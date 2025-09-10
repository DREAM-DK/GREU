# ----------------------------------------------------------------------------------------------------------------------
# Grouping variables by name
# ----------------------------------------------------------------------------------------------------------------------
$Group nonexisting All, -all_variables; # Group of all elements that are dummied out and should not be accessed
$Group constant_variables ; # Variables without a time index
$Group scalar_variables ; # Variables without a time index

$Group+ constant_variables
  $EvalPython
    ",".join(
      name
      for name, var in self.groups["all"].items()
      if not (var.sets == "[t]" or var.sets.endswith(",t]"))
    )
  $EndEvalPython
;

$Group+ scalar_variables
  $EvalPython
    ",".join(
      name
      for name, var in self.groups["all"].items()
      if not var.sets
    )
  $EndEvalPython
;

$Group all_variables_except_scalars all_variables, -scalar_variables;
$Group all_variables_except_constants all_variables, -constant_variables;

# Exceptions to to the naming scheme can be added directly to the groups below
$Group price_variables ; # Variables that are adjusted for steady state inflation
$Group quantity_variables ; # Variables that are adjusted for steady state productivity growth
$Group value_variables ; # Variables that are adjusted for both steady state inflation and productivity growth

$GROUP variables_to_be_assigned_by_prefix
  all_variables
  - price_variables
  - quantity_variables
  - value_variables
  - constant_variables
;

$GROUP+ price_variables
  $EvalPython
    ",".join(
      name
      for name in self.groups["variables_to_be_assigned_by_prefix"]
      if (
        any(name.startswith(prefix) for prefix in ["p", "jp", "sp", "Ep", "mp"]) and "2p" not in name
      ) or (
        any(name.startswith(prefix) for prefix in ["dp", "sdp"]) and "2" in name and not any(x in name for x in ["2dp", "2dq", "2dv"])
      )
    )
  $EndEvalPython
;

$GROUP+ quantity_variables
  $EvalPython
    ",".join(
      name
      for name in self.groups["variables_to_be_assigned_by_prefix"]
      if (
        any(name.startswith(prefix) for prefix in ["q", "jq", "sq", "Eq", "mq"]) and "2q" not in name
      ) or (
        any(name.startswith(prefix) for prefix in ["dq", "sdq"]) and "2" in name and not any(x in name for x in ["2dp", "2dq", "2dv"])
      )
    )
  $EndEvalPython
;

$GROUP+ value_variables
  $EvalPython
    ",".join(
      name
      for name in self.groups["variables_to_be_assigned_by_prefix"]
      if (
        any(name.startswith(prefix) for prefix in ["v", "jv", "sv", "Ev", "mv", "nv"]) and "2v" not in name
      ) or (
        any(name.startswith(prefix) for prefix in ["dv", "sdv"]) and "2" in name and not any(x in name for x in ["2dp", "2dq", "2dv"])
      )
    )
  $EndEvalPython
;

# For each variable, set a dummy that is 1 if the variable exists for the combination of set elements
$FUNCTION update_exist_dummies():
  $Group all_variables_except_scalars all_variables, -scalar_variables;
  $LOOP all_variables_except_scalars:
    {name}_exists_dummy{sets} = {conditions};
  $ENDLOOP
$ENDFUNCTION

# Limit a model to only include elements that are not dummied out
$FUNCTION add_exist_dummies_to_model({model}):
  $Group all_variables_except_scalars all_variables, -scalar_variables;
  model {model} /
    $LOOP all_variables_except_scalars:
      {name}({name}_exists_dummy)
    $ENDLOOP
  /;
$ENDFUNCTION

