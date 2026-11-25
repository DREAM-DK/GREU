# Run the DA labor productivity shock under the mirror closure.
# The rest of the world responds as the home economy does. See modules/MirrorClosure.jl.
# Cash transfers hold the government balance on its baseline share of GDP. See modules/FiscalClosure.jl.
# First solve a zero shock. The closures must return the baseline.
# The shock is the same as in DAProductivityShock.jl.
# Write the solved scenario, the usual shock report, and the tables.
using XLSX
using SquareModels
import GREU: Settings, Time, loaded_module_by_name, base_model, MirrorClosure, FiscalClosure
import GREU.InputOutputSettings: industry_members
import GREU.Production: aProd, labor_l_i
import GREU.Time: T
import GREU.Log: @log_time

model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]

# ==============================================================================
# Shock settings
# ==============================================================================
# Choose the first shocked year
t1 = Time.t1 = 2026

# Create residual variables before loading their calibrated values.
# A mirror equation replaces the base equation with the same endogenous variable.
# The fiscal rule adds one equation. The transfer rate is exogenous in the base model.
mirror = MirrorClosure.define_equations()
fiscal = FiscalClosure.define_equations()
closure_calibration = MirrorClosure.define_calibration(mirror) + FiscalClosure.define_calibration(fiscal)
block = base_model(model_modules) - mirror + mirror + fiscal
baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), block.model)

# ==============================================================================
# Closures
# ==============================================================================
# The baseline file has no closure values. Set the market factor to one. Then set the ratios,
# the net lending shares, the net asset targets, the price anchor, and the equity premiums
# from the baseline paths.
MirrorClosure.assign_data!(baseline)
FiscalClosure.assign_data!(baseline)
baseline[residuals(closure_calibration)] .= 0.0
@log_time solve!(closure_calibration, baseline; replace_nothing=1.0)

# Zero shock test: with no changes, the closures must return the baseline.
zero_shock = @log_time solve(block, baseline; run_test_constraints=false)
assert_no_diff(baseline, zero_shock; atol=1e-5, msg="Zero shock test failed under the closures")

# ==============================================================================
# Shock definition
# ==============================================================================
shock_sheet = XLSX.readxlsx(joinpath(@__DIR__, "data", "shock", "DA_data_NACE.xlsx"))["Stød"][:]
@assert startswith(shock_sheet[1, 7], "AGGREGERET NACE") && startswith(shock_sheet[1, 11], "NACE-kode") "Unexpected layout in columns G-K"
@assert startswith(shock_sheet[1, 1], "NR_69_titel") && startswith(shock_sheet[1, 5], "NACE-kode") "Unexpected layout in columns A-E"
labor_type_name = Dict("videregående" => :tertiary, "faglært" => :skilled, "ufaglært" => :unskilled)
type_name = Dict(l => name for (name, l) in labor_type_name)
# Danish NR69 titles from columns A and E. Several NR69 industries can share one leaf code.
title_rows = filter(row -> !ismissing(row[1]) && !ismissing(row[5]), collect(eachrow(shock_sheet[2:end, :])))
code_of(row) = replace(row[5], "_" => "-")
titles_by_code = Dict(code => unique(strip(row[1]) for row in title_rows if code_of(row) == code)
                      for code in unique(code_of.(title_rows)))
"""Danish titles of the member codes of industry `i`, then the model code."""
industry_name(i) = join(unique(reduce(vcat, [titles_by_code[code] for code in industry_members[i]])), "; ") * " ($(i))"
# Skip the rows without a code or without a shock, like NACE U and the unnamed total.
shock_rows = filter(row -> !any(ismissing, row[8:11]), collect(eachrow(shock_sheet[2:end, :])))
# The source uses sut_detail_codes. The resolution members use the Eurostat leaf codes with a dash.
shock_by_code = Dict(
  (replace(row[11], "_" => "-"), labor_type_name[shock_sheet[1, c]]) => Float64(row[c])
  for row in shock_rows for c in 8:10
)

"""Average the shock over the member codes with employees. A zero shock marks a code without employees, like L68A."""
function industry_shock(l, i)
  live = filter(!=(0.0), [get(shock_by_code, (code, l), 0.0) for code in industry_members[i]])
  return isempty(live) ? 0.0 : sum(live) / length(live)
end

scenario = copy(baseline)
for (l, i) in labor_l_i
  scenario[aProd[l, i, t1:T]] .*= 1 + industry_shock(l, i)
end
@log_time solve!(block, scenario; start_values=baseline, run_test_constraints=false)
unload(joinpath(@__DIR__, "..", "Output", "da_labor_productivity_shock_mirror.parquet"), scenario)

# Report settings
report_file = "da_labor_productivity_shock_mirror_report.html"
tables_file = "da_labor_productivity_shock_mirror_tables.html"
figures_file = "da_labor_productivity_shock_mirror_figures.html"
shock_title = "DA labour productivity shock by type and industry, mirror closure"
figures_title = "DA-stød til arbejdskraftsproduktivitet efter type og branche, spejlet udland"

# ==============================================================================
# Write one HTML report for the solved scenario.
# ==============================================================================
include("ShockReport.jl")
shock_report = ShockReport.write_report(
  joinpath(@__DIR__, "..", "Output", report_file), baseline, scenario;
  shock_title,
  periods=(t1-1):T,
)

# The same six tables and bar charts as in DAProductivityShock.jl.
include("DAProductivityShockFigures.jl")
DAProductivityShockTables.write_tables(
    joinpath(@__DIR__, "..", "Output", "ShockTables", tables_file),
    baseline, scenario;
    shock=industry_shock,
    shock_title,
    year=2050
)
DAProductivityShockFigures.write_figures(
    joinpath(@__DIR__, "..", "Output", "ShockTables", figures_file),
    baseline, scenario;
    shock=industry_shock,
    shock_title=figures_title,
    year=2050,
    industry_name,
    type_name,
)
