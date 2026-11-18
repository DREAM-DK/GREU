# Choose technologies that supply each energy service at least cost.
# A technology supplies a share of the service from fixed energy inputs and machinery capital.
# Capital use per unit varies log-normally inside a technology, which makes the choice smooth.
# Partial model: service demand, energy prices and the capital price are given. EnergyTechnologyPartial.jl can link them to the CGE model.
include(joinpath(@__DIR__, "EnergyTechnologySettings.jl"))
module EnergyTechnology

using SquareModels
import JuMP
import ..DataUtils: fill_cells!, read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..model
import ..Time: t, t1, T
import ..Tags: DynamicCalibration, ForecastConstant

# ============================================================================
# Read data
# ============================================================================
const energy_technology_file = joinpath(@__DIR__, "..", "data", "energy_technology", "energy_technology.csv")
read_data(variable) = read_cells(energy_technology_file, variable)

const rTPotential_data = read_data("rTPotential_l_es_d")
const uTE_data = read_data("uTE_l_es_e_d")
const uTI_data = read_data("uTI_l_es_d")
const uTC_data = read_data("uTC_l_es_d")
const rTDiscount_data = read_data("rTDiscount_l_es_d")
const pEBase_data = read_data("pEBase_es_e_d")
const tqE_data = read_data("tqE_es_e_d")
const pTK_data = read_data("pTK_d")
const qES_data = read_data("qES_es_d")
const life = Dict(key => Int(years) for (key, years) in read_data("nTLife_l_es_d"))

# ============================================================================
# Indices
# ============================================================================
const tech_l_es_d = Set(keys(life))
const input_l_es_e_d = Set((l,es,e,d) for (l,es,e,d,_) in keys(uTE_data))
const service_es_d = Set((es,d) for (_,es,d) in tech_l_es_d)
const energy_es_e_d = Set((es,e,d) for (_,es,e,d) in input_l_es_e_d)

const technology = sort!(unique(first.(tech_l_es_d)))
const service = sort!(unique(first.(service_es_d)))
const user = sort!(unique(last.(service_es_d)))
const energy = sort!(unique(e for (_,e,_) in energy_es_e_d))

technologies(es, d) = [l for l in technology if (l,es,d) in tech_l_es_d]
inputs(l, es, d) = [e for e in energy if (l,es,e,d) in input_l_es_e_d]
users_of(es, e, d) = [l for l in technologies(es, d) if (l,es,e,d) in input_l_es_e_d]

# ============================================================================
# Variables
# ============================================================================
const EnergyTechnologyTag = Tag(:EnergyTechnology)

@variables model :: (EnergyTechnologyTag, GrowthAdjusted) begin
  qES_es_d[es=service, d=user, t=t; (es,d) in service_es_d] :: ForecastConstant, "Energy service demand, in PJ."
  qESE_es_e_d[es=service, e=energy, d=user, t=t; (es,e,d) in energy_es_e_d], "Energy input to an energy service, in PJ."
  qESK_es_d[(es,d,t)=qES_es_d], "Machinery capital in an energy service."
end

@variables model :: (EnergyTechnologyTag, InflationAdjusted) begin
  pEBase_es_e_d[(es,e,d,t)=qESE_es_e_d] :: ForecastConstant, "Energy price per PJ before tax by service, energy type and user."
  tqE_es_e_d[(es,e,d,t)=qESE_es_e_d] :: ForecastConstant, "Energy tax per PJ by service, energy type and user."
  pEMarg_es_e_d[(es,e,d,t)=qESE_es_e_d], "Marginal energy price per PJ, including tax."
  pTK_d[d=user, t=t] :: ForecastConstant, "User cost of machinery capital in energy technologies."
  pESMarg_es_d[(es,d,t)=qES_es_d], "Marginal price of an energy service. Supply meets demand at this price."
  pES_es_d[(es,d,t)=qES_es_d], "Average price of an energy service."
end

@variables model :: (EnergyTechnologyTag, GrowthAdjusted, InflationAdjusted) begin
  vES_es_d[(es,d,t)=qES_es_d], "Cost of an energy service."
  vESK_es_d[(es,d,t)=qES_es_d], "Cost of machinery capital in an energy service."
