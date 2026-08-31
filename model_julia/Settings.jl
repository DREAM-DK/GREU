# Set the country, horizon, solver, and model module groups.
# Keep module load and equation use as separate lists.
module Settings

import SquareModels
import JuMP

const country_code = "DK"

const first_data_year = 2015
const base_year = 2019
const calibration_year = 2019
const terminal_year = 2025

# ============================================================================
# Module groups
# ============================================================================
const macro_accounting_modules = [
  :ModuleTemplate,

  :InputOutput,
  :FixedBasePriceAggregates,

  :SectorAccounts,
]

const macro_core_modules = [
  :ImportSubstitution,

  :FinancialIncome,
  :FinancialRevaluations,

  :Production,
  :Labor,
  :Intermediates,
  :Capital,
  :Taxes,
  :IndustrySectors,

  :Pricing,

  :Households,
  :Government,
  :GovernmentRevenue,
  :GovernmentExpenditure,
  :Corporations,
  :RestOfWorld,

  :ConsumptionSavingsDecision,
  :ConsumptionGroups,

  :Exports,
]

const macro_rigidity_modules = [
  :CapitalAdjustmentCosts,
  :PhillipsCurve,
  :ExportRigidity,
]

# Loaded modules define variables, assign data, and set start values.
const loaded_modules = [
  macro_accounting_modules...,
  macro_core_modules...,
  macro_rigidity_modules...,
]

# Model modules also add equations to the base model and calibration.
# Comment out a group to change the country or user preset.
model_modules::Vector{Symbol} = [
  macro_accounting_modules...,
  macro_core_modules...,
  macro_rigidity_modules...,
]

# JuMP `Model` configured as a square nonlinear system for the selected backend.
# Importing the backend package activates the matching SquareModels extension.
import GAMS
gams_system_dir() = dirname(something(Sys.which("gams"), "C:/GAMS/53/gams.exe"))

function square_model(model=SquareModels.square_model(; gamsdir=gams_system_dir()))
  GAMS.check_system_dir(JuMP.get_optimizer_attribute(model, "sysdir"))
  JuMP.set_optimizer_attribute(model, "workdir", mktempdir())
  JuMP.set_time_limit_sec(model, 5 * 60)
  return model
end
# Alternative backends:
#   import Ipopt;  square_model() = SquareModels.square_model(Ipopt.Optimizer)
#   import CONOPT; square_model() = SquareModels.square_model(CONOPT.Optimizer; lmmxsf=1)

end
