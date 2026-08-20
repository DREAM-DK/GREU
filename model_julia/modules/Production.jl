# ==============================================================================
# Production Module
# ==============================================================================
# find some text to put here that easily and well default
include(joinpath(@__DIR__, "ProductionSettings.jl"))

module Production

using SquareModels
import JuMP
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted, fq, fp
import ..ProductionSettings: production_data_dir
import ..Settings: base_year, calibration_year
import ..InputOutputSettings: input_output_data_dir
import ..db
import ..Time: t, t1, T, at_year, variable_year
import ..Tags: ForecastConstant

# See if better way can be found than import for all other modules:
import ..InputOutput:
    RX,
    K,
    pD,
    qD,
    qY_i,
    vW_i


# ==========================================================================
# Indices
# ==========================================================================

# CES nesting tree structure:
const children = Dict(
    :KE           => [:equipment],
    :KEL          => [:KE, :labor],
    :KELB         => [:KEL, :structures],
    :TopPfunction => [:KELB, :RxE],
)
# Sets, we might consider moving them to seperate files later.
const parent = Dict(child => nest for (nest, nest_children) in children for child in nest_children) # maybe return to this and see if it can be made clearer, rest are good. #notfinished
const nests  = sort([nest for nest in keys(children)])
const leaves = sort([node for node in keys(parent) if node ∉ values(parent)])
const PF     = sort([nests; leaves])
const top    = only([node for node in PF if node ∉ keys(parent)])
const non_top_nests = [nest for nest in nests if nest != top]

# Find good name for this group #notfinished
const qK_k_i_data = read_sparse_array(joinpath(production_data_dir, "production_capital.csv"); variable="qK_k_i")

#notfinished way to complicated, but it works for now
const D1K = Set(
    (k, i)
    for (k, i) in eachindex(qK_k_i_data[:, :, calibration_year])
    if qK_k_i_data[k, i, calibration_year] > 0 &&
       qK_k_i_data[k, i, calibration_year - 1] > 0
)

# Only industries with data. 
const I = sort(unique(i for (k, i) in D1K))

#notfinished, look through
# Which nodes exist for which industry. A capital leaf needs a stock, :RxE needs
# an intermediate-demand column, :labor is always present, and a nest lives if
# any child does. Declaring a node without data gives it a zero CES share and a
# zero Jacobian column, which makes the system singular.
const D1Prod = Set(
    (pf, i)
    for pf in PF, i in I
    if pf ∉ K && pf != :RxE ||          # nests and :labor always exist
       pf in K && (pf, i) in D1K ||     # capital leaves need a stock
       pf == :RxE && i in RX            # RxE needs an intermediate column
)




# ==========================================================================
# Variables
# ==========================================================================
const ProductionTag = Tag(:Production)

# Quantities
@variables db.model :: (ProductionTag, GrowthAdjusted) begin
    qK_k_i[k=K, i=I, t=t; (k, i) in D1K], "Real capital stock by capital type and industry"
    qI_k_i[k=K, i=I, t=t; (k, i) in D1K], "Real investment by capital type and industry" 
    qInstCost_k_i[k=K, i=I, t=t; (k, i) in D1K], "Real installation costs"
    qL_i[I, t], "Labour in effecinecy units"
    qProd[pf=PF, i=I, t=t; (pf, i) in D1Prod], "Quantity at a node of the tree"
    qY0_i[I, t], "Output net of installation costs and costs outside the tree"         
end

# Prices 
@variables db.model :: (ProductionTag, InflationAdjusted) begin
    pK_k_i[k=K, i=I, t=t; (k, i) in D1K], "User cost of capital"
    pL_i[I, t], "wage per unit"
    pProd[pf=PF, i=I, t=t; (pf, i) in D1Prod], "Price at a node of the tree"
    pY0_i[I, t], "Price index"
end

# Values
@variables db.model :: (ProductionTag, GrowthAdjusted, InflationAdjusted) begin 
    vI_k_i[k=K, i=I, t=t; (k, i) in D1K], "Investment" 
    vProdOtherProductionCosts[I, t], "Production costs outside the tree"
end

