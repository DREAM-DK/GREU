# ------------------------------------------------------------------------------
# Initialize groups used accross modules
# ------------------------------------------------------------------------------
$GROUP price_variables ; # Variables that are adjusted for steady state inflation
$GROUP quantity_variables ; # Variables that are adjusted for steady state productivity growth
$GROUP value_variables ; # Variables that are adjusted for both steady state inflation and productivity growth
$GROUP other_variables ; # Variables that are not adjusted for steady state inflation or productivity growth

$GROUP data_covered_variables ; # Variables that are covered by data

$IMPORT growth_adjustments.gms

# ------------------------------------------------------------------------------
# Import modules
# ------------------------------------------------------------------------------
$IMPORT input_output.gms
$IMPORT aggregates.gms
# $IMPORT households.gms

# ------------------------------------------------------------------------------
# Existance dummies
# ------------------------------------------------------------------------------
# Group of all variables, identical to all grouup, except containing only elements that exist (not dummied out)
# We use all_variables instead of All for performance reasons, to avoid accessing elements that are dummied out.
# E.g. use $FIX all_variables; instead of $FIX All;
$GROUP all_variables
  price_variables
  quantity_variables
  value_variables
  other_variables
;

# Group of all elements that are dummied out and should not be accessed
$GROUP nonexisting
  All, -all_variables
;

# For each variable, create a dummy that is 1 if the variable exists for the combination of set elements
$LOOP all_variables:
  set {name}_exists_dummy{sets};
  {name}_exists_dummy{sets}$({conditions}) = yes;
$ENDLOOP

# ------------------------------------------------------------------------------
# Putting it all together
# ------------------------------------------------------------------------------
@inf_growth_adjust()

model base_model /
  input_output_equations
  aggregates_equations
  # households_equations

  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;

$GROUP endogenous
  input_output_endogenous
  aggregates_endogenous
  # households_endogenous
;
