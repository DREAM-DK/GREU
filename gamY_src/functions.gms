# ======================================================================================================================
# Functions and Macros for the GreenREFORM EU Model
# ======================================================================================================================
# This file defines utility functions and macros used throughout the model.
# - Macros are standard GAMS features
# - Functions (using $FUNCTION) are gamY-specific features for user-defined functions
#   that include other gamY commands

# ----------------------------------------------------------------------------------------------------------------------
# 1. State Management Functions
# ----------------------------------------------------------------------------------------------------------------------
# Functions for saving, loading, and comparing model states

# 1.1 Set Variable Values
# Assigns values from one suffix to another for a group of variables
$FUNCTION set({group}, {suffix1}, {suffix2}):
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

# 1.2 Load Data from GDX
# Loads values from a GDX file and assigns them to variables in a group
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

# 1.3 Load Data with Default Level Assignment
$FUNCTION load({group}, {gdx}):
   @load_as({group}, {gdx}, .l)
$ENDFUNCTION

# 1.4 State Comparison
# Aborts if differences between current and saved values exceed threshold
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
# 2. Set Operations
# ----------------------------------------------------------------------------------------------------------------------
# Basic set operations and utilities

# 2.1 Set Position Macros
$macro first(x) ord(x)=1
$macro last(x) ord(x)=card(x)

# 2.2 Set Complement Function
# Defines the complement of a set relative to its parent set
$FUNCTION define_set_complement({name_set_c},{set},{set_c},{isitalist}):   
  set {name_set_c}({set});

  $onMultiR    
    PARAMETER parm_error/0/;
    $onEmbeddedCode Python:
      # Handle list-based set complement
      if {isitalist}=='fromlist':
        import sys 
        if set({set_c}).issubset(set(gams.get("{set}")))==False:
          gams.set("parm_error",[1])
        else:
          gams.set("parm_error",[0])
        gams.set("{name_set_c}", list(set(gams.get("{set}")) - set({set_c})))
      
      # Handle model set complement
      if {isitalist}!='fromlist':
        gams.set("{name_set_c}", list(set(gams.get("{set}")) - set(gams.get("{set_c}"))))
        gams.set("parm_error",[0])

    $offEmbeddedCode {name_set_c} parm_error
  $OffMulti

  ABORT$(parm_error=1) parm_error, "Set-compliment not in set. Make sure that set elements are written as defined with upper/lower-case letters. This error is due to Python case-sensitivity"
$ENDFUNCTION

# ----------------------------------------------------------------------------------------------------------------------
# 3. Mathematical Functions
# ----------------------------------------------------------------------------------------------------------------------
# Utility functions for mathematical operations

# 3.1 Basic Statistics
$FUNCTION mean({dim}, {expression}): sum({dim}, {expression}) / sum({dim}, 1) $ENDFUNCTION

# 3.2 Smooth Approximations
# Parameters for smooth approximations
scalar smooth_abs_delta /0.01/;    # Error parameter for smooth ABS
scalar smooth_max_delta /0.001/;   # Error parameter for smooth MAX
scalar smooth_min_delta /0.001/;   # Error parameter for smooth MIN

# Smooth approximation of absolute value
$FUNCTION abs({x}): (sqrt(sqr({x}) + sqr(smooth_abs_delta)) - smooth_abs_delta)$ENDFUNCTION

# Smooth approximation of maximum
$FUNCTION max({x}, {y}): (({x} + {y} + Sqrt(Sqr({x} - {y}) + Sqr(smooth_max_delta))) / 2)$ENDFUNCTION

# Smooth approximation of minimum
$FUNCTION min({x}, {y}): (({x} + {y} - Sqrt(Sqr({x} - {y}) + Sqr(smooth_min_delta))) / 2)$ENDFUNCTION

# Interval function combining min and max
$FUNCTION InInterval({x},{y},{z}): 
  (({x} + (({z} + {y} - Sqrt(Sqr({z} - {y}) + Sqr(smooth_min_delta))) / 2) + 
    Sqrt(Sqr({x} - (({z} + {y} - Sqrt(Sqr({z} - {y}) + Sqr(smooth_min_delta))) / 2)) + 
    Sqr(smooth_max_delta))) / 2) 
$ENDFUNCTION

# ----------------------------------------------------------------------------------------------------------------------
# 4. Probability Distributions
# ----------------------------------------------------------------------------------------------------------------------
# Functions for working with normal and log-normal distributions

# 4.1 Normal Distribution
$FUNCTION cdfNorm({x},{mu},{std}): 
  errorf(({x}-{mu})/({std})) 
$ENDFUNCTION

# 4.2 Log-normal Distribution
# Cumulative distribution function
$FUNCTION cdfLogNorm({x},{mu},{std}): 
  errorf((log((({x}/{mu})**2)**0.5) + 0.5*{std}**2)/{std}) 
$ENDFUNCTION                                                            

# Integral of cumulative distribution
$FUNCTION Int_cdfLogNorm({x},{mu},{std}): 
  errorf((log((({x}/{mu})**2)**0.5) - 0.5*{std}**2)/{std}) 
$ENDFUNCTION                                                            

# Partial expectation
$FUNCTION PartExpLogNorm({k},{mu},{std}): 
  ({mu} * errorf((log((({k}/{mu})**2)**0.5) - 0.5*{std}**2)/{std})) 
$ENDFUNCTION            

# Conditional expected value
$FUNCTION CondExpLogNorm({k},{mu},{std}):  
  (@PartExpLogNorm({k},{mu},{std}) / @cdfLogNorm({k},{mu},{std})) 
$ENDFUNCTION 

# Reference: https://en.wikipedia.org/wiki/Log-normal_distribution
