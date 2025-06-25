# ======================================================================================================================
# Functions and macros for the GreenREFORM EU Model
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

# 3.3 Discounting Functions
# A closed form solution for the sum of a finite geometric series
# with an initial term "a", a discount factor "r" and a number of terms "n"
$FUNCTION FiniteGeometricSeries({a}, {r}, {n}):
  ({a} * (1 - (1/(1+{r}))**{n}) / (1 - (1/(1+{r}))))
$ENDFUNCTION

# Present value of a future cash flow
# "x" is the cash flow, "r" is the discount rate, and "p" is the number of years 
# "d" is a dummy determining whether or not the cash flow exists in the given year
$FUNCTION Discount2t({x},{r},{p},{d}):
  sum(tt$(tt.val >= t.val and tt.val <= tend.val and tt.val < t.val+{p} and {d}), 
      {x} / ((1+{r})**(tt.val-t.val)))
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
# $FUNCTION Int_cdfLogNorm({x},{mu},{std}): 
#   errorf((log((({x}/{mu})**2)**0.5) - 0.5*{std}**2)/{std}) 
# $ENDFUNCTION                                                            

# Partial expectation
$FUNCTION PartExpLogNorm({k},{mu},{std}): 
  ({mu} * errorf((log((({k}/{mu})**2)**0.5) - 0.5*{std}**2)/{std})) 
$ENDFUNCTION            

# Conditional expected value (Reference: https://en.wikipedia.org/wiki/Log-normal_distribution)
$FUNCTION CondExpLogNorm({k},{mu},{std}):  
  (@PartExpLogNorm({k},{mu},{std}) / @cdfLogNorm({k},{mu},{std})) 
$ENDFUNCTION 

# ----------------------------------------------------------------------------------------------------------------------
# 5. Functions for previous difference check. When data is completely consistent this would be redundant.
# ----------------------------------------------------------------------------------------------------------------------
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
