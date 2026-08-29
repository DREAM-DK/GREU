# Fetch and store sector-account and financial-account data.
# Store non-financial source and net rows in model-readable form.
# Map transfer items in SectorAccounts.assign_data!.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("SectorAccountsSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module SectorAccountsData

using CSV
using DataFrames
import ..EurostatClient
using ..Settings: calibration_year, country_code
import ..SectorAccountsSettings:
  non_financial_transactions_dataset_code,
  non_financial_transactions_unit,
  financial_transactions_dataset_code,
  financial_transactions_unit,
  non_financial_transaction_items,
  equity_income_items,
  debt_income_items,
  fin_other_changes_dataset_code,
  fin_other_changes_unit,
  fin_revaluation_dataset_code,
  fin_revaluation_unit,
  fin_bal_dataset_code,
  fin_bal_equity_na_items,
  fin_bal_na_items,
  fin_tr_na_items,
  fin_bal_raw_finpos,
  fin_bal_unit,
  finpos_map,
  raw_sectors,
  sector_accounts_data_dir,
  sector_map

sum_by(df, cols) = combine(groupby(df, cols), :value => (x -> sum(skipmissing(x); init=0.0)) => :value)
import ..DataUtils: long_format, write_index_set

# ==========================================================================
# Sector and financial tables
# ==========================================================================

function fetch_non_financial_transactions()
  df = EurostatClient.fetch_table(non_financial_transactions_dataset_code,
    "unit"        => non_financial_transactions_unit,
    "geo"         => country_code,
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("sector"  => s  for s in raw_sectors)...,
    ("na_item" => it for it in non_financial_transaction_items)...,
  )
  rename!(df, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:direct, :na_item, :sector, :year, :value]]
end

function fetch_fin_transactions()
  df = EurostatClient.fetch_table(financial_transactions_dataset_code,
    "unit"        => financial_transactions_unit,
    "geo"         => country_code,
    "co_nco"      => "CO",
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("sector"  => s  for s in raw_sectors)...,
    ("na_item" => it for it in fin_tr_na_items)...,
    ("finpos"  => fp for fp in fin_bal_raw_finpos)...,
  )
  rename!(df, :time => :year)
  df.year = parse.(Int, df.year)
  df.na_item = replace.(df.na_item, "F_TR" => "F")
  return df[:, [:finpos, :na_item, :sector, :year, :value]]
end

function fetch_fin_other_changes()
  df = EurostatClient.fetch_table(fin_other_changes_dataset_code,
    "unit"        => fin_other_changes_unit,
    "geo"         => country_code,
    "co_nco"      => "CO",
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("sector"  => s  for s in raw_sectors)...,
    ("na_item" => it for it in fin_bal_na_items)...,
    ("finpos"  => fp for fp in fin_bal_raw_finpos)...,
  )
  rename!(df, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:finpos, :na_item, :sector, :year, :value]]
end

function fetch_fin_revaluation()
  df = EurostatClient.fetch_table(fin_revaluation_dataset_code,
    "unit"        => fin_revaluation_unit,
    "geo"         => country_code,
    "co_nco"      => "CO",
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("sector"  => s  for s in raw_sectors)...,
    ("na_item" => it for it in fin_bal_na_items)...,
    ("finpos"  => fp for fp in fin_bal_raw_finpos)...,
  )
  rename!(df, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:finpos, :na_item, :sector, :year, :value]]
end

function fetch_fin_accounts_balance()
  df = EurostatClient.fetch_table(fin_bal_dataset_code,
    "unit"        => fin_bal_unit,
    "geo"         => country_code,
    "co_nco"      => "CO",
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("sector"  => s  for s in raw_sectors)...,
    ("na_item" => it for it in fin_bal_na_items)...,
    ("finpos"  => fp for fp in fin_bal_raw_finpos)...,
  )
  rename!(df, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:finpos, :na_item, :sector, :year, :value]]
end

# ==========================================================================
# Sector maps
# ==========================================================================

"""Shared processing for nasa_10_f_tr, nasa_10_f_bs, nasa_10_f_oc, and nasa_10_f_gl:
map sector/finpos codes and aggregate S14+S15 into Hh."""
function process_fin_instrument_data(df)
  df.sector = [get(sector_map,  s,  s)  for s  in df.sector]
  df.finpos = [get(finpos_map,  fp, fp) for fp in df.finpos]
  return sum_by(df, [:finpos, :na_item, :sector, :year])
end

function process_non_financial_transactions(df)
  # Map Eurostat sector codes to model sectors (S14, S15 both → Hh)
  df.sector = [get(sector_map, s, s) for s in df.sector]
  # Aggregate Hh (S14 + S15) so (direct, na_item, sector, year) is unique
  return sum_by(df, [:direct, :na_item, :sector, :year])
end

# ==========================================================================
# Non-financial transaction helpers  (nasa_10_nf_tr)
# ==========================================================================

