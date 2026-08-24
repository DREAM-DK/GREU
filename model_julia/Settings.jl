module Settings

import SquareModels

const country_code = "DK"

const first_data_year = 2015
const base_year = 2019
const calibration_year = 2019
const terminal_year = 2025

# File names to include. Model.jl loads these as model_modules.
const module_names = [
  :ModuleTemplate,

  :InputOutput,

  :Production,
  :Labor,
  :Intermediates,
  :Capital,

  :Pricing,

  :CapitalAdjustmentCosts,

  :SectorAccounts,
  :Households,
  :ConsumptionSavingsDecision,
  :ConsumptionGroups,
  :Government,
  :Corporations,
  :RestOfWorld,

  :Exports,
  :ImportSubstitution,

  :FixedBasePriceAggregates,
  ]

# JuMP `Model` configured as a square nonlinear system for the selected backend.
# Importing the backend package activates the matching SquareModels extension.
import GAMS
square_model() = SquareModels.square_model(; gamsdir="C:/GAMS/53")
# Alternative backends:
#   import Ipopt;  square_model() = SquareModels.square_model(Ipopt.Optimizer)
#   import CONOPT; square_model() = SquareModels.square_model(CONOPT.Optimizer; lmmxsf=1)

end