end

@variables model :: EnergyTechnologyTag begin
  rTPotential_l_es_d[l=technology, es=service, d=user, t=t; (l,es,d) in tech_l_es_d], "Largest share of an energy service that a technology can supply."
  rT_l_es_d[(l,es,d,t)=rTPotential_l_es_d], "Share of an energy service that a technology supplies."
  uTE_l_es_e_d[l=technology, es=service, e=energy, d=user, t=t; (l,es,e,d) in input_l_es_e_d], "Energy input per PJ of service by technology."
  uTI_l_es_d[(l,es,d,t)=rTPotential_l_es_d], "Investment cost per PJ of service at full potential."
  uTC_l_es_d[(l,es,d,t)=rTPotential_l_es_d], "Yearly running capital cost per PJ of service at full potential."
  uTKExp_l_es_d[(l,es,d,t)=rTPotential_l_es_d], "Mean capital use per PJ of service: levelized investment and running cost."
  uTKMarg_l_es_d[(l,es,d,t)=rTPotential_l_es_d], "Capital use per PJ of the costliest variant in use."
  uTKSpread_l_es_d[(l,es,d,t)=rTPotential_l_es_d] :: DynamicCalibration, "Log standard deviation of capital use inside a technology."
  rTDiscount_l_es_d[l=technology, es=service, d=user; (l,es,d) in tech_l_es_d], "Discount rate in the levelized cost."
  rTSmooth, "Standard deviation of unit cost inside a technology, as a share of unit cost."
end


# ============================================================================
# Assign data
# ============================================================================
function assign_data!(db)
  fill_cells!(db, rTPotential_l_es_d, rTPotential_data)
  fill_cells!(db, uTE_l_es_e_d, uTE_data)
  fill_cells!(db, uTI_l_es_d, uTI_data)
  fill_cells!(db, uTC_l_es_d, uTC_data)
  fill_cells!(db, rTDiscount_l_es_d, rTDiscount_data)
  fill_cells!(db, pEBase_es_e_d, pEBase_data)
  fill_cells!(db, tqE_es_e_d, tqE_data)
  fill_cells!(db, pTK_d, pTK_data)
  fill_cells!(db, qES_es_d, qES_data)
  db[rTSmooth] = 0.05
  return nothing
end

# ============================================================================
# Functions
# ============================================================================
# Value today of 1 per year for n years, with the first year not discounted.
annuity(r, n) = (1 - (1 / (1 + r))^n) / (1 - 1 / (1 + r))

# Years of a technology's life after the terminal year. Running cost stays at its terminal value there.
years_after_T(l, es, d, t) = max(0, t + life[(l,es,d)] - 1 - T)
last_year(l, es, d, t) = min(t + life[(l,es,d)] - 1, T)

# Standard normal distribution function. GAMS.jl cannot write erf, so use a tanh form.
# It rises everywhere, and its largest error is 1.4e-4.
Φ(x) = 0.5 * (1 + tanh(0.7988005928 * x + 0.03528236872 * x^3))

# Share of a log-normal variable with mean μ and log standard deviation σ that lies below x.
share_below(x, μ, σ) = Φ((log(x / μ) + 0.5 * σ^2) / σ)

# Mean of the same variable over the part below x, times that share.
mean_below(x, μ, σ) = μ * Φ((log(x / μ) - 0.5 * σ^2) / σ)

# Smooth version of max(a, x). The gap to the true maximum is at most width / 2.
smooth_max(a, x; width=1e-5) = 0.5 * (a + x + sqrt((x - a)^2 + width^2))
const uTKFloor = 1e-4

# ============================================================================
# Starting values
# ============================================================================
# Solve each service for its marginal price by bisection and start the solver there.
# Supply rises with the marginal price, so the price where supply meets demand is unique.
const bisection_steps = 60

