# ------------------------------------------------------------------------------
# Calibrate CCS technologies
# ------------------------------------------------------------------------------

# Define the CCS technologies
set CCS_techs[l] /
  't30'
  /;


# Technology potentials
sqTPotential.l[CCS_techs,'process_special','23001',t]$(t.val > 2025) = ;

# Investment costs
vTI.l[CCS_techs,'process_special','23001',t]$(t.val > 2025) = ;

# Operating costs
vTC.l[CCS_techs,'process_special','23001',t]$(t.val > 2025) = ;

# Energy input
uTE.l[CCS_techs,'process_special',e,'23001',t]$(t.val > 2025) = ;
uTE.l[CCS_techs,'process_special','Electricity','23001',t]$(t.val > 2025) = ;
uTE.l[CCS_techs,'process_special','Captured CO2','23001',t]$(t.val > 2025) = ;

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

# Solve model
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
@import_from_modules("report")
execute_unload 'Output/calibration_CCS.gdx';