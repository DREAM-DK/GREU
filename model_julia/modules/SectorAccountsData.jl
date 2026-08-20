include(joinpath(@__DIR__, "..", "Settings.jl"))
include("SectorAccountsSettings.jl")
include("EurostatClient.jl")
include("DataRefreshUtils.jl")

module SectorAccountsData

using CSV
using DataFrames
import ..EurostatClient
using ..Settings: calibration_year, country_code
import ..SectorAccountsSettings:
  fin_transactions_dataset_code,
  fin_transactions_unit,
  fin_transactions_dataset_code_2,
  fin_transactions_unit_2,
  fin_transactions_na_items,
  fin_transactions_equity_income_items,
  fin_transactions_debt_income_items,
  fin_transactions_transfer_items,
  fin_transactions_row_other_items,
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
import ..DataRefreshUtils: sum_by, long_format, write_index_set

# ==========================================================================
# Eurostat fetches
# ==========================================================================

function fetch_sector_accounts()
  df = EurostatClient.fetch_table(fin_transactions_dataset_code,
    "unit"        => fin_transactions_unit,
    "geo"         => country_code,
    "startPeriod" => string(calibration_year - 1),
    "endPeriod"   => string(calibration_year + 1),
    ("sector"  => s  for s in raw_sectors)...,
    ("na_item" => it for it in fin_transactions_na_items)...,
  )
  rename!(df, :time => :year)
  df.year = parse.(Int, df.year)
  return df[:, [:direct, :na_item, :sector, :year, :value]]
end

function fetch_fin_transactions()
  df = EurostatClient.fetch_table(fin_transactions_dataset_code_2,
    "unit"        => fin_transactions_unit_2,
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
# Data processing
# ==========================================================================

"""Shared processing for nasa_10_f_tr, nasa_10_f_bs, nasa_10_f_oc, and nasa_10_f_gl:
map sector/finpos codes and aggregate S14+S15 into Hh."""
function process_fin_instrument_data(df)
  df.sector = [get(sector_map,  s,  s)  for s  in df.sector]
  df.finpos = [get(finpos_map,  fp, fp) for fp in df.finpos]
  return sum_by(df, [:finpos, :na_item, :sector, :year])
end

function process_net_fin_transactions(df)
  # Map Eurostat sector codes to model sectors (S14, S15 both → Hh)
  df.sector = [get(sector_map, s, s) for s in df.sector]
  # Aggregate Hh (S14 + S15) so (direct, na_item, sector, year) is unique
  df = sum_by(df, [:direct, :na_item, :sector, :year])

  # ------------------------------------------------------------------
  # Reallocate Hh mixed income (B2A3G) to NonFinCorp.
  # The B2A3G_correction item carries the offsetting transfer:
  #   RECV for Hh  → used as vCorrectionNonFinCorp2Hh
  #   PAID for NonFinCorp → appears as an outflow in transfer NET calculations
  # ------------------------------------------------------------------
  mask = (df.direct .== "RECV") .& (df.na_item .== "B2A3G") .& (df.sector .== "Hh")

  correction_recv_hh = copy(df[mask, :])
  correction_recv_hh.na_item .= "B2A3G_correction"

  correction_paid_nonfincorp = copy(correction_recv_hh)
  correction_paid_nonfincorp.sector .= "NonFinCorp"
  correction_paid_nonfincorp.direct .= "PAID"

  df = vcat(df, correction_recv_hh, correction_paid_nonfincorp)

  # Add Hh mixed income into the existing (RECV, B2A3G, NonFinCorp) row so that
  # vGrossOpSurplusMixedIncome[:NonFinCorp] = NonFinCorp operating surplus + Hh mixed income.
  corr_key = select(correction_recv_hh, :year, :value => :corr)
  insertcols!(corr_key, :direct => "RECV", :na_item => "B2A3G", :sector => "NonFinCorp")
  df = leftjoin(df, corr_key, on = [:direct, :na_item, :sector, :year])
  df.value .+= coalesce.(df.corr, 0.0)
  select!(df, Not(:corr))

  return df
end

# ==========================================================================
# Net financial transactions items helpers  (nasa_10_nf_tr)
# ==========================================================================

"""Net flow (RECV − PAID) for na_item(s), grouped by (sector, year)."""
function get_net_fin_transactions_item_helper_function(df, items)
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
function get_net_fin_transactions_item(df, items, flow_type, sectors = nothing)
  items_set = items isa AbstractString ? Set([items]) : Set(items)
  if flow_type == "NET"
    result = get_net_fin_transactions_item_helper_function(df, items_set)
  else
    mask   = (df.na_item .∈ Ref(items_set)) .& (df.direct .== flow_type)
    result = sum_by(df[mask, :], [:sector, :year])
  end
  sectors === nothing && return result
  return result[result.sector .∈ Ref(Set(sectors)), :]
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
      let d = get_net_fin_transactions_item(flow_df, items, dir); d.f .= f; d.al .= al; d end
      for (items, dir, f, al) in [
        (fin_transactions_equity_income_items, "RECV", "Equity", finpos_map["ASS"]),
        (fin_transactions_equity_income_items, "PAID", "Equity", finpos_map["LIAB"]),
        (fin_transactions_debt_income_items,   "RECV", "Debt",   finpos_map["ASS"]),
        (fin_transactions_debt_income_items,   "PAID", "Debt",   finpos_map["LIAB"]),
      ]
    ]...),
    vNetFinTransactions                  = get_net_fin_transactions_item(flow_df, "B9",           "RECV"),
    vNetTransfers2sector                 = get_net_fin_transactions_item(flow_df, fin_transactions_transfer_items, "NET",  ["FinCorp", "NonFinCorp", "Hh"]),
    vGrossCapitalFormation               = get_net_fin_transactions_item(flow_df, "P5G",          "PAID", ["FinCorp", "NonFinCorp", "Hh"]),
    vGrossOpSurplusMixedIncome           = get_net_fin_transactions_item(flow_df, "B2A3G",        "RECV", ["FinCorp", "NonFinCorp"]),
    vNonFinancialNonProducedAssets       = get_net_fin_transactions_item(flow_df, "NP",           "PAID", ["FinCorp", "NonFinCorp", "Hh", "RoW"]),

    # Households
    vHhConsumption                       = select(get_net_fin_transactions_item(flow_df, "P3",               "PAID", ["Hh"]), :year, :value),
    vHhWages                             = select(get_net_fin_transactions_item(flow_df, "D1",               "RECV", ["Hh"]), :year, :value),
    vCorrectionNonFinCorp2Hh             = select(get_net_fin_transactions_item(flow_df, "B2A3G_correction", "RECV", ["Hh"]), :year, :value),

    # Rest of World
    vRoWPrimaryIncomeCurrentBalanceOther = select(get_net_fin_transactions_item(flow_df, fin_transactions_row_other_items, "NET", ["RoW"]), :year, :value),
    vExports                             = select(get_net_fin_transactions_item(flow_df, "P6", "PAID", ["RoW"]), :year, :value),
    vImports                             = select(get_net_fin_transactions_item(flow_df, "P7", "RECV", ["RoW"]), :year, :value),
    vRoWNetWages                         = select(get_net_fin_transactions_item(flow_df, "D1", "NET", ["RoW"]), :year, :value),

    # Financial balance sheet  (nasa_10_f_bs)
    vFinAL = fin_bal_by_instrument(bal_df),

    # Total financial assets/liabilities (F − F11 Monetary gold) by sector
    vFinAssets = rename!(fin_bal_sum_minus_f11(bal_df, "F"), :finpos => :al),

   # Financial transactions  (nasa_10_f_tr)
   vFinTransactions = fin_bal_by_instrument(tr_df),

    # Other changes in volume  (nasa_10_f_oc)
    vOtherChangesInVolume = fin_bal_by_instrument(oc_df),

    # Revaluations / holding gains  (nasa_10_f_gl)
    vFinReval = fin_bal_by_instrument(rev_df),
  )