# Ratios, shares, rates and derivatives. 
@variables db.model :: ProductionTag begin
    qK2qY_k_i[k=K, i=I, t=t; (k, i) in D1K], "Capital per unit of output"
    qL2qY_i[I, t], "Labour per unit of output"
    qR2qY_i[I, t], "Intermediates per unit of output"
    qPFtop2qY[I, t] :: ForecastConstant, "Units conversion between the top of the tree and qY_i" 

    uProd[pf=PF, i=I, t=t; (pf, i) in D1Prod] :: ForecastConstant, "CES share at a node"
    pProd2pNest[pf=PF, i=I, t=t; (pf, i) in D1Prod && pf != top], "Price relatve to the parent nest"
    eProd[nests, I], "Elasticity of substitution within a nest"

    rKDepr_k_i[k=K, i=I, t=t; (k, i) in D1K] :: ForecastConstant, "Depreciation rate"
    rHurdleRate_i[I, t] :: ForecastConstant, "Hurdle rate of investment"
    fInstCost_k_i[k=K, i=I, t=t; (k, i) in D1K] :: ForecastConstant, "Installation costs"
    dInstCost2dK_k_i[k=K, i=I, t=t; (k, i) in D1K], "Derivative wrt current capital"
    dInstCost2dKLag_k_i[k=K, i=I, t=t; (k, i) in D1K], "Derivative wrt lagged capital"

    jpK_k_i[k=K, i=I, t=t; (k, i) in D1K], "Addition to user cost get better name #notfinished"

end




# ==========================================================================
# Data
# ==========================================================================
function set_data!(db; dir = production_data_dir)
    file = joinpath(dir, "production_capital.csv")

    # Input Capital and investment from Eurostat, file fromed in ProductionData.jl
    db[qK_k_i] .= read_variable(file, qK_k_i)
    db[qI_k_i] .= read_variable(file, qI_k_i)

    #notfinished really long and bad, but makes it work fix later. 
    # Reconcile the Eurostat capital quantities with the IO investment totals.
    #
    # qI and qK must receive the same scaling factor. Scaling only qI changes
    # the implied depreciation rate in the capital-accumulation equation.
    for k in K
        cells = [
            (k, i) for i in I
            if (k, i) in D1K &&
            !isnothing(db[qI_k_i[k, i, t1]])
        ]

        production_total = sum(
            db[qI_k_i[k, i, t1]]
            for (k, i) in cells
        )

        io_total = db[qD[k, t1]]

        if !isnothing(io_total) && production_total != 0
            adjustment = io_total / production_total

            for (k, i) in cells, tt in t
                investment = db[qI_k_i[k, i, tt]]
                capital    = db[qK_k_i[k, i, tt]]

                if !isnothing(investment)
                    db[qI_k_i[k, i, tt]] = investment * adjustment
                end

                if !isnothing(capital)
                    db[qK_k_i[k, i, tt]] = capital * adjustment
                end
            end
        end
    end


    #notfinished, was much simpler before
    for i in I, tt in t
        db[qL_i[i, tt]] = db[vW_i[i, tt]]
    end
    db[eProd] .= 0.7
    db[rHurdleRate_i] .= 0.2
    db[fInstCost_k_i] .= 0.0 #notfinished, removes usercost while leaving equations. 
    db[jpK_k_i] .= 0.0

    #notfinished, 
    # Set prices to 1.0 (inflation, but not growth-adjusted, variables) #notfinished
    # Price indices initialized at one. pK_k_i is determined endogenously.
    db[pL_i]  .= 1.0
    db[pProd] .= 1.0
    db[pY0_i] .= 1.0


    return nothing
end


