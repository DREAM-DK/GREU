# Prune small intermediate input-output cells in ALL years, in memory.
#
# The model used to prune small cells only in forecast years. Their flows then
# disappeared from the first forecast year, which created jumps and shifted the long
# run. Here the same cells are removed from the data in every year, and the remaining
# cells are rebalanced, so data and forecast use the same table. The CSV files are
# never changed.
#
# Scope: purchaser use by industries (intermediate use). Final uses (C, G, K, X, INV)
# and the supply table are not pruned.
#
# Margins and product taxes on intermediate use move with their purchaser-use cell.
# Cells that share origin weights with margin services (G45-G47) are left untouched.
#
# Included inside module InputOutput, right after the data are read. Uses its settings:
# cell_tolerance, max_pruned_cell_supply_share, max_pruned_cell_row_column_share,
# max_pruned_row_column_loss_share, calibration_year and final_uses.
# Setting max_pruned_cell_supply_share = 0 keeps every cell.

_is_intermediate(u) = !(u in final_uses)

_sums(d, f) = (s = Dict{Any,Float64}(); for (k, v) in d; s[f(k)] = get(s, f(k), 0.0) + v; end; s)

"""Intermediate purchaser-use cells to prune (keys without year), by the model's pruning rule."""
function pruned_intermediate_cells(cells, supply_total)
  magnitudes = sort([key[1:end-1] => abs(v) for (key, v) in cells
                     if key[end] == calibration_year && abs(v) > cell_tolerance]; by=first)
  row(key) = (key[1], key[3:end]...)
  column(key) = (key[2], key[3:end]...)
  row_totals = _sums(Dict(magnitudes), row)
  column_totals = _sums(Dict(magnitudes), column)
  candidates = sort([key => v for (key, v) in magnitudes
    if _is_intermediate(key[2]) &&
       v <= max_pruned_cell_supply_share * supply_total &&
       v <= max_pruned_cell_row_column_share * row_totals[row(key)] &&
       v <= max_pruned_cell_row_column_share * column_totals[column(key)]];
    by = cell -> (last(cell), first(cell)))
  row_losses = Dict(k => 0.0 for k in keys(row_totals))
  column_losses = Dict(k => 0.0 for k in keys(column_totals))
  pruned = Set{Any}()
  for (key, v) in candidates
    r, c = row(key), column(key)
    if row_losses[r] + v <= max_pruned_row_column_loss_share * row_totals[r] &&
       column_losses[c] + v <= max_pruned_row_column_loss_share * column_totals[c]
      row_losses[r] += v
      column_losses[c] += v
      push!(pruned, key)
    end
  end
  return pruned
end

"""RAS: scale nonnegative cells so row and column sums reach their targets."""
function _ras!(x, row_of, col_of, row_target, col_target; tol=1e-10, maxiter=10_000)
  for _ in 1:maxiter
    rs = _sums(x, row_of)
    for (k, v) in x
      s = rs[row_of(k)]
      s > 0 && (x[k] = v * row_target[row_of(k)] / s)
    end
    cs = _sums(x, col_of)
    for (k, v) in x
      s = cs[col_of(k)]
      s > 0 && (x[k] = v * col_target[col_of(k)] / s)
    end
    rs = _sums(x, row_of)
    maximum(abs(s - row_target[r]) / max(abs(row_target[r]), 1.0) for (r, s) in rs; init=0.0) < tol && return true
  end
  return false
end

"""Keep a pruned cell where its row or column would otherwise be empty in that year."""
function _restore_empty!(kept, block, row_of, col_of)
  kr = _sums(kept, row_of)
  kc = _sums(kept, col_of)
  for (k, v) in block
    haskey(kept, k) && continue
    (get(kr, row_of(k), 0.0) <= 0 || get(kc, col_of(k), 0.0) <= 0) && (kept[k] = v)
  end
  return kept
end

"""
Remove pruned cells from `block` and rebalance with RAS. Where a row or column cannot
reach its total, keep that row's and column's pruned cells and try again.
"""
function _balance(block, is_pruned, row_of, col_of; rounds=20, tol=1e-6)
  rt = _sums(block, row_of)
  ct = _sums(block, col_of)
  keep_back = Set{Any}()
  kept = Dict{Any,Float64}()
  for _ in 1:rounds
    kept = Dict{Any,Float64}(k => v for (k, v) in block if !is_pruned(k) || k in keep_back)
    _restore_empty!(kept, block, row_of, col_of)
    _ras!(kept, row_of, col_of, rt, ct)
    rs = _sums(kept, row_of)
    cs = _sums(kept, col_of)
    bad_rows = Set(r for (r, v) in rt if abs(get(rs, r, 0.0) - v) > tol * max(abs(v), 1.0))
    bad_cols = Set(c for (c, v) in ct if abs(get(cs, c, 0.0) - v) > tol * max(abs(v), 1.0))
    isempty(bad_rows) && isempty(bad_cols) && return kept
    for k in keys(block)
      is_pruned(k) && (row_of(k) in bad_rows || col_of(k) in bad_cols) && push!(keep_back, k)
    end
  end
  @warn "Input-output pruning: rebalancing still has gaps"
  return kept
end

