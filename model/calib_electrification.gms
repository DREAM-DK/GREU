# ------------------------------------------------------------------------------
# Calibrate decreasing capital costs for electrification technologies
# ------------------------------------------------------------------------------

# Define the electrification technologies
set electrification_techs[l] /
  't26'
  't27'
  't28'
  't29'
  /;

# Investment costs decrease by 1 pct. per year



# Operating costs decrease by 1 pct. per year



# Supply Curve Visualization
$import Supply_curves_abatement.gms;

# # Solve partial abatement model
# $FIX all_variables;
# $UNFIX abatement_partial_endogenous;
# Solve abatement_partial_equations using CNS;
# execute_unload 'Output\calibration_electrification_abatement_partial.gdx';

# Solve model
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
@import_from_modules("report_baseline") # We recalculate baseline values with the new technologies
@import_from_modules("report")
execute_unload 'Output\calibration_electrification.gdx';