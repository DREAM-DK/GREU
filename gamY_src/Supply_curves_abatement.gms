# =============================================================
# Calculating smooth supply curves for each energy service
# =============================================================


# Set determining the number of data points on the smoothed supply curve
set trace /trace1*trace1000/;
  
parameter
  d1Expensive_tech_smooth[es,d,t] "Most expensive technology"
  sqT2qES_trace[l,es,d,t,trace]     "Smoothed supply curve for technology l"
  sqT2qES_trace_suml[es,d,t,trace]  "Smoothed aggregate supply curve"
  pESmarg_trace[es,d,t,trace] "Auxiliary price parameter for determining the smooth supply curve of technologies"
  uTKmarg_trace[l,es,d,t,trace] "Auxiliary parameter for determining the smooth supply curve for each technology"
  uTKmarg_trace_eq[l,es,d,t]  "The marginal cost of capital in equilibrium, ie. at the point where demand is satisified"
  pESmarg_trace_eq[es,d,t]    "The marginal cost of energy service in equilibrium, ie. at the point where demand is satisified"
;

pTE.l[es,e,d,t]$(d1pTE[es,e,d,t]) =  pTE_base.l[es,e,d,t] + pTE_tax.l[es,e,d,t];
pTPotential.l[l,es,d,t]$(d1sTPotential[l,es,d,t])	
  = sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])+ uTKexp.l[l,es,d,t]*pTK.l[d,t];

# Re-determining the most expensive technology
d1Expensive_tech_smooth[es,d,t] = smax(ll, pTPotential.l[ll,es,d,t] * (1 + 4 * eP.l[ll,es,d,t]));

# Defining marginal costs for each trace (goes from zero up to 4 standard deviations times the price of the most expensive technology)
pESmarg_trace[es,d,t,trace]$(sum(l, sTPotential.l[l,es,d,t])) = ord(trace)/1000 * d1Expensive_tech_smooth[es,d,t];

# Residual calculation of the marginal costs of capital for given value of pESmarg_trace. Equivilant to equation governing uTK in abatement.gms
uTKmarg_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = max (0.000001, ( pESmarg_trace[es,d,t,trace] - sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	) / pTK.l[d,t] ); 

# Smoothed supply curve for technology l
sqT2qES_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_trace[l,es,d,t,trace],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);

# Smoothed supply curve for technology for all technologies
sqT2qES_trace_suml[es,d,t,trace] = sum(l$(sTPotential.l[l,es,d,t]), sqT2qES_trace[l,es,d,t,trace] );

uTKmarg_trace_eq[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sum(trace, uTKmarg_trace[l,es,d,t,trace]$(sqT2qES_trace_suml[es,d,t,trace]  >= 1 and sqT2qES_trace_suml[es,d,t,trace-1]  < 1) );

pESmarg_trace_eq[es,d,t] =   smax(l, sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	+ uTKmarg_trace_eq[l,es,d,t]*pTK.l[d,t] )  ;

# Initial values for pESmarg and sTold (helps the solver getting a good starting point)
uTKmarg.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg_trace_eq[l,es,d,t] ;
uTKmargNobound.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t] ;
sqT2qES.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_trace_eq[l,es,d,t],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);
#pESmarg.l[es,d,t] = pESmarg_trace_eq[es,d,t] ;

# Unload gdx-file with dummy technologies
execute_unloaddi "abatement_old_supply_curves.gdx";