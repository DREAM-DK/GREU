## ----------------------------------------------------------------------------------------
## Creating electrification technologies
## ----------------------------------------------------------------------------------------

parameter
  d1Expensive_tech[l,es,i,t]
  d1Expensive_tech_test[es,i,t]
  ;

pREpj_base.l[es,e,i,t]$(d1pREpj_base[es,e,i,t]) = (1+fpRE.l[es,e,i,t]) * pE_avg.l[e,t];

pREpj.l[es,e,i,t]$(d1pREpj_base[es,e,i,t]) = (1+tpRE.l[es,e,i,t]) * pREpj_base.l[es,e,i,t];
pREpj.l[es,e,i,t]$(d1tqRE[es,e,i,t]) = tqRE.l[es,e,i,t];

# Technology price
pT.l[l,es,i,t]$(d1theta[l,es,i,t]) = sum(e$(d1uTE[l,es,e,i,t]), uTE.l[l,es,e,i,t]*pREpj.l[es,e,i,t])
																	  + uTK.l[l,es,i,t]*pK_abatement.l[i,t];

d1Expensive_tech_test[es,i,t] = smax(ll, pT.l[ll,es,i,t]);

pT.l['t_Electricity_calib',es,i,t]$(sum(l, d1theta[l,es,i,t])) = 1.5 * d1Expensive_tech_test[es,i,t];

theta.l['t_Electricity_calib',es,i,t]$(t.val>2018 and sum(l, d1theta[l,es,i,t])) = 0.5;

d1theta[l,es,i,t] = yes$(theta.l[l,es,i,t]);

uTE.l['t_Electricity_calib',es,'Electricity',i,t]$(t.val>2018 and sum(l, d1theta[l,es,i,t])) = 1;
uTK.l['t_Electricity_calib',es,i,t]$(t.val=2019 and sum(l, d1theta[l,es,i,t])) 
  = (pT.l['t_Electricity_calib',es,i,t] - sum(e, uTE.l['t_Electricity_calib',es,e,i,t]*pREpj.l[es,e,i,t]))
    / pK_abatement.l[i,t];


execute_unloaddi "calib_elec_techs.gdx";


d1uTE[l,es,e,i,t] = yes$(uTE.l[l,es,e,i,t]);
d1pK_abatement[i,t] = yes$(sum((l,es), d1theta[l,es,i,t]));
d1qE_tech[es,e,i,t] = yes$(sum(l, d1uTE[l,es,e,i,t]));

pK_abatement.l[i,t]$(sum((l,es), d1theta[l,es,i,t])) = 0.1;
qES.l[es,i,t] = sum(e, qREpj.l[es,e,i,t]);

svP.l[es,i,t]$(sum(l, d1theta[l,es,i,t])) = 1;
eP.l[l,es,i,t]$(d1theta[l,es,i,t]) = 0.5;