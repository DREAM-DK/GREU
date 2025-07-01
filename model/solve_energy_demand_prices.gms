

@add_exist_dummies_to_model(energy_demand_prices);
$FIX all_variables; $UNFIX energy_demand_prices_endogenous;
Solve energy_demand_prices using CNS;