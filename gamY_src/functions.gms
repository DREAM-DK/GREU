# ======================================================================================================================
# Functions
# ======================================================================================================================
# In this file we define functions and macros to be used elsewhere in the model
# Macros are a vanilla GAMS feature
# The FUNCTION command is is a gamY feature. It should be used when the user defined function includes other gamY commands.

# ----------------------------------------------------------------------------------------------------------------------
# Save, load, and compare states
# ----------------------------------------------------------------------------------------------------------------------
# For each variable in a {group}, assign level from {suffix2} to {suffix1}. I.e. {name}{suffix1}{sets}${conditions} = {name}{suffix2}{sets}
$FUNCTION set({group}, {suffix1},  {suffix2}):
  $offlisting
  $IF "{suffix1}" not in [".l", "", ".fx", ".up", ".lo"]:
    parameters
      $LOOP {group}:
        {name}{suffix1}{sets}$ENDLOOP
    ;
  $ENDIF
    $LOOP {group}:
      {name}{suffix1}{sets}${conditions} = {name}{suffix2}{sets};$ENDLOOP
  $onlisting
$ENDFUNCTION

# Load values from a GDX file and assign them to the {suffix} of the variables in a {group}
$FUNCTION load_as({group}, {gdx}, {suffix}):
  $offlisting
  parameters
    $LOOP {group}:
      {name}__load__{sets}$ENDLOOP
  ;
  $onDotL
  execute_load {gdx} $LOOP {group}: {name}__load__={name} $ENDLOOP;
  $offDotL
  @set({group}, {suffix}, __load__);
  $onlisting
$ENDFUNCTION

$FUNCTION load({group}, {gdx}):
   @load_as({group}, {gdx}, .l)
$ENDFUNCTION

# Abort if differences exceed the threshold. Differences are between the current values of a group of variables and the previously saved values.
$FUNCTION assert_no_difference({group}, {threshold}, {suffix1}, {suffix2}, {msg}):
  $offlisting
    $LOOP {group}:
      parameter {name}_difference{sets};
      {name}_difference{sets}${conditions} = {name}{suffix1}{sets} - {name}{suffix2}{sets};
      {name}_difference{sets}$(abs({name}_difference{sets}) < {threshold}) = 0;
      if (sum({sets}{$}[+t]${conditions}, abs({name}_difference{sets})),
        display {name}_difference;
      );
    $ENDLOOP
    $LOOP {group}:
      loop({sets}{$}[+t]${conditions},
        abort$({name}_difference{sets} <> 0) '{name}_difference exceeds allowed threshold! {msg}';
      )
    $ENDLOOP
  $onlisting
$ENDFUNCTION

