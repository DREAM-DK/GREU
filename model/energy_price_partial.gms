# ----------------------------------------------------------------------------------------------------------------------
# 1. Update energy dummies and prices
# ----------------------------------------------------------------------------------------------------------------------
# 1.1 Model Definition
model energy_price_partial / 
  energy_demand_prices
  energy_and_emissions_taxes
  /;

# 1.2 Endogenous Variables
$Group energy_price_partial_endogenous
  energy_demand_prices_endogenous
  energy_and_emissions_taxes_endogenous
  ;

# 1.3 Update dummies on energy types
# Set of energy types that are not included in the model
set exclude_energy(e) /
  'Waste'
  'Waste oil'
  'Heat pumps'
  'Wood waste'
  'Straw for energy purposes'
  'Natural gas (Extraction)'
  'Renewable energy'
  'Liquid biofuels'
  /;

# Update dummies
$import Dummies_new_energy_use.gms;

# 1.4 Update exists-dummies in the model
@add_exist_dummies_to_model(energy_price_partial);