"""Net flow (RECV − PAID) for na_item(s), grouped by (sector, year)."""
function get_net_non_financial_transactions(df, items)
  items_set = items isa AbstractString ? Set([items]) : Set(items)
  flows = sum_by(df[df.na_item .∈ Ref(items_set), :], [:sector, :year, :direct])
  recv  = flows[flows.direct .== "RECV", [:sector, :year, :value]]
  paid  = flows[flows.direct .== "PAID", [:sector, :year, :value]]
  joined = outerjoin(recv, paid, on = [:sector, :year], makeunique = true)
  return DataFrame(
    sector = joined.sector,
    year   = joined.year,
    value  = coalesce.(joined.value,   0.0) .-
             coalesce.(joined.value_1, 0.0),
  )
end

"""Flows for na_item(s) and flow_type ('RECV', 'PAID', or 'NET').

sectors: optional list of sector labels to keep; nothing means all sectors.
"""
function get_non_financial_transaction(df, items, flow_type, sectors = nothing)
  items_set = items isa AbstractString ? Set([items]) : Set(items)
  if flow_type == "NET"
    result = get_net_non_financial_transactions(df, items_set)
  else
    mask   = (df.na_item .∈ Ref(items_set)) .& (df.direct .== flow_type)
    result = sum_by(df[mask, :], [:sector, :year])
  end
  sectors === nothing && return result
  return result[result.sector .∈ Ref(Set(sectors)), :]
end

function net_non_financial_transactions(df)
  flows = unstack(df, [:sector, :na_item, :year], :direct, :value; fill=0.0)
  flows.value = flows.RECV .- flows.PAID
  return select(flows, :sector, :na_item, :year, :value)
end

# ==========================================================================
# Financial instrument helpers  (nasa_10_f_tr, nasa_10_f_bs, nasa_10_f_oc, nasa_10_f_gl)
# ==========================================================================

"""Aggregate values for the given na_item codes, grouped by (sector, finpos, year)."""
function fin_bal_sum(df, items)
  items_set = items isa AbstractString ? Set([items]) : Set(items)
  return sum_by(df[df.na_item .∈ Ref(items_set), :], [:sector, :finpos, :year])
end

"""Subtract `sub` from `base`, aligned on (sector, finpos, year)."""
function fin_bal_minus(base, sub)
  joined = leftjoin(base, sub, on = [:sector, :finpos, :year], makeunique = true)
  joined.value .= joined.value .- coalesce.(joined.value_1, 0.0)
  return select(joined, [:sector, :finpos, :year, :value])
end

"""Sum `items` and subtract `subtract_items`, grouped by (sector, finpos, year)."""
fin_bal_sum_minus(df, items, subtract_items) =
  fin_bal_minus(fin_bal_sum(df, items), fin_bal_sum(df, subtract_items))

"""Sum na_items and subtract the F11 (Monetary gold) component."""
fin_bal_sum_minus_f11(df, items) = fin_bal_sum_minus(df, items, "F11")

"""Debt instruments: total F minus equity minus F11 (Monetary gold)."""
fin_bal_debt(df) = fin_bal_sum_minus(df, "F", [fin_bal_equity_na_items; "F11"])

"""Split financial instruments into Debt (F − equity − F11) and Equity."""
function fin_bal_by_instrument(df)
  rename!(vcat(
    let d = fin_bal_debt(df);                         d.f .= "Debt";   d end,
    let d = fin_bal_sum(df, fin_bal_equity_na_items); d.f .= "Equity"; d end,
  ), :finpos => :al)
end

function build_parameters(flow_df, tr_df, bal_df, oc_df, rev_df)
  return (;
    # ------------------------------------------------------------------
    # Non-financial transactions  (nasa_10_nf_tr)
    # ------------------------------------------------------------------

    vFinIncome = vcat([
      let d = get_non_financial_transaction(flow_df, "D4", dir); d.al .= al; d end
      for (dir, al) in [
        ("RECV", finpos_map["ASS"]),
        ("PAID", finpos_map["LIAB"]),
      ]
    ]...),
    vFinIncome_s_f = vcat([
      let d = get_non_financial_transaction(flow_df, items, dir); d.f .= f; d.al .= al; d end
      for (items, dir, f, al) in [
        (equity_income_items, "RECV", "Equity", finpos_map["ASS"]),
        (equity_income_items, "PAID", "Equity", finpos_map["LIAB"]),
        (debt_income_items,   "RECV", "Debt",   finpos_map["ASS"]),
        (debt_income_items,   "PAID", "Debt",   finpos_map["LIAB"]),
      ]
    ]...),
    vNetFinTransactions                  = get_non_financial_transaction(flow_df, "B9", "RECV"),
    vI_s                                 = get_non_financial_transaction(flow_df, "P5G", "PAID", ["FinCorp", "NonFinCorp", "Gov", "Hh"]),
    vGrossOpSurplusMixedIncome           = get_non_financial_transaction(flow_df, "B2A3G", "RECV", ["FinCorp", "NonFinCorp", "Gov", "Hh"]),

    # Households
    vHhConsumption                       = select(get_non_financial_transaction(flow_df, "P3",               "PAID", ["Hh"]), :year, :value),
    vHhWages                             = select(get_non_financial_transaction(flow_df, "D1",               "RECV", ["Hh"]), :year, :value),
    # Rest of World
    vRoWNetWages                         = select(get_non_financial_transaction(flow_df, "D1", "NET", ["RoW"]), :year, :value),

    # Financial balance sheet  (nasa_10_f_bs)
    vFinPosition_s_f = fin_bal_by_instrument(bal_df),

    # Total financial assets/liabilities (F − F11 Monetary gold) by sector
    vFinAssets = rename!(fin_bal_sum_minus_f11(bal_df, "F"), :finpos => :al),

    # Financial transactions  (nasa_10_f_tr)
    vFinTransactions_f = fin_bal_by_instrument(tr_df),

    # Other changes in volume  (nasa_10_f_oc)
    vOtherChangesInVolume_f = fin_bal_by_instrument(oc_df),

    # Revaluations / holding gains  (nasa_10_f_gl)
    vFinReval_s_f = fin_bal_by_instrument(rev_df),
  )
