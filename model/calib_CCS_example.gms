# ------------------------------------------------------------------------------
# Calibrate decreasing capital costs for CCS technologies
# ------------------------------------------------------------------------------

# Define the electrification technologies
set CCS_techs[l] /
  't30'
  /;

# Technology potentials
sqTPotential.l['t30','process_special','23001',t]$(t.val > 2025) = sqTPotential.l['t7','process_special','23001',t];

# Investment costs
vTI.l['t30','process_special','23001',t]$(t.val > 2025) = vTI.l['t7','process_special','23001',t] + 0.1;

# Operating costs
vTC.l[CCS_techs,'process_special','23001',t]$(t.val > 2025) = vTI.l[CCS_techs,'process_special','23001',t]/10;

# Energy input
uTE.l[CCS_techs,'process_special',e,'23001',t]$(t.val > 2025) = uTE.l['t7','process_special',e,'23001',t];
uTE.l[CCS_techs,'process_special','Electricity','23001',t]$(t.val > 2025) = 0.1;
uTE.l[CCS_techs,'process_special','Captured CO2','23001',t]$(t.val > 2025) #= -84.1;
  = sum((em,ee)$(sameas[em,'co2ubio'] or sameas[em,'co2bio']), 
      uTE.l[CCS_techs,'process_special',ee,'23001',t]*uEmmE_BU.l[em,'process_special',ee,'23001',t])
    * 0.9;

# Life span
LifeSpan[CCS_techs,'process_special','23001',t]$(t.val > 2025) = 5;

# Set discount rate
DiscountRate[CCS_techs,'process_special','23001'] = 0.05;

# Set smoothing parameters
eP.l[CCS_techs,'process_special','23001',t]$(sqTPotential.l[CCS_techs,'process_special','23001',t]) = eP.l['t1','process_special','23001',t];

# Set dummy determining the existence of technology potentials
d1sqTPotential[l,es,d,t] = yes$(sqTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));

# Supply Curve Visualization
$import Supply_curves_abatement.gms;

# # Solve partial abatement model
# $FIX all_variables;
# $UNFIX abatement_partial_endogenous;
# Solve abatement_partial_equations using CNS;
# execute_unload 'Output\calibration_CCS_abatement_partial.gdx';

# Solve model
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
@import_from_modules("report")
execute_unload 'Output\calibration_CCS.gdx';