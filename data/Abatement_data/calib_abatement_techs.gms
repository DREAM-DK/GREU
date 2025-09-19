$IMPORT ..\model\functions.gms;

## ----------------------------------------------------------------------------------------
## Creating abatement technologies to match data
## ----------------------------------------------------------------------------------------

set l_input "Technology name for calibrated abatement data";
set l "Technology name." / t1*t1000 /;

$gdxIn Abatement_data/calibrate_abatement_data_python.gdx
$load l_input
$gdxIn

alias(l,ll);

parameter 
  sqTPotential_input[l_input,es,d,t] "Technology potential for calibrated abatement data"
  uTE_input[l_input,es,e,d,t] "Technology energy input for calibrated abatement data"
  counter[es,d] "Counter for technology potential"
  pEpj_marg[es,e,d,t]

  sqTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  vTI[l,es,d,t]
  vTC[l,es,d,t]
  qES[es,d,t]
  LifeSpan[l,es,d,t]
  pTK[d,t]
  DiscountRate[l,es,d]

  uTKexp[l,es,d,t]
  ;

counter[es,d] = 0;

execute_load "Abatement_data/calibrate_abatement_data_python.gdx" sqTPotential_input=sqTPotential_input.l;
execute_load "Abatement_data/calibrate_abatement_data_python.gdx" uTE_input=uTE_input.l;
execute_load "Abatement_data/calibrate_abatement_data_python.gdx" qES=qES.l;
execute_load "Abatement_data/pEpj_marg.gdx" pEpj_marg=pEpj_marg.l;

loop(l_input$(sum((es,i,t), sqTPotential_input[l_input,es,i,t])),
    counter[es,i]$(sum(t, sqTPotential_input[l_input,es,i,t])) = counter[es,i]+1;
    sqTPotential[l,es,i,t]$(ord(l)=counter[es,i] and sqTPotential_input[l_input,es,i,t]) = sqTPotential_input[l_input,es,i,t];
    uTE[l,es,e,i,t]$(ord(l)=counter[es,i] and sqTPotential_input[l_input,es,i,t]) = uTE_input[l_input,es,e,i,t];
);

LifeSpan[l,es,i,t]$(sqTPotential[l,es,i,t]) = 5;
DiscountRate[l,es,d]$(sum(t, sqTPotential[l,es,d,t])) = 0.05;
pTK[d,t]$(sum((l,es), sqTPotential[l,es,d,t])) = 1;

# ----------------------------------------------------------------------------------------
# Split large technologies into smaller technologies
# ----------------------------------------------------------------------------------------

parameter
  sqTPotential_large[l,es,d,t] "Technology potential"
  sqTPotential_large_sumL[es,d,t] "Technology potential"
  last_tech[l,es,d,t] "Last technology"
  ;

sqTPotential_large[l,es,d,t]$(sqTPotential[l,es,d,t] > 0.5) = sqTPotential[l,es,d,t];

sqTPotential_large_sumL[es,d,t] = sum(l,sqTPotential_large[l,es,d,t]);

# Identify the last technology
last_tech[l,es,d,t]$(sqTPotential[l,es,d,t] and not sqTPotential[l+1,es,d,t]) = yes;

# The original potential is divided by 4 
sqTPotential[l,es,d,t]$(sqTPotential_large[l,es,d,t]) = sqTPotential_large[l,es,d,t]/4;

# The remaining potential from the large technologies is divided onto three other technologies
sqTPotential[l+1,es,d,t]$(sum(ll, sqTPotential_large[ll,es,d,t]) and last_tech[l,es,d,t]) = sum(ll, sqTPotential_large[ll,es,d,t])/4;
sqTPotential[l+2,es,d,t]$(sum(ll, sqTPotential_large[ll,es,d,t]) and last_tech[l,es,d,t]) = sum(ll, sqTPotential_large[ll,es,d,t])/4;
sqTPotential[l+3,es,d,t]$(sum(ll, sqTPotential_large[ll,es,d,t]) and last_tech[l,es,d,t]) = sum(ll, sqTPotential_large[ll,es,d,t])/4;


LifeSpan[l,es,i,t]$(sqTPotential[l,es,i,t]) = 5;
DiscountRate[l,es,d]$(sum(t, sqTPotential[l,es,d,t])) = 0.05;
pTK[d,t]$(sum((l,es), sqTPotential[l,es,d,t])) = 1;

## Assign uTE to the large technologies (Works only if there is only one large technology in each indutry/energy service)
uTE[l+1,es,e,d,t]$(sum(ll, sqTPotential_large[ll,es,d,t]) and last_tech[l,es,d,t]) = sum(ll$(sqTPotential_large[ll,es,d,t]), uTE[ll,es,e,d,t]);
uTE[l+2,es,e,d,t]$(sum(ll, sqTPotential_large[ll,es,d,t]) and last_tech[l,es,d,t]) = sum(ll$(sqTPotential_large[ll,es,d,t]), uTE[ll,es,e,d,t]);
uTE[l+3,es,e,d,t]$(sum(ll, sqTPotential_large[ll,es,d,t]) and last_tech[l,es,d,t]) = sum(ll$(sqTPotential_large[ll,es,d,t]), uTE[ll,es,e,d,t]);

# ----------------------------------------------------------------------------------------
# Defining capital costs for each technology
# ----------------------------------------------------------------------------------------
parameter
  pTPotential[l,es,d,t] "Technology price"
  ;

set exceptions(es,d) /
  'process_special'.'35002'
  'process_normal'.'off'
  'process_special'.'10120'
  'transport'.'35011'
/;

