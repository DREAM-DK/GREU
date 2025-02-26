## ----------------------------------------------------------------------------------------
## Creating dummy technologies
## ----------------------------------------------------------------------------------------

set tech_l[l] /
  set.l
  /;

alias (tech_l,tech_ll);

tech_l[l]$(sameas[l,'t_Electricity_calib'] or sameas[l,'t_Electricity_calib_2']) = no;

set tech_d[d] /
  '10030'
  /;

set tech_es[es] /
  'heating'
  /;

# Energy service is set to 1
qES.l[tech_es,tech_d,t] = 1;

# Energy prices are set to 1 for all energy input
pT_e.l[tech_es,e,tech_d,t] = 1;

# Mapping between energy input and technologies
set map_e_2_l[e,l];
map_e_2_l[e,tech_l] = yes$(sum((es,d,t), uTE.l[tech_l,es,e,d,t]));

# Defining energy efficiency
uTE.l[tech_l,es,e,d,t] = 0;
uTE.l[tech_l,tech_es,e,tech_d,t]$(map_e_2_l[e,tech_l]) = 1;

# Defining capital costs (must be different across technologies)
uTK.l[tech_l,es,d,t] = 0;
# uTK.l[tech_l,tech_es,tech_d,t] = ord(tech_l)*0.01;

parameter
  counter
  ;

counter = 0.01;

LOOP((tech_l)$(sum(e, map_e_2_l[e,tech_l])),
    uTK.l[tech_l,tech_es,tech_d,t] = counter;
    counter = counter + 0.01;
);

# Potentials
sTPotential.l[tech_l,es,d,t] = 0;
sTPotential.l[tech_l,tech_es,tech_d,t] = qES.l[tech_es,tech_d,t]/sum(tech_ll$(uTK.l[tech_ll,tech_es,tech_d,t]), 1);

# User cost on capital
pT_k.l[d,t]$(sum((l,es), sTPotential.l[l,es,d,t])) = 0.1;