end

# ==========================================================================
# Refresh
# ==========================================================================

function write_indices(dir, params)
  fin = params.vFinIncome_s_f
  write_index_set(joinpath(dir, "sector_accounts_sectors.csv"),        "sectors",         sort(unique(fin.sector)))
  write_index_set(joinpath(dir, "sector_accounts_ass_liab.csv"),       "ass_liab",        sort(unique(fin.al)))
  write_index_set(joinpath(dir, "sector_accounts_fin_instruments.csv"),"fin_instruments", sort(unique(fin.f)))
end

function write_non_financial_transactions(dir, flow_df)
  net_flow_df = net_non_financial_transactions(flow_df)
  CSV.write(joinpath(dir, "non_financial_transactions.csv"), vcat(
    long_format(:NonFinancialTransactions,    flow_df,     [:sector, :na_item, :direct, :year]),
    long_format(:NetNonFinancialTransactions, net_flow_df, [:sector, :na_item, :year]),
  ))
end

"""All sector-account variables in a single file."""
function write_sector_flows(dir, params)
  sectors = sort(unique(params.vFinIncome_s_f.sector))
  @assert all(any(row.sector == s && row.year == calibration_year for row in eachrow(params.vNetFinTransactions)) for s in sectors) "Each sector needs net financial transactions"
  @assert all(any(row.sector == s && row.al == al && row.year == calibration_year for row in eachrow(params.vFinAssets)) for s in sectors, al in ("Assets", "Liab")) "Each sector needs financial assets and liabilities"
  vGovBalance = select(params.vNetFinTransactions[params.vNetFinTransactions.sector .== "Gov", :], :year, :value)
  vNetFinAssets = combine(groupby(params.vFinAssets, [:sector, :year]), sdf -> (; value = only(sdf.value[sdf.al .== "Assets"]) - only(sdf.value[sdf.al .== "Liab"])))
  CSV.write(joinpath(dir, "sector_accounts.csv"), vcat(
    long_format(:vFinIncome,                               params.vFinIncome,                               [:sector, :al, :year]),
    long_format(:vFinIncome_s_f,                             params.vFinIncome_s_f,                             [:sector, :f, :al, :year]),
    long_format(:vNetFinTransactions,                      params.vNetFinTransactions,                      [:sector, :year]),
    long_format(:vI_s,                                     params.vI_s,                                     [:sector, :year]),
    long_format(:vGrossOpSurplusMixedIncome,               params.vGrossOpSurplusMixedIncome,               [:sector, :year]),
    long_format(:vHhConsumption,                           params.vHhConsumption,                           [:year]),
    long_format(:vHhWages,                                 params.vHhWages,                                 [:year]),
    long_format(:vRoWNetWages,                             params.vRoWNetWages,                             [:year]),
    long_format(:vFinTransactions_f,                       params.vFinTransactions_f,                       [:sector, :f, :al, :year]),
    long_format(:vFinPosition_s_f,                           params.vFinPosition_s_f,                           [:sector, :f, :al, :year]),
    long_format(:vOtherChangesInVolume_f,                  params.vOtherChangesInVolume_f,                  [:sector, :f, :al, :year]),
    long_format(:vFinReval_s_f,                              params.vFinReval_s_f,                              [:sector, :f, :al, :year]),
    long_format(:vGovBalance,                              vGovBalance,                                     [:year]),
    long_format(:vNetFinAssets,                            vNetFinAssets,                                   [:sector, :year]),
  ))
end

function refresh_sector_accounts_data!(dir = sector_accounts_data_dir)
  mkpath(dir)
  flow_df = process_non_financial_transactions(fetch_non_financial_transactions())
  write_non_financial_transactions(dir, flow_df)
  tr_df   = process_fin_instrument_data(fetch_fin_transactions())
  bal_df  = process_fin_instrument_data(fetch_fin_accounts_balance())
  oc_df   = process_fin_instrument_data(fetch_fin_other_changes())
  rev_df  = process_fin_instrument_data(fetch_fin_revaluation())
  params  = build_parameters(flow_df, tr_df, bal_df, oc_df, rev_df)
  write_indices(dir, params)
  write_sector_flows(dir, params)
  return params
end

end # module