function set_starting_values!(start_values)
  value(var) = something(start_values[var], 1.0)
  for year in t, (es, d) in service_es_d
    isnothing(start_values[qES_es_d[es,d,year]]) && continue
    techs, pTK, qES = technologies(es, d), value(pTK_d[d,year]), value(qES_es_d[es,d,year])
    potential = Dict(l => value(rTPotential_l_es_d[l,es,d,year]) for l in techs)
    for e in energy
      (es,e,d) in energy_es_e_d || continue
      start_values[pEMarg_es_e_d[es,e,d,year]] = value(pEBase_es_e_d[es,e,d,year]) + value(tqE_es_e_d[es,e,d,year])
    end
    energy_cost = Dict(
      l => sum(value(uTE_l_es_e_d[l,es,e,d,year]) * value(pEMarg_es_e_d[es,e,d,year]) for e in inputs(l, es, d))
      for l in techs
    )
    μ = Dict(
      l => value(uTI_l_es_d[l,es,d,year]) / annuity(value(rTDiscount_l_es_d[l,es,d]), life[(l,es,d)]) + value(uTC_l_es_d[l,es,d,year])
      for l in techs
    )
    σ = Dict(
      l => something(start_values[uTKSpread_l_es_d[l,es,d,year]], value(rTSmooth) * (energy_cost[l] / (μ[l] * pTK) + 1))
      for l in techs
    )
    marginal_capital(l, price) = smooth_max(uTKFloor, (price - energy_cost[l]) / pTK)
    share(l, price) = potential[l] * share_below(marginal_capital(l, price), μ[l], σ[l])
    supply(price) = sum(share(l, price) for l in techs)

    low, high = minimum(values(energy_cost)), maximum(energy_cost[l] + μ[l] * exp(5 * σ[l]) * pTK for l in techs)
    @assert supply(high) > 1 "Technology potentials for $es in $d must cover demand in $year"
    for _ in 1:bisection_steps
      middle = (low + high) / 2
      supply(middle) > 1 ? (high = middle) : (low = middle)
    end
    price = (low + high) / 2

    start_values[pESMarg_es_d[es,d,year]] = price
    for l in techs
      start_values[uTKExp_l_es_d[l,es,d,year]] = μ[l]
      start_values[uTKSpread_l_es_d[l,es,d,year]] = σ[l]
      start_values[uTKMarg_l_es_d[l,es,d,year]] = marginal_capital(l, price)
      start_values[rT_l_es_d[l,es,d,year]] = share(l, price)
    end
    for e in energy
      (es,e,d) in energy_es_e_d || continue
      start_values[qESE_es_e_d[es,e,d,year]] =
        qES * sum(share(l, price) * value(uTE_l_es_e_d[l,es,e,d,year]) for l in users_of(es, e, d))
    end
    start_values[qESK_es_d[es,d,year]] =
      qES * sum(potential[l] * mean_below(marginal_capital(l, price), μ[l], σ[l]) for l in techs)
    start_values[vESK_es_d[es,d,year]] = value(qESK_es_d[es,d,year]) * pTK
    start_values[vES_es_d[es,d,year]] = value(vESK_es_d[es,d,year]) +
      sum(value(qESE_es_e_d[es,e,d,year]) * value(pEMarg_es_e_d[es,e,d,year]) for e in energy if (es,e,d) in energy_es_e_d)
    start_values[pES_es_d[es,d,year]] = value(vES_es_d[es,d,year]) / qES
  end
  return nothing
end

