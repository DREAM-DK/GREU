## ----------------------------------------------------------------------------------------
## Creating dummy technologies
## ----------------------------------------------------------------------------------------

set tech_l[l] /
  set.l
  /;

alias (tech_l,tech_ll);

tech_l[l]$(sameas[l,'t_Electricity_calib'] or sameas[l,'t_Electricity_calib_2']) = no;

# Stress test: Restricting number of technologies
$IF %stress_restrict_techs%:
  set restrict_l[l] / 
    't_Biogas_10'
  /;

  tech_l[l]$(not restrict_l[l]) = no;
$ENDIF

set tech_d[d] /
  '10030'
  # set.d
  /;

# Restricting d to only include production sectors
tech_d[d]$(not i[d]) = no;

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

# Defining capital costs (must be different across technologies)
uTK.l[l,es,d,t] = 0;
# uTK.l[tech_l,tech_es,tech_d,t] = ord(tech_l)*0.01;

parameter
  counter
  ;

counter = 0.01;

LOOP((tech_l)$(sum(e, map_e_2_l[e,tech_l])),
    uTK.l[tech_l,tech_es,tech_d,t] = counter;
    $IF %stress_price_base_tech% = 0:
      counter = counter + 0.01;
    $ENDIF
    $IF %stress_price_base_tech% = 1:
      counter = counter + 10; # Stress test: Increasing price difference between technologies (increases iterations a little bit)
    $ENDIF
);

# Potentials
sTPotential.l[l,es,d,t] = 0;
sTPotential.l[tech_l,tech_es,tech_d,t] = qES.l[tech_es,tech_d,t]/sum(tech_ll$(uTK.l[tech_ll,tech_es,tech_d,t]), 1);

# User cost on capital
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
