# Group of all variables, identical to all grouup, except containing only elements that exist (not dummied out)
# We use all_variables instead of All for performance reasons, to avoid accessing elements that are dummied out.
# E.g. use $FIX all_variables; instead of $FIX All;
$Group all_variables
  price_variables
  quantity_variables
  value_variables
  other_variables
;

# Group of all elements that are dummied out and should not be accessed
$Group nonexisting
  All, -all_variables
;

# For each variable, set a dummy that is 1 if the variable exists for the combination of set elements
$LOOP all_variables:
  {name}_exists_dummy{sets}$({conditions}) = yes;
$ENDLOOP

# Limit the main model to only include elements that are not dummied out
model main /
  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;
