# Solve one shock scenario against the calibrated baseline and write its report.
# To create another experiment, copy this file and change the marked settings
# and shock definition below.
using SquareModels
import GREU: Settings, Time, loaded_module_by_name, base_model, Exports, Labor, PhillipsCurve, Production, SectorAccounts
import GREU.Labor: nLSupplyHh, nLSupplyRoW, ntL_l_i
import GREU.PhillipsCurve: snLSupplyHh_l, snLSupplyRoW_l
import GREU.Exports: qXMarket_p, qCTouristMarket
import GREU.Production: aProd, qFixedCost_i, vntProductionOther_i
import GREU.SectorAccounts: vSocialContributions, vSocialBenefits, vNetPensionSaving, vOtherTransfers, vNonProducedAssetAcquisitions
import GREU.Time: T
import GREU.Log: @log_time

include("ShockReport.jl")

model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]

# ==============================================================================
# Shock settings
# ==============================================================================
# Choose the first shocked year
t1 = Time.t1 = 2026

# Create residual variables before loading their calibrated values.
block = base_model(model_modules)
baseline = load(joinpath(@__DIR__, "..", "Output", "baseline.parquet"), block.model)

# ==============================================================================
# Shock definition
# ==============================================================================
scenario = copy(baseline)
scenario[PhillipsCurve.snLSupplyHh_l[:, t1:T]] .*= 1.01
scenario[PhillipsCurve.snLSupplyRoW_l[:, t1:T]] .*= 1.01
# scenario[Production.aProd[:labor, :, t1:T]] .*= 1.01
scenario[Production.qFixedCost_i[:, t1:T]] .*= 1.01
scenario[Labor.ntL_l_i[:, :, t1:T]] .*= 1.01
scenario[SectorAccounts.vSocialContributions[:, t1:T]] .*= 1.01
scenario[SectorAccounts.vSocialBenefits[[:FinCorp], t1:T]] .*= 1.01
scenario[SectorAccounts.vNetPensionSaving[t1:T]] .*= 1.01
scenario[SectorAccounts.vOtherTransfers[[:FinCorp, :NonFinCorp, :RoW], t1:T]] .*= 1.01
scenario[SectorAccounts.vNonProducedAssetAcquisitions[[:FinCorp, :NonFinCorp, :RoW], t1:T]] .*= 1.01
scenario[Production.vntProductionOther_i[:, t1:T]] .*= 1.01
scenario[Exports.qXMarket_p[:, t1:T]] .*= 1.01
scenario[Exports.qCTouristMarket[t1:T]] .*= 1.01

@log_time solve!(block, scenario; start_values=baseline, run_test_constraints=false)
unload(joinpath(@__DIR__, "..", "Output", "homogeniety_shock_productivity.parquet"), scenario)

# Report settings
report_file = "homogeniety_shock_productivity_report.html"
shock_title = "Homogeniety productivity shock"
# extra_figures=[]


# ==============================================================================
# Write one HTML report for the solved scenario.
# ==============================================================================
shock_report = ShockReport.write_report(
  joinpath(@__DIR__, "..", "Output", report_file), baseline, scenario;
  # extra_figures,
  shock_title,
  periods=(t1-1):T,
)

# One styled HTML report with three tables: percentage deviation from baseline in 2050.
include("ShockTables.jl")
ShockTables.write_tables(
    joinpath(@__DIR__, "..", "Output", "ShockTables"),
    baseline, scenario; year=2050
)


# Virksomhedernes værdi (prisen på aktierne) og porteføljen