end

# ==========================================================================
# Output files
# ==========================================================================

function write_indices(dir, params)
  fin = params.vFinIncome
  write_index_set(joinpath(dir, "sector_accounts_sectors.csv"),        "sectors",         sort(unique(fin.sector)))
  write_index_set(joinpath(dir, "sector_accounts_ass_liab.csv"),       "ass_liab",        sort(unique(fin.al)))
  write_index_set(joinpath(dir, "sector_accounts_fin_instruments.csv"),"fin_instruments", sort(unique(fin.f)))
end

"""All sector-account variables in a single file."""
function write_sector_flows(dir, params)
  CSV.write(joinpath(dir, "sector_accounts.csv"), vcat(
    long_format(:vFinIncome,                               params.vFinIncome,                               [:sector, :f, :al, :year]),
    long_format(:vNetFinTransactions,                      params.vNetFinTransactions,                      [:sector, :year]),
    long_format(:vNetTransfers2sector,                     params.vNetTransfers2sector,                     [:sector, :year]),
    long_format(:vGrossCapitalFormation,                   params.vGrossCapitalFormation,                   [:sector, :year]),
    long_format(:vGrossOpSurplusMixedIncome,               params.vGrossOpSurplusMixedIncome,               [:sector, :year]),
    long_format(:vNonFinancialNonProducedAssets,           params.vNonFinancialNonProducedAssets,           [:sector, :year]),
    long_format(:vNetTransfers2sector,                     params.vNetTransfers2sector,                     [:sector, :year]),
    long_format(:vHhConsumption,                           params.vHhConsumption,                           [:year]),
    long_format(:vHhWages,                                 params.vHhWages,                                 [:year]),
    long_format(:vCorrectionNonFinCorp2Hh,                 params.vCorrectionNonFinCorp2Hh,                 [:year]),
    long_format(:vRoWPrimaryIncomeCurrentBalanceOther,     params.vRoWPrimaryIncomeCurrentBalanceOther,     [:year]),
    long_format(:vExports,                                 params.vExports,                                 [:year]),
    long_format(:vImports,                                 params.vImports,                                 [:year]),
    long_format(:vRoWNetWages,                             params.vRoWNetWages,                             [:year]),
    long_format(:vFinTransactions,                         params.vFinTransactions,                         [:sector, :f, :al, :year]),
    long_format(:vFinAL,                                   params.vFinAL,                                   [:sector, :f, :al, :year]),
    long_format(:vFinAssets,                               params.vFinAssets,                               [:sector, :al, :year]),
    long_format(:vOtherChangesInVolume,                    params.vOtherChangesInVolume,                         [:sector, :f, :al, :year]),
    long_format(:vFinReval,                                params.vFinReval,                                [:sector, :f, :al, :year]),
  ))
end

function refresh_sector_accounts_data!(dir = sector_accounts_data_dir)
  mkpath(dir)
  flow_df = process_net_fin_transactions(fetch_sector_accounts())
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
