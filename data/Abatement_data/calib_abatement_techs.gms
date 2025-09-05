## ----------------------------------------------------------------------------------------
## Creating abatement technologies to match data
## ----------------------------------------------------------------------------------------

set l_input "Technology name for calibrated abatement data";
set l "Technology name.";

$gdxIn Abatement_data/calibrate_abatement_data_python.gdx
$load l_input
$gdxIn

$gdxIn ../data/Abatement_data/Abatement_dummy_data.gdx
$load l
$gdxIn

alias(l,ll);

parameter 
  sqTPotential_input[l_input,es,d,t] "Technology potential for calibrated abatement data"
  uTE_input[l_input,es,e,d,t] "Technology energy input for calibrated abatement data"
  counter "Counter for technology potential"

  sqTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  vTI[l,es,d,t]
  vTC[l,es,d,t]
  qES[es,d,t]
  LifeSpan[l,es,d,t]
  pTK[d,t]
  ;

counter = 0;

execute_load "Abatement_data/calibrate_abatement_data_python.gdx" sqTPotential_input=sqTPotential_input.l;
execute_load "Abatement_data/calibrate_abatement_data_python.gdx" uTE_input=uTE_input.l;
execute_load "Abatement_data/calibrate_abatement_data_python.gdx" qES=qES.l;

# sqTPotential.l[l,es,i,t] = no;
# uTE.l[l,es,e,i,t] = no;
# vTI.l[l,es,i,t] = no;
# vTC.l[l,es,i,t] = no;

loop(l_input$(sum((es,d,t), sqTPotential_input[l_input,es,d,t])),
    counter = counter+1;
    sqTPotential[l,es,i,t]$(ord(l)=counter) = sqTPotential_input[l_input,es,i,t];
    uTE[l,es,e,i,t]$(ord(l)=counter) = uTE_input[l_input,es,e,i,t];
    vTI[l,es,i,t]$(ord(l)=counter and sqTPotential[l,es,i,t]) = counter/5;
    vTC[l,es,i,t]$(ord(l)=counter and sqTPotential[l,es,i,t]) = counter/50;
);

LifeSpan[l,es,i,t]$(sqTPotential[l,es,i,t]) = 5;

## ----------------------------------------------------------------------------------------
## Calculating technology costs
## ----------------------------------------------------------------------------------------

# # 1.2 Starting values for Levelized Cost of Energy (LCOE)
# uTKexp.l[l,es,d,t]$(t.val <= tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
#    (vTI.l[l,es,d,t] # Investment costs
#     + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt])) # Discounted variable costs
#       / @Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Dicounted denominator
#       ;

#   # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
#   uTKexp.l[l,es,d,t]$(t.val > tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
#      (vTI.l[l,es,d,t] # Investment costs
#       + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discounted variable costs until tEnd
#       + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({vTC.l[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
#       / (@Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discount denominator until tEnd
#        + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted denominator after tEnd
#        ; 

# # 1.3 Technology Prices
# # Technology price for plotting the discrete supply curve
# pTPotential.l[l,es,d,t] = sum(e$(d1pEpj[es,e,d,t] and d1uTE[l,es,e,d,t]), uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t])
#                         + uTKexp.l[l,es,d,t]*pTK.l[d,t];

## ----------------------------------------------------------------------------------------
## Creating electricity technologies
## ----------------------------------------------------------------------------------------

parameter
  # pTPotential_max[es,d,t] "Maximum technology price for each energy service"
  vTI_max[es,d,t] "Maximum investment costs for each energy service"
  ;

# Determining the most expensive technology (used in determining the range for the supply curve)
# pTPotential_max[es,d,t] = smax(l, pTPotential.l[l,es,d,t]);


vTI_max[es,d,t] = smax(l, vTI[l,es,d,t]);

# First electrification technology
sqTPotential['t26',es,i,t]$(sum(ll, sqTPotential[ll,es,i,t])) = 0.1;
uTE['t26',es,'Electricity',i,t]$(sqTPotential['t26',es,i,t]) = 1;
vTI['t26',es,i,t]$(sqTPotential['t26',es,i,t]) = vTI_max[es,i,t]+0.1;
vTC['t26',es,i,t]$(sqTPotential['t26',es,i,t]) = vTI['t26',es,i,t]/10;

# Second electrification technology
sqTPotential['t27',es,i,t]$(sum(ll, sqTPotential[ll,es,i,t])) = 0.1;
uTE['t27',es,'Electricity',i,t]$(sqTPotential['t27',es,i,t]) = 1;
vTI['t27',es,i,t]$(sqTPotential['t27',es,i,t]) = vTI_max[es,i,t]+0.2;
vTC['t27',es,i,t]$(sqTPotential['t27',es,i,t]) = vTI['t27',es,i,t]/10;

## ----------------------------------------------------------------------------------------
## Set LifeSpan and pTK
## ----------------------------------------------------------------------------------------

pTK[d,t]$(sum((l,es), sqTPotential[l,es,d,t])) = 1;
LifeSpan[l,es,i,t]$(sqTPotential[l,es,i,t]) = 5;

## ----------------------------------------------------------------------------------------
## Updating dummies
## ----------------------------------------------------------------------------------------

set these_sectors(d) /
  # '10010'
  # '10020' # LBS: Works in calibration but not in shock
  '10030'
  # '10040' # LBS: Does not work at the moment
  # '10120' 
  # '13150' # LBS: Does not work at the moment
  # '16000' # LBS: Does not work at the moment
  # '19000'
  # '20000' # LBS: Works in calibration but not in shock
  # '21000' # LBS: Works in calibration but not in shock
  # '23001'
  # '23002' # LBS: Does not work at the moment
  # '25000' # LBS: Does not work at the moment
  /;

set these_eservices(es) /
  'heating'
  # 'transport'
  # 'process_normal'
  # 'process_special'
  # 'in_ETS'
  /;

sqTPotential[l,es,d,t]$(not (these_sectors(d) and these_eservices(es))) = 0;
uTE[l,es,e,d,t]$(not (these_sectors(d) and these_eservices(es))) = 0;
vTI[l,es,d,t]$(not (these_sectors(d) and these_eservices(es))) = 0;
vTC[l,es,d,t]$(not (these_sectors(d) and these_eservices(es))) = 0;
LifeSpan[l,es,d,t]$(not (these_sectors(d) and these_eservices(es))) = 0;
pTK[d,t]$(not these_sectors(d)) = 0;
qES[es,d,t]$(not (these_sectors(d) and these_eservices(es))) = 0;

# d1sqTPotential[l,es,d,t] = no;
# d1uTE[l,es,e,d,t] = no;
# d1pTK[d,t] = no;
# d1qES_e[es,e,d,t] = no;
# d1qES[es,d,t] = no;

# d1sqTPotential[l,es,d,t] = yes$(sqTPotential.l[l,es,d,t] and these_eservices(es) and these_sectors(d));
# d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t] and these_eservices(es) and these_sectors(d));
# d1pTK[d,t] = yes$(sum((l,es), d1sqTPotential[l,es,d,t]));
# d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));
# d1qES[es,d,t] = yes$(qES.l[es,d,t] and these_eservices(es) and these_sectors(d));

# Unload gdx-file
execute_unload 'Abatement_data\calibrate_abatement_techs.gdx'
              sqTPotential
              uTE
              vTI
              vTC
              LifeSpan
              pTK
              qES
              ;
