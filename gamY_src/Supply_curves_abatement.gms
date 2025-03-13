# =============================================================
# Calculating smooth supply curves for each energy service
# =============================================================


# Set determining the number of data points on the smoothed supply curve
set trace /trace1*trace1000/;
  
parameter
  d1Expensive_tech_smooth[es,d,t] "Most expensive technology"
  sTSupply_trace[l,es,d,t,trace] "Smoothed supply curve for technology l"
  sTSupply_trace_suml[es,d,t,trace] "Smoothed supply curve for technology for all technologies"
  pESmarg_trace[es,d,t,trace] "Auxiliary price parameter for determining the smooth supply curve"
  pESmarg_eq[es,d,t,trace] "The partial marginal price, that will satisfy the demanded energy service"
;

# Re-determining the most expensive technology
d1Expensive_tech_smooth[es,d,t] = smax(ll, pTPotential.l[ll,es,d,t] * (1 + 4 * eP.l[ll,es,d,t]));

# Defining marginal costs for each trace (goes from zero up to 4 standard deviations times the price of the most expensive technology)
pESmarg_trace[es,d,t,trace]$(sum(l, sTPotential.l[l,es,d,t])) = ord(trace)/1000 * d1Expensive_tech_smooth[es,d,t];

# Smoothed supply curve for technology l
sTSupply_trace[l,es,d,t,trace]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(pESmarg_trace[es,d,t,trace],pTPotential.l[l,es,d,t],eP.l[l,es,d,t]);

# Smoothed supply curve for technology for all technologies
# sTSupply_trace_suml[es,d,t,trace]$(sum(l, sTPotential.l[l,es,d,t])) = sum(l$(sTPotential.l[l,es,d,t]), sTSupply_trace[l,es,d,t,trace]);
sTSupply_trace_suml[es,d,t,trace]$(sum(l, sTPotential.l[l,es,d,t])) = sum(l$(sTPotential.l[l,es,d,t]), sTPotential.l[l,es,d,t]*@cdfLogNorm(pESmarg_trace[es,d,t,trace],pTPotential.l[l,es,d,t],eP.l[l,es,d,t]));

pESmarg_eq[es,d,t,trace]$(sTSupply_trace_suml[es,d,t,trace] >= 1 and sTSupply_trace_suml[es,d,t,trace-1] < 1) = pESmarg_trace[es,d,t,trace];

# Initial values for pESmarg and sTSupply (helps the solver getting a good starting point)
pESmarg.l[es,d,t] = sum(trace, pESmarg_eq[es,d,t,trace]);
sTSupply.l[l,es,d,t] = sum(trace$(pESmarg_eq[es,d,t,trace]), sTSupply_trace[l,es,d,t,trace]);

# Unload gdx-file with dummy technologies
execute_unloaddi "supply_curves_data.gdx";