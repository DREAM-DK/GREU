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

# ----------------------------------------------------------------------------------------------------------------------
# Mean value and continous approximation of max and min functions
# ----------------------------------------------------------------------------------------------------------------------

$FUNCTION mean({dim}, {expression}): sum({dim}, {expression}) / sum({dim}, 1) $ENDFUNCTION

# Smooth approximation of ABS function. The error is zero when {x} is zero and goes to -smooth_abs_delta as abs({x}) increases.
scalar smooth_abs_delta /0.01/;
$FUNCTION abs({x}): (sqrt(sqr({x}) + sqr(smooth_abs_delta)) - smooth_abs_delta)$ENDFUNCTION

# Smooth approximation of MAX function. The error is smooth_max_delta/2 when {x}=={y} and goes to zero as {x} and {y} diverge.
scalar smooth_max_delta /0.001/;
$FUNCTION max({x}, {y}): (({x} + {y} + Sqrt(Sqr({x} - {y}) + Sqr(smooth_max_delta))) / 2)$ENDFUNCTION

# Smooth approximation of MIN function. The error is -smooth_min_delta/2 when {x}=={y} and goes to zero as {x} and {y} diverge.
scalar smooth_min_delta /0.001/;
$FUNCTION min({x}, {y}): (({x} + {y} - Sqrt(Sqr({x} - {y}) + Sqr(smooth_min_delta))) / 2)$ENDFUNCTION

$FUNCTION InInterval({x},{y},{z}): (({x} + (({z} + {y} - Sqrt(Sqr({z} - {y}) + Sqr(smooth_min_delta))) / 2) + Sqrt(Sqr({x} - (({z} + {y} - Sqrt(Sqr({z} - {y}) + Sqr(smooth_min_delta))) / 2)) + Sqr(smooth_max_delta))) / 2) $ENDFUNCTION

# ----------------------------------------------------------------------------------------------------------------------
# Probalitily distributions
# ----------------------------------------------------------------------------------------------------------------------

# #Cumulative distribution of a normal distribution
$FUNCTION cdfNorm({x},{mu},{std}): errorf(({x}-{mu})/({std})) $ENDFUNCTION

# #Cumulative distribution of a log-normal distribution with expected value mu and standard deviation std 
$FUNCTION cdfLogNorm({x},{mu},{std}): errorf((log( ( ({x}/{mu})**2 )**0.5) + 0.5*{std}**2 )/{std}) $ENDFUNCTION                                                            

#Integral of cumulative distribution of a log-normal distribution with expected value mu and standard deviation std 
$FUNCTION Int_cdfLogNorm({x},{mu},{std}): errorf((log( ( ({x}/{mu})**2 )**0.5) - 0.5*{std}**2 )/{std}) $ENDFUNCTION                                                            

#Partial expectation of a log normal distributed random variable X with mean value mu, standard deviaton std and a threshold X<k
$FUNCTION PartExpLogNorm({k},{mu},{std}): ({mu} * errorf((log( ( ({k}/{mu})**2 )**0.5) - 0.5*{std}**2 )/{std})) $ENDFUNCTION            

#Conditional expected value of a log normal distributed random variable X with mean value mu, standard deviaton std and conditional on x<k
$FUNCTION CondExpLogNorm({k},{mu},{std}):  (@PartExpLogNorm({k},{mu},{std}) / @cdfLogNorm({k},{mu},{std})) $ENDFUNCTION 

# Reference: https://en.wikipedia.org/wiki/Log-normal_distribution