# ==========================================================================
# Starting values (solver hints, not exogenous data)
# ==========================================================================

    #notfinished long and unwindly not a good idea, fix later. 
    # Extend the static calibration values across the dynamic horizon.
    # This is called after endogenous/exogenous selection, so these values
    # are solver starting values rather than exogenous data.
    function set_starting_values!(db)
        for tt in t
            (tt <= t1 || tt > T) && continue
    
            for (k, i) in D1K
                isnothing(db[qK_k_i[k, i, tt]]) && (db[qK_k_i[k, i, tt]] = db[qK_k_i[k, i, t1]])
            end
    
            # Base of a negative fractional power; one is the base-year normalisation.
            for pf in PF, i in I
               (pf == top || (pf, i) ∉ D1Prod) || (db[pProd2pNest[pf, i, tt]] = 1.0)
            end
    
            for pf in PF, i in I
                (pf, i) ∈ D1Prod || continue
                isnothing(db[qProd[pf, i, tt]]) && (db[qProd[pf, i, tt]] = db[qProd[pf, i, t1]])
                isnothing(db[pProd[pf, i, tt]]) && (db[pProd[pf, i, tt]] = db[pProd[pf, i, t1]])
            end
        end
        return nothing
    end

# ==========================================================================
# Residuals allowed to exceed the global tolerance
# ==========================================================================
function set_residual_tolerances!(tolerances)
    tolerances[dInstCost2dKLag_k_i] .= 1.0
    return nothing
end

# ==========================================================================
# Equations
# ==========================================================================

