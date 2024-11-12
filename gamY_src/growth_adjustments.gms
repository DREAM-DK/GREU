# ----------------------------------------------------------------------------------------------------------------------
# Adjusting for growth and inflation
# ----------------------------------------------------------------------------------------------------------------------
parameters
  fp "1+gp"
  fq "1+gq"
  fv "fp * fq"

  fpt[t] "fp^(t-tBase)"
  fqt[t] "fq^(t-tBase)"
  fvt[t] "fv^(t-tBase)"
;

fp = 1 + gp;
fq = 1 + gq;
fv = fp * fq;

fpt[t] = fp ** (t.val - tBase.val);
fqt[t] = fq ** (t.val - tBase.val);
fvt[t] = fv ** (t.val - tBase.val);


scalar INF_GROWTH_ADJUSTED "Dummy indicating if variables are growth and inflation adjusted";
INF_GROWTH_ADJUSTED = No;

$FUNCTION inf_growth_adjust():
  # Shift variables to adjust for inflation and growth
  abort$(INF_GROWTH_ADJUSTED) "Trying to adjust for inflation and growth, but model is already adjusted.";
  $offlisting
    $LOOP price_variables:
      {name}.l{sets}= {name}.l{sets} / fpt[t];
      {name}.lo{sets} = {name}.lo{sets} / fpt[t];
      {name}.up{sets} = {name}.up{sets} / fpt[t];
    $ENDLOOP
    $LOOP quantity_variables:
      {name}.l{sets} = {name}.l{sets} / fqt[t];
      {name}.lo{sets} = {name}.lo{sets} / fqt[t];
      {name}.up{sets} = {name}.up{sets} / fqt[t];
    $ENDLOOP
    $LOOP value_variables:
      {name}.l{sets} = {name}.l{sets} / fvt[t];
      {name}.lo{sets} = {name}.lo{sets} / fvt[t];
      {name}.up{sets} = {name}.up{sets} / fvt[t];
    $ENDLOOP
  $onlisting
  INF_GROWTH_ADJUSTED = Yes;
$ENDFUNCTION

$FUNCTION remove_inf_growth_adjustment():
  # Remove inflation and growth adjustment
  abort$(not INF_GROWTH_ADJUSTED) "Trying to remove inflation and growth adjustment, but model is already nominal.";
  $offlisting
    $LOOP price_variables:
      {name}.l{sets} = {name}.l{sets} * fpt[t];
      {name}.lo{sets} = {name}.lo{sets} * fpt[t];
      {name}.up{sets} = {name}.up{sets} * fpt[t];
    $ENDLOOP
    $LOOP quantity_variables:
      {name}.l{sets} = {name}.l{sets} * fqt[t];
      {name}.lo{sets} = {name}.lo{sets} * fqt[t];
      {name}.up{sets} = {name}.up{sets} * fqt[t];
    $ENDLOOP
    $LOOP value_variables:
      {name}.l{sets} = {name}.l{sets} * fvt[t];
      {name}.lo{sets} = {name}.lo{sets} * fvt[t];
      {name}.up{sets} = {name}.up{sets} * fvt[t];
    $ENDLOOP
  $onlisting
  INF_GROWTH_ADJUSTED = No;
$ENDFUNCTION
