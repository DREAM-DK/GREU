## ----------------------------------------------------------------------------------------
## Creating dummy technologies
## ----------------------------------------------------------------------------------------

# Set restricting the technologies that are included in the dummy data calibration
set tech_l[l] /
  set.l
  /;

alias (tech_l,tech_ll);

# tech_l excludes back-stop technologies
tech_l[l]$(sameas[l,'t_Electricity_calib'] or sameas[l,'t_Electricity_calib_2']) = no;

# Stress test: Restricting number of technologies
$IF %stress_restrict_techs%:
  set restrict_l[l] / 
    't_Biogas_10'
    't_Coal and coke_10'
    't_Diesel for transport_10'
    't_District heat_10'
    't_Electricity_10'
    't_Firewood and woodchips_10'
    't_Gasoline for transport_10'
    't_Heat pumps_10'
  /;

  tech_l[l]$(not restrict_l[l]) = no;
$ENDIF

# Set restricting the sectors that are included in the dummy data calibration
set tech_d[d] /
  '10030'
  # set.d
  /;

# Restricting d to only include production sectors
tech_d[d]$(not i[d]) = no;

# Set restricting the energy services that are included in the dummy data calibration
set tech_es[es] /
  'heating'
  # set.es
  /;

# Energy service is set to 1
qES.l[es,d,t] = 0;
qES.l[tech_es,tech_d,t] = 1;

# Energy prices are set to 1 for all energy input
pT_e.l[es,e,d,t] = 0;
pT_e.l[tech_es,e,tech_d,t] = 1;

# Mapping between energy input and technologies
set map_e_2_l[e,l];
map_e_2_l[e,tech_l] = yes$(sum((es,d,t), uTE.l[tech_l,es,e,d,t]));

# Defining energy efficiency
uTE.l[l,es,e,d,t] = 0;
uTE.l[tech_l,tech_es,e,tech_d,t]$(map_e_2_l[e,tech_l]) = 1;

# Setting all capital costs to 0
uTK.l[l,es,d,t] = 0;
# uTK.l[tech_l,tech_es,tech_d,t] = ord(tech_l)*0.01;

# Parameter for increasing capital costs for each technology
parameter
  counter / 0.01 /
  ;

# Loop defining capital costs (must be different across technologies)
LOOP((tech_l)$(sum(e, map_e_2_l[e,tech_l])),
    uTK.l[tech_l,tech_es,tech_d,t] = counter;
    $IF %stress_price_base_tech% = 0:
      counter = counter + 0.01;
    $ENDIF
    $IF %stress_price_base_tech% = 1:
      # counter = counter + 500; # Stress test: Increasing price difference between technologies (increases iterations a little bit)
      counter = counter + 100; # Stress test: Increasing price difference between technologies (increases iterations a little bit)
    $ENDIF
);

$IF %stress_price_base_tech2% = 1:
# Det virker som om, smertegrænsen er 11.6
uTK.l[tech_l,tech_es,tech_d,t]$(sameas[tech_l,'t_Bunkering of Danish operated vessels on foreign territory_100']) = counter + 11.7;
$ENDIF

# Defining potentials
sTPotential.l[l,es,d,t] = 0;
sTPotential.l[tech_l,tech_es,tech_d,t] = qES.l[tech_es,tech_d,t]/sum(tech_ll$(uTK.l[tech_ll,tech_es,tech_d,t]), 1);

# Stress test: Reducing potentials for base technologies
$IF %stress_reduced_potential_base_tech% = 1:
  sTPotential.l[tech_l,tech_es,tech_d,t] = 0.95*qES.l[tech_es,tech_d,t]/sum(tech_ll$(uTK.l[tech_ll,tech_es,tech_d,t]), 1);
$ENDIF

# Defining user cost on capital
pT_k.l[d,t]$(sum((l,es), sTPotential.l[l,es,d,t])) = 0.1;

# =============================================================
# No technology data
# =============================================================

# qES.l[tech_es,tech_d,t]     = 0;
# pT_e.l[tech_es,e,tech_d,t]  = 0;
# uTE.l[tech_l,es,e,d,t]      = 0;
# uTK.l[tech_l,es,d,t]        = 0;
# sTPotential.l[tech_l,es,d,t] = 0;

# =============================================================
# Calibration of back-stop technologies
# =============================================================

$import calib_backstop_techs.gms

# =============================================================
# Calculating smooth supply curves for each energy service
# =============================================================

# Defining efficiency of costs of technology l (smoothing parameter)"
eP.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = 0.05;

# Stress test: Increasing smoothing parameter
$IF1 %stress_increase_eP% = 1:
  eP.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = 0.5;
$ENDIF1

# Set determining the number of data points on the smoothed supply curve
set trace /trace1*trace1000/;
  
parameter
  sTSupply_trace[l,es,d,t,trace] "Smoothed supply curve for technology l"
  sTSupply_trace_suml[es,d,t,trace] "Smoothed supply curve for technology for all technologies"
  pESmarg_trace[l,es,d,t,trace]
;

# Re-determining the most expensive technology
d1Expensive_tech[es,d,t] = smax(ll, pT.l[ll,es,d,t]);

# Defining marginal costs for each trace (goes from zero up to 4 standard deviations times the price of the most expensive technology)
pESmarg_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = ord(trace)/1000 * (d1Expensive_tech[es,d,t] * (1 + 4 * eP.l[l,es,d,t]));

# Smoothed supply curve for technology l
sTSupply_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(pESmarg_trace[l,es,d,t,trace],pT.l[l,es,d,t],eP.l[l,es,d,t]);
# Smoothed supply curve for technology for all technologies
sTSupply_trace_suml[es,d,t,trace] = sum(l$(sTPotential.l[l,es,d,t]), sTSupply_trace[l,es,d,t,trace]);

# Unload gdx-file with dummy technologies
execute_unloaddi "calib_dummy_techs.gdx";


