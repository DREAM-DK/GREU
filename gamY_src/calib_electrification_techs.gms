## ----------------------------------------------------------------------------------------
## Creating electrification technologies
## ----------------------------------------------------------------------------------------


parameter
  d1Expensive_tech[l,es,d,t]
  d1Expensive_tech_test[es,d,t]
  ;

# pT_e_base.l[es,e,d,t] = (1+fpE.l[es,e,d,t]) * pE_avg.l[e,t];

# pT_e.l[es,e,d,t] = (1+tpE.l[es,e,d,t]) * pT_e_base.l[es,e,d,t];
# # pT_e.l[es,e,d,t]$(d1tqRE[es,e,d,t]) = tqRE.l[es,e,d,t];

# Calculating technology price of all technologies (excluding back-stop technologies)
pT.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sum(e$(uTE.l[l,es,e,d,t]), uTE.l[l,es,e,d,t]*pT_e.l[es,e,d,t])
																	        + uTK.l[l,es,d,t]*pT_k.l[d,t];

# Determining the most expensive technology
d1Expensive_tech_test[es,d,t] = smax(ll, pT.l[ll,es,d,t]);

# The first back-stop technology cost 20 pct. more than the most expensive technology
pT.l['t_Electricity_calib',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 1.3 * d1Expensive_tech_test[es,d,t];
pT.l['t_Electricity_calib_2',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 1.4 * d1Expensive_tech_test[es,d,t];

# Energy efficiency of back-stop technologies are set to 1
uTE.l['t_Electricity_calib',es,'Electricity',d,t]$(t.val>2018 and sum(l, sTPotential.l[l,es,d,t])) = 1;
uTE.l['t_Electricity_calib_2',es,'Electricity',d,t]$(t.val>2018 and sum(l, sTPotential.l[l,es,d,t])) = 1;

# Capital costs are calculated as a residual to ensure the relative price of back-stop technologies compared to the most expensive technology
uTK.l['t_Electricity_calib',es,d,t]$(t.val=2019 and sum(l, sTPotential.l[l,es,d,t])) 
  = (pT.l['t_Electricity_calib',es,d,t] - sum(e, uTE.l['t_Electricity_calib',es,e,d,t]*pT_e.l[es,e,d,t]))
    / pT_k.l[d,t];
uTK.l['t_Electricity_calib_2',es,d,t]$(t.val=2019 and sum(l, sTPotential.l[l,es,d,t])) 
  = (pT.l['t_Electricity_calib_2',es,d,t] - sum(e, uTE.l['t_Electricity_calib_2',es,e,d,t]*pT_e.l[es,e,d,t]))
    / pT_k.l[d,t];

# Potentials for back-stop technologies are set to 10 pct. of energy service
sTPotential.l['t_Electricity_calib',es,d,t]$(t.val>2018 and sum(l, sTPotential.l[l,es,d,t])) = 0.1;
sTPotential.l['t_Electricity_calib_2',es,d,t]$(t.val>2018 and sum(l, sTPotential.l[l,es,d,t])) = 0.1;

# uTK.l['t_Electricity_calib','heating','10030',t] = 2.45;
# uTK.l['t_Electricity_calib','heating','10030',t] = 2.5;
# uTK.l['t_Electricity_calib_2','heating','10030',t] = 3;

execute_unloaddi "calib_elec_techs.gdx";
