# ======================================================================================================================
# Growth and Inflation Adjustments for GreenREFORM EU Model
# ======================================================================================================================
# This file handles adjustments for steady-state growth and inflation in the model.
# It provides functions to convert between nominal and real values.

# ----------------------------------------------------------------------------------------------------------------------
# 1. Adjustment Parameters
# ----------------------------------------------------------------------------------------------------------------------
# 1.1 Annual Adjustment Factors
parameters
  fp "1 year adjustment factor for price inflation, =1+gp"
  fq "1 year adjustment factor for growth in quantities, =1+gq"
  fv "1 year composite growth and inflation factor to adjust for growth in nominal values, =(1+gq)(1+gp)"

  fpt[t] "Inflation adjustment factor, =fp^(t-tBase)"
  fqt[t] "Growth adjusment factor, =fq^(t-tBase)"
  fvt[t] "Geometric series for fv, =fv^(t-tBase)"
;

# 1.2 Parameter Initialization
fp = 1 + gp;
fq = 1 + gq;
fv = fp * fq;

# 1.3 Time-Dependent Factors
fpt[t] = fp ** (t.val - tBase.val);
fqt[t] = fq ** (t.val - tBase.val);
fvt[t] = fv ** (t.val - tBase.val);

# 1.4 Adjustment Status
scalar INF_GROWTH_ADJUSTED "Dummy indicating if variables are growth and inflation adjusted";
INF_GROWTH_ADJUSTED = No;

# ----------------------------------------------------------------------------------------------------------------------
# 2. Adjustment Functions
# ----------------------------------------------------------------------------------------------------------------------
# 2.1 Apply Growth and Inflation Adjustments
$FUNCTION inf_growth_adjust():
  # Shift variables to adjust for inflation and growth
  abort$(INF_GROWTH_ADJUSTED) "Trying to adjust for inflation and growth, but model is already adjusted.";
  $offlisting
    # 2.1.1 Price Variable Adjustments
    $LOOP price_variables:
      {name}.l{sets}$({name}.l{sets})= {name}.l{sets} / fpt[t];
      {name}.lo{sets}$({name}.l{sets}) = {name}.lo{sets} / fpt[t];
      {name}.up{sets}$({name}.l{sets}) = {name}.up{sets} / fpt[t];
    $ENDLOOP

    # 2.1.2 Quantity Variable Adjustments
    $LOOP quantity_variables:
      {name}.l{sets}$({name}.l{sets}) = {name}.l{sets} / fqt[t];
      {name}.lo{sets}$({name}.l{sets}) = {name}.lo{sets} / fqt[t];
      {name}.up{sets}$({name}.l{sets}) = {name}.up{sets} / fqt[t];
    $ENDLOOP

    # 2.1.3 Value Variable Adjustments
    $LOOP value_variables:
      {name}.l{sets}$({name}.l{sets}) = {name}.l{sets} / fvt[t];
      {name}.lo{sets}$({name}.l{sets}) = {name}.lo{sets} / fvt[t];
      {name}.up{sets}$({name}.l{sets}) = {name}.up{sets} / fvt[t];
    $ENDLOOP
  $onlisting
  INF_GROWTH_ADJUSTED = Yes;
$ENDFUNCTION

# 2.2 Remove Growth and Inflation Adjustments
$FUNCTION remove_inf_growth_adjustment():
  # Remove inflation and growth adjustment
  abort$(not INF_GROWTH_ADJUSTED) "Trying to remove inflation and growth adjustment, but model is already nominal.";
  $offlisting
    # 2.2.1 Price Variable Restoration
    $LOOP price_variables:
      {name}.l{sets}$({name}.l{sets}) = {name}.l{sets} * fpt[t];
      {name}.lo{sets}$({name}.l{sets}) = {name}.lo{sets} * fpt[t];
      {name}.up{sets}$({name}.l{sets}) = {name}.up{sets} * fpt[t];
    $ENDLOOP

    # 2.2.2 Quantity Variable Restoration
    $LOOP quantity_variables:
      {name}.l{sets}$({name}.l{sets}) = {name}.l{sets} * fqt[t];
      {name}.lo{sets}$({name}.l{sets}) = {name}.lo{sets} * fqt[t];
      {name}.up{sets}$({name}.l{sets}) = {name}.up{sets} * fqt[t];
    $ENDLOOP

    # 2.2.3 Value Variable Restoration
    $LOOP value_variables:
      {name}.l{sets}$({name}.l{sets}) = {name}.l{sets} * fvt[t];
      {name}.lo{sets}$({name}.l{sets}) = {name}.lo{sets} * fvt[t];
      {name}.up{sets}$({name}.l{sets}) = {name}.up{sets} * fvt[t];
    $ENDLOOP
  $onlisting
  INF_GROWTH_ADJUSTED = No;
$ENDFUNCTION
