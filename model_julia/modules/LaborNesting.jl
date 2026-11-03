# Optional CES disaggregation of Production's existing :labor leaf.
# Production continues to determine qProd[:labor] through factor demand.
# Labor continues to determine the aggregate labor user cost pL_l_i.
# This module owns ONLY pProd[:labor] and its internal CES tree.
include(joinpath(@__DIR__, "LaborNestingSettings.jl"))
module LaborNesting
using SquareModels
import JuMP
import ..model
import ..DataUtils: read_cells
import ..GrowthInflationAdjustment: GrowthAdjusted, InflationAdjusted
import ..Production: qProd, pProd, labor_l_i
import ..ProductionSettings: production_data_dir
import ..Labor: pL_l_i, pLType_i, nLType, nL_l_i, qL2nL
import ..LaborNestingSettings: labor_types, full_nesting
import ..InputOutput: industry
import ..Settings: calibration_year
import ..Time: t, t1, T, tBase
import ..Tags: ForecastConstant, DynamicCalibration

const labor_data = read_cells(joinpath(production_data_dir, "production_labor_types.csv"), "nL_l_i")
const active_industries = Set(i for (l,i) in labor_l_i if l == :labor)
# Validate the user-defined binary CES tree, independently of dictionary order.
const nest_names = Set(keys(full_nesting))
@assert length(labor_types) >= 2 && allunique(labor_types) "At least two unique labor types are required"
@assert :labor ∉ labor_types && isempty(intersect(Set(labor_types), nest_names)) "Labor types and CES nest names must be distinct from :labor and each other"
@assert length(full_nesting) == length(labor_types) - 1 "A binary CES tree needs N-1 nests"
for (n, spec) in full_nesting
    @assert length(spec.children) == 2 && allunique(spec.children) "Nest $n must have two distinct children"
    @assert isfinite(spec.elasticity) && spec.elasticity > 0 "Nest $n must have a positive finite elasticity"
    @assert all(c -> c in nest_names || c in labor_types, spec.children) "Unknown child in labor nest $n"
end
const child_list = [c for spec in values(full_nesting) for c in spec.children]
@assert allunique(child_list) "Each labor type/nest must have exactly one parent"
@assert Set(labor_types) ⊆ Set(child_list) "Every labor type must appear in the CES tree"
const root_candidates = setdiff(nest_names, Set(child_list))
@assert length(root_candidates) == 1 "Labor CES tree must have exactly one root"
const top = only(root_candidates)
const parent_node = Dict(c => n for (n, spec) in full_nesting for c in spec.children)
const children_of = Dict(n => spec.children for (n, spec) in full_nesting)
const inner_nodes = sort!(collect(nest_names))
const nodes = [labor_types; inner_nodes]
function validate_tree(n, visiting=Set{Symbol}(), visited=Set{Symbol}())
    n in labor_types && return
    @assert !(n in visiting) "Cycle in labor CES tree at $n"
    n in visited && return
    push!(visiting, n)
    for c in children_of[n]
        validate_tree(c, visiting, visited)
    end
    delete!(visiting, n)
    push!(visited, n)
end
validate_tree(top)
@assert all(n -> n == top || haskey(parent_node, n), inner_nodes) "Disconnected labor CES nest"
const subtree_leaves = Dict{Symbol,Vector{Symbol}}()
function leaves_below(n)
    return get!(subtree_leaves, n) do
        n in labor_types ? [n] : vcat((leaves_below(c) for c in children_of[n])...)
    end
end
leaves_below(top)
@assert Set(leaves_below(top)) == Set(labor_types) "All labor types must be reachable from root"
const shares = Dict{Tuple{Symbol,Symbol},Float64}()
for i in active_industries
  counts = Dict(l => get(labor_data, (l,i,calibration_year), 0.0) for l in labor_types)
  @assert all(v -> isfinite(v) && v > 0, values(counts)) "Missing positive labor type observations for $i in $calibration_year"
  for (n, spec) in full_nesting
    totals = [sum(counts[l] for l in leaves_below(c)) for c in spec.children]
    for (c, total) in zip(spec.children, totals)
      shares[(c,i)] = total / sum(totals)
    end
  end
end

# Base-year calibration: with unit leaf and nest prices, the CES quantity
# share of a leaf equals the product of its conditional shares along the tree.
# The type-specific conversion factor makes the observed type PERSON shares
# agree with CES quantities in the base year. This is a fixed physical-unit
# normalization, not a CES identity outside the calibration year.
const productivity = Dict{Tuple{Symbol,Symbol},Float64}()
for i in active_industries
  total_people = sum(labor_data[(l,i,calibration_year)] for l in labor_types)
  for l in labor_types
    leaf_share = 1.0
    child = l
    while haskey(parent_node, child)
      leaf_share *= shares[(child,i)]
      child = parent_node[child]
    end
    person_share = labor_data[(l,i,calibration_year)] / total_people
    productivity[(l,i)] = leaf_share / person_share
    @assert isfinite(productivity[(l,i)]) && productivity[(l,i)] > 0
  end
end

const LaborNestingTag = Tag(:LaborNesting)
@variables model :: LaborNestingTag begin
  nLaborType_i[l=labor_types, i=industry, t=t; i in active_industries], "Persons of labor type by industry."
