$IMPORT functions.gms;
$IMPORT settings.gms

$IMPORT sets/time.sets.gms
$IMPORT sets/input_output.sets.gms
$IMPORT sets/output.sets.gms

set_time_periods(%first_data_year%, %terminal_year%);

# ------------------------------------------------------------------------------
# Initialize models and groups used accross modules
# ------------------------------------------------------------------------------
$onMulti
model main;
model calibration;

$GROUP price_variables ; # Variables that are adjusted for steady state inflation
$GROUP quantity_variables ; # Variables that are adjusted for steady state productivity growth
$GROUP value_variables ; # Variables that are adjusted for both steady state inflation and productivity growth
$GROUP other_variables ; # Variables that are not adjusted for steady state inflation or productivity growth

$GROUP data_covered_variables ; # Variables that are covered by data

$GROUP main_endogenous ;
$GROUP calibration_endogenous ;

$IMPORT growth_adjustments.gms

# ------------------------------------------------------------------------------
# Import modules
# ------------------------------------------------------------------------------
# $IMPORT test_module.gms
#  $IMPORT labor_market.gms
$IMPORT energy_markets.gms
# $IMPORT input_output.gms
# $IMPORT aggregates.gms
# $IMPORT imports.gms
# $IMPORT households.gms

# ------------------------------------------------------------------------------
@inf_growth_adjust()

$IMPORT exist_dummies.gms

$IMPORT calibration.gms