function define_equations()
    return @block db begin
        # -- Factor demands --
        #notfinished, changed qY0_i to qY_i in two below please double check later. 
        qK_k_i[k = K, i = I, t = t1:T; (k, i) in D1K], qK_k_i[k, i , t] == qK2qY_k_i[k, i, t] * qY_i[i, t]

        qL_i[i = I, t = t1:T], qL_i[i, t] == qL2qY_i[i, t] * qY_i[i, t]

        qD[i = RX, t = t1:T], qD[i, t] == qR2qY_i[i, t] * qY_i[i, t]

        # -- Capital accumulation --
        qI_k_i[k = K, i = I, t = t1:T; (k, i) ∈ D1K],
        qI_k_i[k, i, t] == qK_k_i[k, i, t] - (1 - rKDepr_k_i[k, i, t]) * qK_k_i[k, i, t-1]/fq

        qD[k = K, t = t1:T], qD[k, t] == ∑(qI_k_i[k, i, t] for i ∈ I if (k, i) ∈ D1K)

        vI_k_i[k = K, i = I, t = t1:T; (k, i) ∈ D1K], vI_k_i[k, i, t] == pD[k, t] * qI_k_i[k, i, t]
        
        # -- Installation costs --
        qInstCost_k_i[k = K, i = I, t = t1:T; (k, i) ∈ D1K],
        qInstCost_k_i[k, i, t] == fInstCost_k_i[k, i, t] * (qI_k_i[k, i, t]/qK_k_i[k, i, t-1])^2 * qK_k_i[k, i, t-1]

        dInstCost2dK_k_i[k = K, i = I, t = t1:T; (k, i) ∈ D1K],
        dInstCost2dK_k_i[k, i , t] == 2 * fInstCost_k_i[k, i, t] * qI_k_i[k, i, t]/(qK_k_i[k, i, t-1] / fq)

        dInstCost2dKLag_k_i[k = K, i = I, t = t1:T-1; (k, i) ∈ D1K],
        dInstCost2dKLag_k_i[k, i, t] == 
            -fInstCost_k_i[k, i, t] * 
            (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t+1] * fq / qK_k_i[k, i, t]) * 
            (qI_k_i[k, i, t+1] * fq / qK_k_i[k, i, t])
        
        # Last period in regard to lagged capital, assume ratio is at steady state at this point
        dInstCost2dKLag_k_i[k = K, i = I, t = T:T; (k, i) in D1K],
        dInstCost2dKLag_k_i[k, i, t] ==
              -fInstCost_k_i[k, i, t] * 
              (2 * (1 - rKDepr_k_i[k, i, t]) + qI_k_i[k, i, t] * fq / qK_k_i[k, i, t]) * (qI_k_i[k, i, t] * fq / qK_k_i[k, i, t])

        # -- Cost minimization, CES tree is constraint --
        pProd2pNest[pf = PF, i = I, t = t1:T; pf != top && (pf, i) ∈ D1Prod],
        pProd2pNest[pf, i, t] == pProd[pf, i, t] / pProd[parent[pf], i, t] 

        qProd[pf = [top], i = I, t = t1:T],
        qProd[pf, i, t] == qY0_i[i, t] + sum(qInstCost_k_i[k, i, t] for k ∈ K if (k, i) ∈ D1K)

        qProd[pf = PF, i = I, t = t1:T; pf != top && (pf, i) ∈ D1Prod],
        qProd[pf, i, t] == uProd[pf, i, t] * pProd2pNest[pf, i, t]^(-eProd[parent[pf], i]) * qProd[parent[pf], i, t]

        pProd[pf = nests, i = I, t = t1:T; (pf, i) ∈ D1Prod],
        pProd[pf, i , t] * qProd[pf, i, t] == ∑(pProd[c, i, t] * qProd[c, i, t] for c ∈ children[pf] if (c, i) ∈ D1Prod)

        qY0_i[i = I, t = t1:T], qY0_i[i, t] == qPFtop2qY[i, t] * qY_i[i, t]
        pY0_i[i = I, t = t1:T], pY0_i[i, t] * qY0_i[i, t] == pProd[top, i, t] * qProd[top, i, t] 

        # -- Deciding leafs of the tree --
        pProd[pf = [:RxE], i = RX, t = t1:T], pProd[pf, i, t] == pD[i, t]
        pProd[pf = [:labor], i = I, t = t1:T; (pf, i) ∈ D1Prod], pProd[pf, i, t] == pL_i[i, t]
        pProd[pf = K, i = I, t = t1:T; (pf, i) ∈ D1K], pProd[pf, i, t] == pK_k_i[pf, i, t] / pK_k_i[pf, i, base_year]

        qR2qY_i[i = RX, t = t1:T], qD[i, t] == qProd[:RxE, i, t]
        qL2qY_i[i = I, t = t1:T], qL_i[i, t] == qProd[:labor, i, t]
        qK2qY_k_i[k = K, i = I, t = t1:T; (k, i) ∈ D1K], qProd[k, i, t] == qK_k_i[k, i, t] * pK_k_i[k, i, base_year]

        # -- User cost of capital --
        pK_k_i[k = K, i = I, t = t1:T-1; (k, i) in D1K],
        pK_k_i[k, i, t] ==
          pD[k, t] -
          (1 - rKDepr_k_i[k, i, t]) / (1 + rHurdleRate_i[i, t+1]) * pD[k, t+1] * fp + 
          pProd[top, i, t] * dInstCost2dK_k_i[k, i, t] + 
          dInstCost2dKLag_k_i[k, i, t] / (1 + rHurdleRate_i[i, t+1]) * pProd[top, i, t+1] * fp + 
          jpK_k_i[k, i, t]
        
        # Last period 
        #notfinished, fix later not a good solution in regard to Lag variable. 
        pK_k_i[k = K, i = I, t = T:T; (k, i) in D1K],
        pK_k_i[k, i, t] ==
            pD[k, t] - 
            (1 - rKDepr_k_i[k, i, t]) / (1 + rHurdleRate_i[i, t]) * pD[k, t] * fp + 
            pProd[top, i, t] * dInstCost2dK_k_i[k, i, t] + 
            dInstCost2dKLag_k_i[k, i,  t] / (1 + rHurdleRate_i[i, t]) * pProd[top, i, t] * fp + 
            jpK_k_i[k, i, t]

    end  
end


# ==========================================================================
# Calibration
# ==========================================================================
function define_calibration()
    block = define_equations()
   
    @endo_exo_swap! block begin
        rKDepr_k_i[:, :, t1], qI_k_i[:, :, t1]
        uProd[non_top_nests, :, t1], pProd[non_top_nests, :, t1]
    end

    #notfinished
    @endo_exo_swap! block begin
        [uProd[:RxE, i, t1] for i in RX], [qD[i, t1] for i in RX]
        [uProd[k, i, t1] for (k, i) in D1K], [qK_k_i[k, i, t1] for (k, i) in D1K]
        [uProd[:labor, i, t1] for i in I], [qL_i[i, t1] for i in I]
        [qPFtop2qY[i, t1] for i in I], [pProd[top, i, t1] for i in I]
    end

    return block
end


# ==========================================================================
# Tests
# ==========================================================================
function run_tests(db)
    errors = String[]
  
    return errors
end



end # module