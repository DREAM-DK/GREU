# Raise labor productivity aProd by labor type and industry with the DA shock sheet, and
# add a fee that firms pay abroad for each person they employ.
# Both come by NACE leaf code from data/shock/DA_data_NACE.xlsx, columns G-K: the productivity
# increase from sheet "Stød", the fee share from sheet "Pris". Both apply from t1 in every year.
# Write the usual shock report and tables.
using XLSX
using SquareModels
import GREU: Settings, Time, loaded_module_by_name, base_model
import GREU.Government: vGovPrimaryBalance
import GREU.GovernmentExpenditure: vHhLumpSum
import GREU.GrowthInflationAdjustment: fv
import GREU.InputOutputSettings: industry_members
import GREU.LaborFee: rLaborFee_l_i, vLaborFeeBase
import GREU.Production: aProd, labor_l_i
import GREU.Time: T, tBase
import GREU.Log: @log_time

model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]

# ==============================================================================
# Shock settings
# ==============================================================================
# Choose the first shocked year
t1 = Time.t1 = 2026

# Fee base per person in DKK in the first shocked year. It grows with nominal growth after that.
fee_base_dkk = 10_000
dkk_per_eur = 7.46

# Create residual variables before loading their calibrated values.
block = base_model(model_modules) + loaded_module_by_name[:LaborFee].define_equations()
baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), block.model)

# ==============================================================================
# Shock definition
# ==============================================================================
da_file = XLSX.readxlsx(joinpath(@__DIR__, "data", "shock", "DA_data_NACE.xlsx"))
shock_sheet = da_file["Stød"][:]
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
"""Values by leaf code and labor type from columns G-K. Skip the rows without a code or a value, like NACE U and the unnamed total."""
function values_by_code(sheet)
  @assert startswith(sheet[1, 7], "AGGREGERET NACE") && startswith(sheet[1, 11], "NACE-kode") "Unexpected layout in columns G-K"
  rows = filter(row -> !any(ismissing, row[8:11]), collect(eachrow(sheet[2:end, :])))
  # The source uses sut_detail_codes. The resolution members use the Eurostat leaf codes with a dash.
  return Dict(
    (replace(row[11], "_" => "-"), labor_type_name[sheet[1, c]]) => Float64(row[c])
    for row in rows for c in 8:10
  )
end
fee_sheet = da_file["Pris"][:]
shock_by_code = values_by_code(shock_sheet)
fee_by_code = values_by_code(fee_sheet)

"""Average over the member codes with employees. A zero value marks a code without employees, like L68A."""
function industry_average(by_code, l, i)
  live = filter(!=(0.0), [get(by_code, (code, l), 0.0) for code in industry_members[i]])
  return isempty(live) ? 0.0 : sum(live) / length(live)
end
industry_shock(l, i) = industry_average(shock_by_code, l, i)
industry_fee(l, i) = industry_average(fee_by_code, l, i)

scenario = copy(baseline)
for (l, i) in labor_l_i
  scenario[aProd[l, i, t1:T]] .*= 1 + industry_shock(l, i)
  scenario[rLaborFee_l_i[l, i, t1:T]] .= industry_fee(l, i)
end
# Million EUR in model units, which are growth- and inflation-adjusted to the base year.
scenario[vLaborFeeBase[t1:T]] .= fee_base_dkk / dkk_per_eur / 1e6 / fv^(t1 - tBase)
# Hold the primary balance at baseline. A lump-sum transfer to households absorbs the change.
@endo_exo_swap! block begin
  vHhLumpSum[t1:T], vGovPrimaryBalance[t1:T]
end
@log_time solve!(block, scenario; start_values=baseline, run_test_constraints=false)

# Report settings
report_file = "da_shock_report.html"
tables_file = "da_shock_tables.html"
figures_file = "da_shock_figures.html"
figures_xlsx = "da_shock_figures.xlsx"
labor_types_file = "da_shock_labor_types.html"
shock_title = "DA labour productivity shock and fee per employed person by type and industry"
figures_title = "DA-stød til arbejdskraftsproduktivitet og gebyr pr. beskæftiget efter type og branche. Elasticiteter i produktionsfunktionen er fra GrønREFORM. Lump-sum lukning."

# ==============================================================================
# Write one HTML report for the solved scenario.
# ==============================================================================
include("ShockReport.jl")
shock_report = ShockReport.write_report(
  joinpath(@__DIR__, "..", "Output", report_file), baseline, scenario;
  shock_title,
  periods=(t1-1):T,
)

# One styled HTML report with six tables: the shock by industry and type, percentage
# deviations from baseline in 2050, and employment changes in persons.
# Then the same six tables as interactive bar charts in Danish, in the same order.
# The chart rows are also written as one Excel worksheet per chart.
# One more HTML file shows persons by labor type over time, and wage per person as lines.
# Industry and labor type names come from the shock sheet.
include("DAProductivityShockFigures.jl")
DAProductivityShockTables.write_tables(
    joinpath(@__DIR__, "..", "Output", "ShockTables", tables_file),
    baseline, scenario;
    shock=industry_shock,
    shock_title,
    year=2050
)
# Figures 02 and 03 show the fee per employed person: the share from sheet "Pris", then DKK.
# Set false to leave out figure 06, the percentage change in total employment by labor type.
include_total_employment = false
DAProductivityShockFigures.write_figures(
    joinpath(@__DIR__, "..", "Output", "ShockTables", figures_file),
    baseline, scenario;
    shock=industry_shock,
    fee=industry_fee,
    fee_base_dkk,
    shock_title=figures_title,
    year=2050,
    industry_name,
    type_name,
    include_total_employment,
)
DAProductivityShockFigures.write_excel(
    joinpath(@__DIR__, "..", "Output", "ShockTables", figures_xlsx),
    baseline, scenario;
    shock=industry_shock,
    fee=industry_fee,
    fee_base_dkk,
    year=2050,
    industry_name,
    type_name,
    include_total_employment,
)
# Persons by labor type over time, and wage per person for each type, in one HTML file.
DAProductivityShockFigures.write_labor_types(
    joinpath(@__DIR__, "..", "Output", "ShockTables", labor_types_file),
    baseline, scenario;
    shock_title=figures_title,
    type_name,
    years=t1:T,
)

# The government balance and its parts: shock less baseline, tables for chosen years and figures by year.
write_government_tables = true
government_table_years = [t1, 2030, 2040, 2050, 2060]
government_figure_years = t1:2065
if write_government_tables
  include("BaselineTables.jl")
  include("GovernmentTables.jl")
  GovernmentTables.write_tables(
    joinpath(@__DIR__, "..", "Output", "ShockTables", "da_shock_government_tables.html"), baseline;
    years=government_table_years, scenario, title="Government balance – $shock_title")
  GovernmentTables.write_figures(
    joinpath(@__DIR__, "..", "Output", "ShockTables", "da_shock_government_figures.html"), baseline;
    years=government_figure_years, scenario, title="Offentlig saldo – $figures_title")
end

unload(joinpath(@__DIR__, "..", "Output", "da_labor_productivity_shock.parquet"), scenario)