end
@variables model :: (LaborNestingTag, GrowthAdjusted) begin
  qLaborNode[n=nodes, i=industry, t=t; i in active_industries], "CES labor quantities."
end
@variables model :: (LaborNestingTag, InflationAdjusted) begin
  pLaborNode[(n,i,t)=qLaborNode], "CES labor prices."
end
@variables model :: LaborNestingTag begin
  uLaborNode[n=nodes, i=industry, t=t; (n,i) in keys(shares)] :: (ForecastConstant, DynamicCalibration), "CES conditional shares."
  aLabor[l=labor_types, i=industry, t=t; i in active_industries] :: ForecastConstant, "Factor-augmenting labor productivity by labor type and industry."
end
JuMP.set_lower_bound.([pLaborNode[key...] for key in keys(pLaborNode)], 1e-4)
JuMP.set_lower_bound.([aLabor[key...] for key in keys(aLabor)], 1e-4)

function assign_data!(db)
  db[uLaborNode] .= [shares[(n,i)] for (n,i,yr) in keys(uLaborNode)]
  db[pLaborNode] .= 1.0
  db[aLabor]     .= 1.0
  # Do not assign observed headcounts to qLaborNode. Those are not
  # production quantity units. Conditional shares are calibrated above;
  # the CES equations determine node quantities during calibration.
  return nothing
end
function set_starting_values!(start_values)
  return nothing
end
function define_equations()
  return @block model begin
    # Price ownership switches from Labor to LaborNesting, not Production.
    pProd[l=:labor, i=industry, t=t1:T; i in active_industries],
      pProd[l,i,t] == pLaborNode[top,i,t]

    # Production's demand for aggregate labor remains untouched.
    qLaborNode[n=nodes, i=industry, t=t1:T; n == top && i in active_industries],
      qLaborNode[n,i,t] == qProd[:labor,i,t]

    # Explicit type-level PERSON demand, rather than a normalized CES share.
    # pL_l_i[:labor,i,tBase] converts original qProd into efficiency units;
    # productivity[(l,i)] calibrates type units to observed persons in tBase.
    nLaborType_i[l=labor_types, i=industry, t=t1:T; i in active_industries],
      qLaborNode[l,i,t] == productivity[(l,i)] *
        nLaborType_i[l,i,t] * qL2nL[t] * pL_l_i[:labor,i,tBase]

    # The aggregate headcount is the exact sum of type headcounts.
    # This replaces Labor.jl's old direct qL2nL -> aggregate persons equation
    # when LaborNesting is enabled; keeping both would overdetermine CES.
    nL_l_i[l=:labor, i=industry, t=t1:T; i in active_industries],
      nL_l_i[l,i,t] == ∑(nLaborType_i[k,i,t] for k in labor_types)

    # Total persons of each type are obtained from industry-specific persons.
    nLType[l=labor_types, t=t1:T],
      nLType[l,t] == ∑(nLaborType_i[l,i,t] for i in active_industries)

    # Step 3A: prices now flow through explicit type-specific labor costs.
    # The wage bridge in Labor.jl keeps the original baseline unchanged.
    pLaborNode[n=labor_types, i=industry, t=t1:T; i in active_industries],
      pLaborNode[n,i,t] == pLType_i[n,i,t] / pLType_i[n,i,tBase]

    # Each internal CES price is the value-weighted unit cost of its children.
    pLaborNode[n=inner_nodes, i=industry, t=t1:T; i in active_industries],
      pLaborNode[n,i,t] * qLaborNode[n,i,t] ==
        ∑(pLaborNode[c,i,t] * qLaborNode[c,i,t] for c in children_of[n])

     # CES demand for primary labor types with factor-augmenting productivity.
     qLaborNode[n=labor_types, i=industry, t=t1:T; (n,i) in keys(shares)],
     (aLabor[n,i,t] * qLaborNode[n,i,t]) *
       (pLaborNode[n,i,t] / aLabor[n,i,t])^full_nesting[parent_node[n]].elasticity ==
       uLaborNode[n,i,t] * qLaborNode[parent_node[n],i,t] *
       pLaborNode[parent_node[n],i,t]^full_nesting[parent_node[n]].elasticity

   # CES demand for composite labor nodes without productivity adjustment.
   qLaborNode[n=inner_nodes, i=industry, t=t1:T; (n,i) in keys(shares)],
     qLaborNode[n,i,t] *
       pLaborNode[n,i,t]^full_nesting[parent_node[n]].elasticity ==
       uLaborNode[n,i,t] * qLaborNode[parent_node[n],i,t] *
       pLaborNode[parent_node[n],i,t]^full_nesting[parent_node[n]].elasticity
  end
end
function define_calibration(base=define_equations())
  block = copy(base)
  # The aggregate headcount equation belongs to LaborNesting when enabled.
  # Calibrate aggregate production labor quantities from observed headcounts,
  # just as the original Labor module did before CES disaggregation.
  @endo_exo_swap! block begin
    qProd[l=:labor, i=industry, t=t1; i in active_industries],
      nL_l_i[l=:labor, i=industry, t=t1; i in active_industries]
  end
  return block
end
end # module LaborNesting
