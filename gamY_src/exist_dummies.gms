# Group of all elements that are dummied out and should not be accessed
$Group nonexisting All, -all_variables;

# For each variable, set a dummy that is 1 if the variable exists for the combination of set elements
$FUNCTION update_exist_dummies():
  $LOOP all_variables:
    {name}_exists_dummy{sets}$({conditions}) = yes;
  $ENDLOOP
$ENDFUNCTION

# Limit the main model to only include elements that are not dummied out
model main /
  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;
