# ==============================================================================
# Module for solving supply curves and setting initial values
# ==============================================================================

# Updating energy input price for plotting the discrete supply curve
pTE.l[es,e,d,t] =  pTE_base.l[es,e,d,t] + pTE_tax.l[es,e,d,t]; 

# Technology price for plotting the discrete supply curve
pTPotential.l[l,es,d,t]	= sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])
										    + uTKexp.l[l,es,d,t]*pTK.l[d,t];


# ------------------------------------------------------------------------------
# Initializing variables for supply curve calculation
# ------------------------------------------------------------------------------

# Determining the most expensive technology (used in determining the range for the supply curve (in pESmarg_scen below))
d1Expensive_tech_smooth_scen[es,d,t] = smax(l, pTPotential.l[l,es,d,t] * (1 + 4 * eP.l[l,es,d,t]));

# Defining marginal costs for each trace (goes from zero up to 4 standard deviations times the price of the most expensive technology)
pESmarg_scen.l[es,d,t,scen]$(sum(l, d1sTPotential[l,es,d,t])) = ord(scen)/100 * d1Expensive_tech_smooth_scen[es,d,t];

# Random starting values for the marginal costs of capital
uTKmarg_scen.l[l,es,d,t,scen]$(sTPotential.l[l,es,d,t]) = 1;
uTKmargNobound_scen.l[l,es,d,t,scen]$(sTPotential.l[l,es,d,t]) = uTKmarg_scen.l[l,es,d,t,scen];

# ------------------------------------------------------------------------------
# Solving the model for supply curve calculation
# ------------------------------------------------------------------------------

# Solving the model
$FIX G_abatement_supply_curve_exo;
$UNFIX G_abatement_supply_curve_endo;
@Setbounds_abatement();
Solve M_abatement_supply_curve using CNS;
 
# ------------------------------------------------------------------------------
# Creating starting values for the main model
# ------------------------------------------------------------------------------

# Determining uTKmarg and pESmarg in equilibrium
uTKmarg_eq[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sum(scen, uTKmarg_scen.l[l,es,d,t,scen]$(sqT2qES_sum_scen.l[es,d,t,scen]  >= 1 and sqT2qES_sum_scen.l[es,d,t,scen-1]  < 1) );
pESmarg_eq[es,d,t] = smax(l, sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])	+ uTKmarg_eq[l,es,d,t]*pTK.l[d,t] )  ;

# Setting starting values for the main model
uTKmarg.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg_eq[l,es,d,t]; 
# For some reason, the model can't solve when given too good starting values for uTKmarg
uTKmarg.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t] + 3; 

uTKmargNobound.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t];
sqT2qES.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = sTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_eq[l,es,d,t],uTKexp.l[l,es,d,t],eP.l[l,es,d,t]);
pESmarg.l[es,d,t] = pESmarg_eq[es,d,t];