"""
Prune intermediate purchaser use (p, u, o, year) in place and rebalance each year and
origin, keeping every product row (p, o) and industry column (u, o) total.
Returns the pruned cells (keys without year).
"""
function prune_intermediate_use!(cells, supply_total, frozen=k -> false)
  pruned = setdiff(pruned_intermediate_cells(cells, supply_total), Set(k[1:3] for k in keys(cells) if frozen(k)))
  isempty(pruned) && return pruned
  years = unique(k[end] for k in keys(cells))
  origins = unique(k[3] for k in keys(cells))
  for y in years, o in origins
    block = Dict{Any,Float64}(k => v for (k, v) in cells
      if k[end] == y && k[3] == o && _is_intermediate(k[2]) && v > cell_tolerance && !frozen(k))
    isempty(block) && continue
    kept = _balance(block, k -> k[1:3] in pruned, k -> k[1], k -> k[2])
    for k in keys(block)
      cells[k] = get(kept, k, 0.0)
    end
  end
  return pruned
end

"""
Move cells that sit on intermediate purchaser use (margins, product taxes) with their
purchaser-use cell: scale each by `factor(key)` (new over old purchaser use), then
restore each `column_of(key)` total by spreading the gap in proportion to the cells'
own size among cells where `live(key)`. Keeps column totals and cell signs.
"""
function follow_purchaser_use!(cells, factor, column_of, live)
  original = copy(cells)
  for (k, v) in original
    _is_intermediate(k[2]) || continue
    cells[k] = v * factor(k)
  end
  columns = Dict{Any,Vector{Any}}()
  for k in keys(original)
    _is_intermediate(k[2]) && push!(get!(columns, column_of(k), Any[]), k)
  end
  for col in values(columns)
    gap = sum(original[k] for k in col; init=0.0) - sum(cells[k] for k in col; init=0.0)
    abs(gap) > 0 || continue
    targets = [k for k in col if live(k)]
    weights = Dict(k => abs(cells[k]) for k in targets)
    sum(values(weights); init=0.0) > 0 || (weights = Dict(k => 1.0 for k in targets))
    w = sum(values(weights); init=0.0)
    w > 0 || continue
    for (k, wk) in weights
      cells[k] += gap * wk / w
    end
  end
  return cells
end

# ============================================================================
# Apply to the data read above
# ============================================================================

# Margin-service cells share origin weights with purchaser use of the same product and use.
const _margin_service_p_u = Set((s, u) for ((s, u, _, _), v) in qMarginService_s_u_o_data if abs(v) > cell_tolerance)

const unpruned_purchaser_use_p_u_o_data = copy(qPurchaserUse_p_u_o_data)
const pruned_intermediate_use = prune_intermediate_use!(
  qPurchaserUse_p_u_o_data, vY_data[(calibration_year,)] + vM_data[(calibration_year,)],
  k -> (k[1], k[2]) in _margin_service_p_u,
)

const _unpruned_p_u = _sums(unpruned_purchaser_use_p_u_o_data, k -> (k[1], k[2], k[4]))
const _pruned_p_u = _sums(qPurchaserUse_p_u_o_data, k -> (k[1], k[2], k[4]))

for k in keys(qPurchaserUse_p_u_data)
  _is_intermediate(k[2]) && (qPurchaserUse_p_u_data[k] = get(_pruned_p_u, k, 0.0))
end
for k in keys(qM_p_i_data)
  qM_p_i_data[k] = get(_pruned_p_u, k, 0.0)
end

_new_and_old(k) = length(k) == 4 ?
  (get(qPurchaserUse_p_u_o_data, k, 0.0), get(unpruned_purchaser_use_p_u_o_data, k, 0.0)) :
  (get(_pruned_p_u, k, 0.0), get(_unpruned_p_u, k, 0.0))

"""New over old purchaser use for a (p, u, year) or (p, u, o, year) cell."""
purchaser_use_factor(k) = ((new, old) = _new_and_old(k); abs(old) > cell_tolerance ? new / old : 0.0)

"""Purchaser use is still nonzero after pruning."""
purchaser_use_is_live(k) = abs(first(_new_and_old(k))) > cell_tolerance

follow_purchaser_use!(qMarginBundle_p_u_data, purchaser_use_factor, k -> (k[2], k[3]), purchaser_use_is_live)

"""Move intermediate product taxes and subsidies with purchaser use. Keeps (use, origin) totals."""
function follow_product_taxes!(vt_p_u_o, vs_p_u_o, vt_p_u, vs_p_u, vnt_p_u)
  isempty(pruned_intermediate_use) && return nothing
  for cells in (vt_p_u_o, vs_p_u_o)
    follow_purchaser_use!(cells, purchaser_use_factor, k -> (k[2], k[3], k[4]), purchaser_use_is_live)
  end
  vt = _sums(vt_p_u_o, k -> (k[1], k[2], k[4]))
  vs = _sums(vs_p_u_o, k -> (k[1], k[2], k[4]))
  for (cells, totals) in ((vt_p_u, vt), (vs_p_u, vs)), k in keys(cells)
    _is_intermediate(k[2]) && (cells[k] = get(totals, k, 0.0))
  end
  for k in keys(vnt_p_u)
    _is_intermediate(k[2]) && (vnt_p_u[k] = get(vt, k, 0.0) - get(vs, k, 0.0))
  end
  return nothing
end

"""Set the product split of intermediate input to pruned purchaser use."""
function follow_intermediate_split!(qM_p_m_i, qM_m_i)
  isempty(pruned_intermediate_use) && return nothing
  for (p, m, i, y) in keys(qM_p_m_i)
    qM_p_m_i[(p, m, i, y)] = get(qM_p_i_data, (p, i, y), 0.0)
  end
  totals = _sums(qM_p_m_i, k -> (k[2], k[3], k[4]))
  for k in keys(qM_m_i)
    qM_m_i[k] = get(totals, k, 0.0)
  end
  return nothing
end