pTPotential['t1',es,i,t]$(sqTPotential['t1',es,i,t] and not exceptions[es,i]) = 0.5;
pTPotential['t1',es,i,t]$(sqTPotential['t1',es,i,t] and exceptions[es,i]) = 3;

loop(l$(sum((es,i,t), sqTPotential[l,es,i,t]) and not sameas(l, 't1')),
  pTPotential[l,es,i,t]$(sqTPotential[l,es,i,t]) = pTPotential[l-1,es,i,t]+0.02;
);

uTKexp[l,es,i,t]$(sqTPotential[l,es,i,t])
 = ((pTPotential[l,es,i,t]) 
   - sum(e, uTE[l,es,e,i,t]*pEpj_marg[es,e,i,t]))
 / pTK[i,t];

vTI[l,es,i,t]$(sqTPotential[l,es,i,t]) 
  = uTKexp[l,es,i,t]*@FiniteGeometricSeries({1}, {DiscountRate[l,es,i]}, {LifeSpan[l,es,i,t]})
  / (1+0.1*@FiniteGeometricSeries({1}, {DiscountRate[l,es,i]}, {LifeSpan[l,es,i,t]}));

vTC[l,es,i,t] = vTI[l,es,i,t]/10;


## ----------------------------------------------------------------------------------------
## Creating electricity technologies
## ----------------------------------------------------------------------------------------

## First step: Electricity prices where they don't exist
parameter 
  d1pEpj_abatement[es,e,i,t] "Electricity prices for abatement technologies"
  ;

d1pEpj_abatement[es,'Electricity',i,t]$(sum((l,e), uTE[l,es,e,i,t]) and not pEpj_marg[es,'Electricity',i,t]) = yes;

pEpj_marg[es,e,i,t]$(d1pEpj_abatement[es,e,i,t]) = 0.157988;

## Second step: Technology prices
parameter
  pTPotential_max[es,d,t] "Maximum technology price for each energy service"
  cost_factor[l] "Factor determining how much more expensive electrification technologies are compared to baseline technologies"
  vTI_max[es,d,t] "Maximum investment costs for each energy service"
  ;

set electrification_techs[l] /
  't26'
  # 't27'
  # 't28'
  # 't29'
  /;

cost_factor['t26'] = 1.02;
# cost_factor['t27'] = 1.1;
# cost_factor['t28'] = 1.2;
# cost_factor['t29'] = 1.3;

# Determining the most expensive technology (used in determining the range for the supply curve)
pTPotential_max[es,d,t] = smax(l, sum(e, uTE[l,es,e,d,t]*pEpj_marg[es,e,d,t]) 
                                + uTKexp[l,es,d,t]*pTK[d,t]);

sqTPotential[l,es,i,t]$(sum(ll, sqTPotential[ll,es,i,t]) and electrification_techs[l]) = 0.2;
uTE[l,es,'Electricity',i,t]$(sqTPotential[l,es,i,t] and electrification_techs[l]) = 1;

# Set LifeSpan, DiscountRate and pTK
LifeSpan[l,es,i,t]$(sqTPotential[l,es,i,t]) = 5;
DiscountRate[l,es,d]$(sum(t, sqTPotential[l,es,d,t])) = 0.05;
pTK[d,t]$(sum((l,es), sqTPotential[l,es,d,t])) = 1;

# Calculate uTKexp, vTI and vTC for the electrification technologies
uTKexp[l,es,i,t]$(sqTPotential[l,es,i,t] and electrification_techs[l])
 = ((pTPotential_max[es,i,t]*cost_factor[l]) 
   - sum(e, uTE[l,es,e,i,t]*pEpj_marg[es,e,i,t]))
 / pTK[i,t];

vTI[l,es,i,t]$(sqTPotential[l,es,i,t] and electrification_techs[l]) 
  = uTKexp[l,es,i,t]*@FiniteGeometricSeries({1}, {DiscountRate[l,es,i]}, {LifeSpan[l,es,i,t]})
  / (1+0.1*@FiniteGeometricSeries({1}, {DiscountRate[l,es,i]}, {LifeSpan[l,es,i,t]}));

vTC[l,es,i,t] = vTI[l,es,i,t]/10;


## ----------------------------------------------------------------------------------------
## Updating dummies
## ----------------------------------------------------------------------------------------

set these_i_es(d,es) /
  '01011'.'heating'
  '01011'.'transport'
  '01031'.'heating'
  '01051'.'process_normal'
  '01051'.'heating'
  '01080'.'heating'
  '10120'.'process_normal'
  '13150'.'transport'
  '23001'.'process_special'
  '25000'.'transport'
  '25000'.'process_normal'
  '35011'.'process_special'
  '41430'.'transport'
  '41430'.'process_normal'
  '45000'.'transport'
  '46000'.'transport'
  '47000'.'transport'
  '49011'.'process_normal'
  '49024'.'transport'
  '49031'.'transport'
  '52000'.'transport'
  '53000'.'transport'
  '55560'.'transport'
  '55560'.'heating'
  '71000'.'transport'
  '71000'.'heating'
  'off'.'transport'
  'off'.'heating'
  /;

# Delete technologies that are not in the list
sqTPotential[l,es,d,t]$(not these_i_es(d,es)) = 0;
uTE[l,es,e,d,t]$(not these_i_es(d,es)) = 0;
vTI[l,es,d,t]$(not these_i_es(d,es)) = 0;
vTC[l,es,d,t]$(not these_i_es(d,es)) = 0;
LifeSpan[l,es,d,t]$(not these_i_es(d,es)) = 0;
pTK[d,t]$(not sum(es, these_i_es(d,es))) = 0;
qES[es,d,t]$(not these_i_es(d,es)) = 0;
