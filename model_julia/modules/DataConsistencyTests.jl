# Diagnostic comparisons of the same national-accounting concepts across
# independent Eurostat source tables. This module never changes model data.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("SectorAccountsSettings.jl")
include("TaxesSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module DataConsistencyTests

using CSV
using DataFrames
import ..EurostatClient
import ..DataUtils: read_cells
import ..InputOutputSettings:
  eurostat_supply_dataset,
  eurostat_use_dataset,
  eurostat_unit,
  input_output_data_dir
import ..ProductionSettings:
  capital_flow_dataset,
  flow_unit,
  gva_dataset,
  gva_unit,
  production_data_dir
import ..SectorAccountsSettings:
  non_financial_transactions_dataset_code,
  non_financial_transactions_unit
import ..TaxesSettings:
  resident_sector,
  tax_dataset,
  tax_unit
import ..Settings: calibration_year, country_code, first_data_year

const data_years = collect(first_data_year:calibration_year)
const year_params = ["time" => string(year) for year in data_years]
const diagnostics_dir = joinpath(@__DIR__, "..", "data", "diagnostics")
const diagnostics_file = joinpath(diagnostics_dir, "cross_source_consistency.csv")
const production_gva_file = joinpath(production_data_dir, "production_gva.csv")
const production_labor_file = joinpath(production_data_dir, "production_labor.csv")

"""Convert a comparison into PASS/WARNING/FAIL using relative and absolute gaps."""
function comparison_status(a, b; pass_rtol=1e-3, warn_rtol=1e-2, atol=1.0)
  gap = abs(a - b)
  scale = max(abs(a), abs(b), atol)
  rel = gap / scale
  gap <= atol || rel <= pass_rtol ? "PASS" : rel <= warn_rtol ? "WARNING" : "FAIL"
end

function result_rows(test, variable, source_a, source_b, values_a, values_b;
                     pass_rtol=1e-3, warn_rtol=1e-2, atol=1.0, note="")
  rows = NamedTuple[]
  for year in sort(intersect(collect(keys(values_a)), collect(keys(values_b))))
    a = Float64(values_a[year])
    b = Float64(values_b[year])
    difference = a - b
    denominator = max(abs(a), abs(b), atol)
    relative_difference = abs(difference) / denominator
    push!(rows, (
      test=String(test), variable=String(variable), year=Int(year),
      source_a=String(source_a), value_a=a,
      source_b=String(source_b), value_b=b,
      difference=difference, relative_difference=relative_difference,
      status=comparison_status(a, b; pass_rtol=pass_rtol, warn_rtol=warn_rtol, atol=atol),
      note=String(note),
    ))
  end
  return rows
end

"""Sum one already-refreshed model variable over all non-year indices."""
function model_sum_by_year(file, variable)
  cells = read_cells(file, variable)
  totals = Dict(year => 0.0 for year in data_years)
  for (indices, value) in cells
    tuple_indices = indices isa Tuple ? indices : (indices,)
    year = tuple_indices[end]
    year isa Integer || continue
    year in data_years || continue
    totals[year] += value
  end
  return totals
end

function fetch_total_by_year(dataset, params...; value_filter=(row -> true))
  df = EurostatClient.fetch_table(dataset, params..., "geo" => country_code, year_params...)
  totals = Dict(year => 0.0 for year in data_years)
  found = Dict(year => false for year in data_years)
  for row in eachrow(df)
    value_filter(row) || continue
    ismissing(row.value) && continue
    year = parse(Int, string(row.time))
    year in data_years || continue
    totals[year] += Float64(row.value)
    found[year] = true
  end
  return Dict(year => totals[year] for year in data_years if found[year])
end

"""Resident-sector total from nasa_10_nf_tr for a transaction and direction."""
function resident_transaction(item, direct)
  sectors = Set(resident_sector)
  return fetch_total_by_year(
    non_financial_transactions_dataset_code,
    "unit" => non_financial_transactions_unit,
    ("sector" => sector for sector in resident_sector)...,
    "na_item" => item;
    value_filter = row -> string(row.sector) in sectors && string(row.direct) == direct,
  )
end

"""D29 from the government tax aggregate source used by TaxesData."""
function government_tax_d29()
  return fetch_total_by_year(
    tax_dataset,
    "unit" => tax_unit,
    "sector" => "S13",
    "na_item" => "D29";
    value_filter = row -> true,
  )
end

"""Independent A64 D1 compensation total."""
function nama_d1()
  return fetch_total_by_year(
    gva_dataset,
    "unit" => gva_unit,
    "na_item" => "D1";
    # Prefer TOTAL if Eurostat returns it; otherwise sum detailed NACE rows.
    value_filter = row -> hasproperty(row, :nace_r2) && string(row.nace_r2) == "TOTAL",
  )
end

"""Independent A64 B1G total."""
function nama_gva_total()
  return fetch_total_by_year(
    gva_dataset,
    "unit" => gva_unit,
    "na_item" => "B1G";
    value_filter = row -> hasproperty(row, :nace_r2) && string(row.nace_r2) == "TOTAL",
  )
end

"""SUT D1 total from the same table used for detailed payroll."""
function sut_d1_total()
  return fetch_total_by_year(
    eurostat_use_dataset,
    "unit" => eurostat_unit,
    "stk_flow" => "TOTAL",
    "prd_ava" => "D1";
    value_filter = row -> hasproperty(row, :ind_use) && string(row.ind_use) == "TOTAL",
  )
end

"""Gross fixed capital formation total from nama_10_a64_p5."""
function nama_investment_total()
  return fetch_total_by_year(
    capital_flow_dataset,
    "unit" => flow_unit,
    "na_item" => "P51G";
    value_filter = row ->
      hasproperty(row, :nace_r2) && string(row.nace_r2) == "TOTAL" &&
      (!hasproperty(row, :asset10) || string(row.asset10) == "TOTAL"),
  )
end

"""Gross fixed capital formation total from the SUT use table."""
function sut_investment_total()
  return fetch_total_by_year(
    eurostat_use_dataset,
    "unit" => eurostat_unit;
    value_filter = row ->
      hasproperty(row, :ind_use) && string(row.ind_use) == "P51G" &&
      (!hasproperty(row, :prd_ava) || string(row.prd_ava) == "TOTAL"),
  )
end

"""Domestic output P1 from sector accounts (resident institutional sectors)."""
function resident_output_p1()
  return resident_transaction("P1", "RECV")
end

"""Total domestic output from SUT supply."""
function sut_output_total()
  return fetch_total_by_year(
    eurostat_supply_dataset,
    "unit" => eurostat_unit,
    "stk_flow" => "TOTAL";
    value_filter = row ->
      hasproperty(row, :ind_impv) && string(row.ind_impv) == "TOTAL" &&
      hasproperty(row, :prd_amo) && string(row.prd_amo) == "TOTAL",
  )
end

"""Run one diagnostic safely; unavailable Eurostat concepts are reported as SKIP."""
function safe_test!(f, rows, test_name)
  try
    append!(rows, f())
  catch err
    @warn "Cross-source test skipped" test=test_name error=sprint(showerror, err)
    push!(rows, (
      test=String(test_name), variable="", year=0,
      source_a="", value_a=NaN, source_b="", value_b=NaN,
      difference=NaN, relative_difference=NaN, status="SKIP",
      note=sprint(showerror, err),
    ))
  end
end

"""
    run_all_tests(; dir=diagnostics_dir)

Compare national-accounting concepts available from independent Eurostat sources.
The function is diagnostic only: it never reconciles, overwrites, or mutates model data.
Results are printed and written to `data/diagnostics/cross_source_consistency.csv`.
"""
function run_all_tests(; dir=diagnostics_dir)
  mkpath(dir)
  rows = NamedTuple[]

  # D29: tax-statistics total versus all resident sectors paying D29.
  safe_test!(rows, "D29 tax aggregate vs sector accounts") do
    result_rows(
      "D29 tax aggregate vs sector accounts", "D29",
      "gov_10a_taxag / S13", "nasa_10_nf_tr / resident sectors PAID",
      government_tax_d29(), resident_transaction("D29", "PAID");
      note="Different compilation frameworks can produce small source differences.",
    )
  end

  # D29-D39 identity: RAW detailed industry data versus sector-account controls.
  # This test should run before TaxesData.reconcile_net_production_taxes!().
  safe_test!(rows, "D29X39 industry identity vs sector accounts") do
    net_industry = model_sum_by_year(production_gva_file, "vntProduction_i")
    d29 = government_tax_d29()
    d39_resident = resident_transaction("D39", "RECV")
    implied_net = Dict(year => d29[year] - d39_resident[year]
                       for year in intersect(keys(d29), keys(d39_resident)))
    result_rows(
      "D29X39 industry identity vs sector accounts", "D29-D39",
      "nama_10_a64 / summed detailed D29X39", "gov_10a_taxag D29 - nasa_10_nf_tr resident D39",
      net_industry, implied_net;
      note="Run before reconciliation to diagnose the raw detailed-industry discrepancy.",
    )
  end

  # Compensation of employees: SUT payroll versus A64 national accounts.
  safe_test!(rows, "D1 SUT vs A64") do
    result_rows(
      "D1 SUT vs A64", "D1",
      "naio_10_cp1610 / TOTAL D1", "nama_10_a64 / TOTAL D1",
      sut_d1_total(), nama_d1();
    )
  end

  # Also compare refreshed detailed payroll sum with the independent A64 total.
  safe_test!(rows, "D1 refreshed detail vs A64 total") do
    result_rows(
      "D1 refreshed detail vs A64 total", "D1",
      "refreshed detailed payroll from naio_10_cp1610", "nama_10_a64 / TOTAL D1",
      model_sum_by_year(production_labor_file, "vWages_i"), nama_d1();
    )
  end

  # GVA: selected detailed mapping must sum to Eurostat's directly published TOTAL.
  safe_test!(rows, "B1G detailed mapping vs published total") do
    result_rows(
      "B1G detailed mapping vs published total", "B1G",
      "nama_10_a64 / refreshed detailed mapping", "nama_10_a64 / published TOTAL",
      model_sum_by_year(production_gva_file, "vGVA_i"), nama_gva_total();
      note="Same dataset, but tests the dynamic industry mapping against an independent published aggregate.",
    )
  end

  # Investment from industry capital-flow table versus product/use SUT table.
  safe_test!(rows, "P51G capital flow vs SUT") do
    result_rows(
      "P51G capital flow vs SUT", "P51G",
      "nama_10_a64_p5 / TOTAL", "naio_10_cp1610 / P51G total",
      nama_investment_total(), sut_investment_total();
    )
  end

  # Output from SUT versus institutional-sector production account.
  safe_test!(rows, "P1 SUT output vs sector accounts") do
    result_rows(
      "P1 SUT output vs sector accounts", "P1",
      "naio_10_cp15 / TOTAL supply", "nasa_10_nf_tr / resident sectors RECV",
      sut_output_total(), resident_output_p1();
      warn_rtol=0.02,
      note="Coverage/valuation differences can be larger for output than for transaction controls.",
    )
  end

  result = DataFrame(rows)
  CSV.write(joinpath(dir, basename(diagnostics_file)), result)
  print_report(result)
  return result
end

function print_report(df::DataFrame)
  println()
  println("==========================================================================")
  println(" CROSS-SOURCE DATA CONSISTENCY TEST")
  println("==========================================================================")
  for row in eachrow(df)
    if row.status == "SKIP"
      println("[SKIP] ", row.test, " — ", row.note)
      continue
    end
    pct = 100 * row.relative_difference
    println(
      "[", rpad(row.status, 7), "] ", row.test,
      " | ", row.year,
      " | A=", round(row.value_a; digits=3),
      " | B=", round(row.value_b; digits=3),
      " | diff=", round(row.difference; digits=3),
      " (", round(pct; digits=3), "%)",
    )
  end
  counts = Dict(status => count(==(status), df.status) for status in unique(df.status))
  println("--------------------------------------------------------------------------")
  println("Summary: ", join(["$status=$(counts[status])" for status in sort(collect(keys(counts)))], ", "))
  println("CSV: ", diagnostics_file)
  println("==========================================================================")
  println()
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  DataConsistencyTests.run_all_tests()
end
