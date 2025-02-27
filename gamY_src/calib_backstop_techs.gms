## ----------------------------------------------------------------------------------------
## Creating back-stop technologies (electricity)
## ----------------------------------------------------------------------------------------

parameter
  d1Expensive_tech[es,d,t]
  ;

# Calculating technology price of all technologies (excluding back-stop technologies)
pT.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sum(e$(uTE.l[l,es,e,d,t]), uTE.l[l,es,e,d,t]*pT_e.l[es,e,d,t])
																	        + uTK.l[l,es,d,t]*pT_k.l[d,t];

# Determining the most expensive technology
d1Expensive_tech[es,d,t] = smax(ll, pT.l[ll,es,d,t]);

# The back-stop technologies cost 30 pct. and 40 pct. more than the most expensive technology
pT.l['t_Electricity_calib',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 1.3 * d1Expensive_tech[es,d,t];
pT.l['t_Electricity_calib_2',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 1.4 * d1Expensive_tech[es,d,t];

# Stress test: Decreasing price difference between baseline technologies and backstop technologies (Solves easily)
$IF %stress_decrease_price_backstop_tech% = 1:
  pT.l['t_Electricity_calib',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 1.05 * d1Expensive_tech[es,d,t];
  pT.l['t_Electricity_calib_2',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 1.1 * d1Expensive_tech[es,d,t];
$ENDIF

# Stress test: Increasing price difference between baseline technologies and backstop technologies (Static calibration solves easily but dynamic calibration does not solve)
# Dynamic calibration error message: ** A derivative in the initial point is very large or NaN (Not a Number).
$IF %stress_increase_price_backstop_tech% = 1:
  pT.l['t_Electricity_calib',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 3 * d1Expensive_tech[es,d,t];
  pT.l['t_Electricity_calib_2',es,d,t]$(sum(l, sTPotential.l[l,es,d,t])) = 3.1 * d1Expensive_tech[es,d,t];
$ENDIF

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

# Stress test: Eliminating backstop technologies (Solves easily)
$IF %stress_no_backstop_tech% = 1:
  sTPotential.l['t_Electricity_calib',es,d,t]$(t.val>2018 and sum(l, sTPotential.l[l,es,d,t])) = 0;
  sTPotential.l['t_Electricity_calib_2',es,d,t]$(t.val>2018 and sum(l, sTPotential.l[l,es,d,t])) = 0;
$ENDIF

execute_unloaddi "calib_elec_techs.gdx";
