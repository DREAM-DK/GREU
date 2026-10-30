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
import ..Labor: pL_l_i
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

const LaborNestingTag = Tag(:LaborNesting)
@variables model :: (LaborNestingTag, GrowthAdjusted) begin
  qLaborNode[n=nodes, i=industry, t=t; i in active_industries], "CES labor quantities."
end
@variables model :: (LaborNestingTag, InflationAdjusted) begin
  pLaborNode[(n,i,t)=qLaborNode], "CES labor prices."
end
@variables model :: LaborNestingTag begin
  uLaborNode[n=nodes, i=industry, t=t; (n,i) in keys(shares)] :: (ForecastConstant, DynamicCalibration), "CES conditional shares."
end
JuMP.set_lower_bound.([pLaborNode[key...] for key in keys(pLaborNode)], 1e-4)

function assign_data!(db)
  db[uLaborNode] .= [shares[(n,i)] for (n,i,yr) in keys(uLaborNode)]
  db[pLaborNode] .= 1.0
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

    # In step 1, types inherit the existing common wage/user cost.
    # Type-specific wages and taxes are deferred to a later step.
    pLaborNode[n=labor_types, i=industry, t=t1:T; i in active_industries],
      pLaborNode[n,i,t] == pL_l_i[:labor,i,t] / pL_l_i[:labor,i,tBase]

    # Each internal CES price is the value-weighted unit cost of its children.
    pLaborNode[n=inner_nodes, i=industry, t=t1:T; i in active_industries],
      pLaborNode[n,i,t] * qLaborNode[n,i,t] ==
        ∑(pLaborNode[c,i,t] * qLaborNode[c,i,t] for c in children_of[n])

    # Conditional CES factor demand at every binary nest.
    qLaborNode[n=nodes, i=industry, t=t1:T; (n,i) in keys(shares)],
      qLaborNode[n,i,t] * pLaborNode[n,i,t]^full_nesting[parent_node[n]].elasticity ==
        uLaborNode[n,i,t] * qLaborNode[parent_node[n],i,t] *
        pLaborNode[parent_node[n],i,t]^full_nesting[parent_node[n]].elasticity
  end
end
function define_calibration(base=define_equations())
  return base
end
end # module LaborNesting
