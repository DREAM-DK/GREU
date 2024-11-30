## ----------------------------------------------------------------------------------------
## Creating electrification technologies
## ----------------------------------------------------------------------------------------

## PARTIAL ENERGY PRICE MODEL




# parameter
#   d1Expensive_tech[l,es,d,t]
#   d1Expensive_tech_test[es,d,t]
#   ;

# pEpj_base.l[es,e,d,t] = (1+fpE.l[es,e,d,t]) * pE_avg.l[e,t];

# pEpj.l[es,e,d,t] = (1+tpE.l[es,e,d,t]) * pEpj_base.l[es,e,d,t];
# # pEpj.l[es,e,d,t]$(d1tqRE[es,e,d,t]) = tqRE.l[es,e,d,t];

# # Technology price
# pT.l[l,es,d,t]$(d1theta[l,es,d,t]) = sum(e$(d1uTE[l,es,e,d,t]), uTE.l[l,es,e,d,t]*pEpj.l[es,e,d,t])
# 																	  + uTK.l[l,es,d,t]*pK_abatement.l[d,t];

# d1Expensive_tech_test[es,d,t] = smax(ll, pT.l[ll,es,d,t]);

# pT.l['t_Electricity_calib',es,d,t]$(sum(l, d1theta[l,es,d,t])) = 1.2 * d1Expensive_tech_test[es,d,t];

theta.l['t_Electricity_calib',es,d,t]$(t.val>2018 and sum(l, d1theta[l,es,d,t])) = 0.1;
theta.l['t_Electricity_calib_2',es,d,t]$(t.val>2018 and sum(l, d1theta[l,es,d,t])) = 0.1;

d1theta[l,es,d,t] = yes$(theta.l[l,es,d,t]);

uTE.l['t_Electricity_calib',es,'Electricity',d,t]$(t.val>2018 and sum(l, d1theta[l,es,d,t])) = 1;
uTE.l['t_Electricity_calib_2',es,'Electricity',d,t]$(t.val>2018 and sum(l, d1theta[l,es,d,t])) = 1;
# uTK.l['t_Electricity_calib',es,d,t]$(t.val=2019 and sum(l, d1theta[l,es,d,t])) 
#   = (pT.l['t_Electricity_calib',es,d,t] - sum(e, uTE.l['t_Electricity_calib',es,e,d,t]*pEpj.l[es,e,d,t]))
#     / pK_abatement.l[d,t];


# uTK.l['t_Electricity_calib','heating','10030',t] = 2.45;
uTK.l['t_Electricity_calib','heating','10030',t] = 2.5;
uTK.l['t_Electricity_calib_2','heating','10030',t] = 3;

execute_unloaddi "calib_elec_techs.gdx";


d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1pK_abatement[d,t] = yes$(sum((l,es), d1theta[l,es,d,t]));
d1qE_tech[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));

pK_abatement.l[d,t]$(sum((l,es), d1theta[l,es,d,t])) = 0.1;
qES.l[es,d,t] = sum(e, qEpj.l[es,e,d,t]);

svP.l[es,d,t]$(sum(l, d1theta[l,es,d,t])) = 1;
eP.l[l,es,d,t]$(d1theta[l,es,d,t]) = 0.5;