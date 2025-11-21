# ======================================================================================================================
# Base Model for GreenREFORM EU
# ======================================================================================================================
# This file sets up the base model structure and runs the main simulations

$onMulti # Allows adding to an already defined set or model with multiple "model" or "set" statements

# ----------------------------------------------------------------------------------------------------------------------
# 1. Import Dependencies
# ----------------------------------------------------------------------------------------------------------------------
# 1.1 Core Functions and Settings
$IMPORT functions.gms;
$IMPORT settings.gms

# 1.2 Set Definitions
$IMPORT sets/time.sets.gms
$IMPORT sets/abatement.sets.gms
set_time_periods(%first_data_year%, %terminal_year%);

# ----------------------------------------------------------------------------------------------------------------------
# 2. Module Management
# ----------------------------------------------------------------------------------------------------------------------
# Function to import modules based on stage
$FUNCTION import_from_modules(stage_key):
  $SETGLOBAL stage stage_key;
  $IMPORT abatement.gms
$ENDFUNCTION

# ----------------------------------------------------------------------------------------------------------------------
# 3. Model Structure
# ----------------------------------------------------------------------------------------------------------------------
# 3.1 Variable Groups
$Group all_variables ; # All variables in the model
$Group main_endogenous ;
$Group data_covered_variables ; # Variables that are covered by data
$Group G_flat_after_last_data_year ; # Variables that are extended with "flat forecast" after last data year
$SetGroup SG_flat_after_last_data_year ; # Dummies that are extended with "flat forecast" after last data year

# 3.2 Import Module Variables
@import_from_modules("variables")
$IMPORT variable_groups.gms
$IMPORT growth_adjustments.gms

# 3.3 Model Definition
model main;
model calibration;
@import_from_modules("equations")
@add_exist_dummies_to_model(main) # Limit the main model to only include elements that are not dummied out
main.optfile=1;

# ----------------------------------------------------------------------------------------------------------------------
# 4. Data and Parameters
# ----------------------------------------------------------------------------------------------------------------------
# 4.1 Import Data
@import_from_modules("exogenous_values")
# @inf_growth_adjust()
@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration
@update_exist_dummies()

# 4.2 Supply Curve Visualization
* $import premodel_abatement.gms
* $import Supply_curves_abatement.gms

# ----------------------------------------------------------------------------------------------------------------------
# 5. Model Calibration
# ----------------------------------------------------------------------------------------------------------------------
# 5.1 Setup Calibration
$Group calibration_endogenous ;
@import_from_modules("calibration")
calibration.optfile=1;
$IMPORT calibration.gms
$IMPORT report_abatement.gms
execute_unloaddi "calibration.gdx";