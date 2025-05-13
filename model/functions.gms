# ======================================================================================================================
# Functions and macros
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


$FUNCTION create_difference_parameters({group},{suffix}):
  $offlisting
    $LOOP {group}:
      parameter {name}{suffix}{sets};
    $ENDLOOP 
  $onlisting
$ENDFUNCTION

$FUNCTION set_difference_parameters({group}, {suffix}):
  $offlisting
  $LOOP {group}:
    {name}{suffix}{sets}${conditions} = {name}.l{sets} - {name}_data{sets};
  $ENDLOOP 
  $onlisting
$ENDFUNCTION

$FUNCTION unload_previous_difference({group}, {suffix}):
  $offlisting
  @create_difference_parameters({group}, {suffix})
  @set_difference_parameters({group}, {suffix})

  execute_unload  "..\data\previous_difference.gdx" $LOOP {group}: {name}{suffix} $ENDLOOP;
  $onlisting
$ENDFUNCTION

$FUNCTION load_previous_difference({group}, {suffix}):
  $offlisting
  @create_difference_parameters({group}, _previous{suffix})

  execute_load "..\data\previous_difference.gdx" $LOOP {group}: {name}_previous{suffix} = {name}{suffix} $ENDLOOP;
  $onlisting
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

# ----------------------------------------------------------------------------------------------------------------------
# Set operations
# ----------------------------------------------------------------------------------------------------------------------
$macro first(x) ord(x)=1
$macro last(x) ord(x)=card(x)

$FUNCTION define_set_complement({name_set_c},{set},{set_c},{isitalist}):   
  #Set compliment is defined on mother-set
  set {name_set_c}({set});

   $onMultiR    
      PARAMETER parm_error/0/;
      $onEmbeddedCode Python:

      #If set {set_c} is just a list of set-elements then we define the set-compliment with this code
      if {isitalist}=='fromlist':
        #Python is case-sensitive and this can cause problems. For this reason a check is run to make sure that {set_c} is contained in {set}
        import sys 
        if set({set_c}).issubset(set(gams.get("{set}")))==False:
          gams.set("parm_error",[1])
        else:
          gams.set("parm_error",[0])

        gams.set("{name_set_c}", list(set(gams.get("{set}")) - set({set_c})))
      
      #If set {set_c} is already a model set we use this to extract the compliment
      if {isitalist}!='fromlist':
        gams.set("{name_set_c}", list(set(gams.get("{set}")) - set(gams.get("{set_c}"))))
        gams.set("parm_error",[0]) #Set to indicicate no error       

      $offEmbeddedCode {name_set_c} parm_error
    $OffMulti

    #Hvis fejl
    ABORT$(parm_error=1) parm_error, "Set-compliment not in set. Make sure that set elements are written as defined with upper/lower-case letters. This error is due to Python case-sensitivity"
$ENDFUNCTION