# ============================================================================
# Equations
# ============================================================================
function define_equations()
  # Capital use of the costliest variant in use. The floor keeps it positive for a technology
  # whose energy cost alone is above the marginal price, so the log in the share is defined at
  # every solver step without a variable bound.
  marginal_capital(l, es, d, t) = smooth_max(
    uTKFloor,
    (pESMarg_es_d[es,d,t] - ∑(uTE_l_es_e_d[l,es,e,d,t] * pEMarg_es_e_d[es,e,d,t] for e in inputs(l, es, d))) / pTK_d[d,t],
  )

  return @block model begin
    # The marginal energy price is the base price plus tax. A full link to the CGE model replaces this equation.
    pEMarg_es_e_d[es=service, e=energy, d=user, t=t1:T; (es,e,d) in energy_es_e_d],
    pEMarg_es_e_d[es,e,d,t] == pEBase_es_e_d[es,e,d,t] + tqE_es_e_d[es,e,d,t]

    # Levelized capital cost: the constant yearly cost with the same present value as
    # investment plus running costs over the life of the technology.
    uTKExp_l_es_d[l=technology, es=service, d=user, t=t1:T; (l,es,d) in tech_l_es_d],
    uTKExp_l_es_d[l,es,d,t] * annuity(rTDiscount_l_es_d[l,es,d], life[(l,es,d)]) ==
      uTI_l_es_d[l,es,d,t]
      + ∑(uTC_l_es_d[l,es,d,tt] / (1 + rTDiscount_l_es_d[l,es,d])^(tt-t) for tt in t:last_year(l, es, d, t))
      + uTC_l_es_d[l,es,d,T] * annuity(rTDiscount_l_es_d[l,es,d], years_after_T(l, es, d, t)) / (1 + rTDiscount_l_es_d[l,es,d])^(T+1-t)

    # A variant is in use when its unit cost is at most the marginal price of the service.
    uTKMarg_l_es_d[l=technology, es=service, d=user, t=t1:T; (l,es,d) in tech_l_es_d],
    uTKMarg_l_es_d[l,es,d,t] == marginal_capital(l, es, d, t)

    # A technology supplies its potential times the share of its variants in use.
    rT_l_es_d[l=technology, es=service, d=user, t=t1:T; (l,es,d) in tech_l_es_d],
    rT_l_es_d[l,es,d,t] == rTPotential_l_es_d[l,es,d,t] *
      share_below(marginal_capital(l, es, d, t), uTKExp_l_es_d[l,es,d,t], uTKSpread_l_es_d[l,es,d,t])

    # The marginal price is where supply meets demand.
    pESMarg_es_d[es=service, d=user, t=t1:T; (es,d) in service_es_d],
    1 == ∑(rT_l_es_d[l,es,d,t] for l in technologies(es, d))

    # Energy and capital use.
    qESE_es_e_d[es=service, e=energy, d=user, t=t1:T; (es,e,d) in energy_es_e_d],
    qESE_es_e_d[es,e,d,t] == qES_es_d[es,d,t] * ∑(rT_l_es_d[l,es,d,t] * uTE_l_es_e_d[l,es,e,d,t] for l in users_of(es, e, d))

    qESK_es_d[es=service, d=user, t=t1:T; (es,d) in service_es_d],
    qESK_es_d[es,d,t] == qES_es_d[es,d,t] * ∑(
      rTPotential_l_es_d[l,es,d,t] *
        mean_below(marginal_capital(l, es, d, t), uTKExp_l_es_d[l,es,d,t], uTKSpread_l_es_d[l,es,d,t])
      for l in technologies(es, d)
    )

    # Cost and average price of the service.
    vESK_es_d[es=service, d=user, t=t1:T; (es,d) in service_es_d], vESK_es_d[es,d,t] == qESK_es_d[es,d,t] * pTK_d[d,t]

    vES_es_d[es=service, d=user, t=t1:T; (es,d) in service_es_d],
    vES_es_d[es,d,t] == ∑(qESE_es_e_d[es,e,d,t] * pEMarg_es_e_d[es,e,d,t] for e in energy if (es,e,d) in energy_es_e_d) + vESK_es_d[es,d,t]

    pES_es_d[es=service, d=user, t=t1:T; (es,d) in service_es_d], pES_es_d[es,d,t] * qES_es_d[es,d,t] == vES_es_d[es,d,t]
  end
end

# ============================================================================
# Calibration
# ============================================================================
# Set the spread from baseline costs, so that unit cost inside a technology has the standard
# deviation rTSmooth as a share of unit cost. The spread then stays fixed in a shock.
function define_calibration(base=define_equations())
  return copy(base) + @block model begin
    uTKSpread_l_es_d[l=technology, es=service, d=user, t=t1:T; (l,es,d) in tech_l_es_d],
    uTKSpread_l_es_d[l,es,d,t] * uTKExp_l_es_d[l,es,d,t] * pTK_d[d,t] == rTSmooth * (
      ∑(uTE_l_es_e_d[l,es,e,d,t] * pEMarg_es_e_d[es,e,d,t] for e in inputs(l, es, d))
      + uTKExp_l_es_d[l,es,d,t] * pTK_d[d,t]
    )
  end
end

end # module