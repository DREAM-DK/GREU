# ======================================================================================================================
# Supply Curves for Abatement Model
# ======================================================================================================================
# This module solves a pre-model in order to calculate supply curves for the main abatement model.

# ----------------------------------------------------------------------------------------------------------------------
# 1. Calibrate new technology data
# ----------------------------------------------------------------------------------------------------------------------


# $import calib_abatement_techs.gms;


# ----------------------------------------------------------------------------------------------------------------------
# 1. Update energy dummies and prices
# ----------------------------------------------------------------------------------------------------------------------

$FIX all_variables; $UNFIX energy_price_partial_endogenous;
# execute_unload 'energy_price_partial_pre.gdx';
Solve energy_price_partial using CNS;
# execute_unload 'energy_price_partial_post.gdx';

# ----------------------------------------------------------------------------------------------------------------------
# 1. Initialize linking variables
# ----------------------------------------------------------------------------------------------------------------------

# Initialise linking variables
qES.l[es,i,t]$(qES.l[es,i,t] and qREes.l[es,i,t]) = uES.l[es,i,t]*qREes.l[es,i,t];
pTK.l[i,t]$(d1pTK[i,t] and d1K_k_i['iM',i,t]) = pK_k_i.l['iM',i,t]*jpTK.l[i,t];

# ----------------------------------------------------------------------------------------------------------------------
# 1. Price Initialization
# ----------------------------------------------------------------------------------------------------------------------
# 1.2 Starting values for Levelized Cost of Energy (LCOE)
uTKexp.l[l,es,d,t]$(t.val <= tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
   (vTI.l[l,es,d,t] # Investment costs
    + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt])) # Discounted variable costs
      / @Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Dicounted denominator
      ;

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  uTKexp.l[l,es,d,t]$(t.val > tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
     (vTI.l[l,es,d,t] # Investment costs
      + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discounted variable costs until tEnd
      + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({vTC.l[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
      / (@Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discount denominator until tEnd
       + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted denominator after tEnd
       ; 

# 1.3 Technology Prices
# Technology price for plotting the discrete supply curve
pTPotential.l[l,es,d,t] = sum(e$(d1pEpj[es,e,d,t] and d1uTE[l,es,e,d,t]), uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t])
                        + uTKexp.l[l,es,d,t]*pTK.l[d,t];

# ----------------------------------------------------------------------------------------------------------------------
# 2. Supply Curve Initialization
# ----------------------------------------------------------------------------------------------------------------------
# 2.1 Technology Range Determination
# Determining the most expensive technology (used in determining the range for the supply curve)
d1Expensive_tech_smooth_scen[es,d,t] = smax(l, pTPotential.l[l,es,d,t] * (1 + 4 * eP.l[l,es,d,t]));

# 2.2 Marginal Cost Setup
# Defining marginal costs for each trace (goes from zero up to 4 standard deviations times the price of the most expensive technology)
pESmarg_scen.l[es,d,t,scen]$(sum(l, d1sqTPotential[l,es,d,t])) = ord(scen)/100 * d1Expensive_tech_smooth_scen[es,d,t];

# 2.3 Initial Capital Costs
# Random starting values for the marginal costs of capital
uTKmarg_scen.l[l,es,d,t,scen]$(sqTPotential.l[l,es,d,t]) = 1;
uTKmargNobound_scen.l[l,es,d,t,scen]$(sqTPotential.l[l,es,d,t]) = uTKmarg_scen.l[l,es,d,t,scen];

# ----------------------------------------------------------------------------------------------------------------------
# 3. Supply Curve Solution
# ----------------------------------------------------------------------------------------------------------------------
# 3.1 Pre-model Solution
$FIX G_abatement_supply_curve_exo;
$UNFIX G_abatement_supply_curve_endo;
@Setbounds_abatement();
# execute_unload 'pre_supply_curves.gdx';
Solve M_abatement_supply_curve using CNS;

# ----------------------------------------------------------------------------------------------------------------------
# 4. Main Model Initialization
# ----------------------------------------------------------------------------------------------------------------------
# 4.1 Equilibrium Values
# Determining uTKmarg and pESmarg in equilibrium
uTKmarg_eq[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = 
  sum(scen, uTKmarg_scen.l[l,es,d,t,scen]$(sqT_sum_scen.l[es,d,t,scen] >= 1 and sqT_sum_scen.l[es,d,t,scen-1] < 1));

pESmarg_eq[es,d,t] = smax(l, sum(e, uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t]) + uTKmarg_eq[l,es,d,t]*pTK.l[d,t]);

# 4.2 Starting Values, Marginal Capital Intensity
# Setting starting values for the main model
uTKmarg.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = uTKmarg_eq[l,es,d,t]; 

# For some reason, the model can't solve when given too good starting values for uTKmarg
uTKmarg.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t] * 1; 

# 4.3 Starting Values, Other Core Variables
uTKmargNobound.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t];
sqT.l[l,es,d,t]$(sqTPotential.l[l,es,d,t] and uTKmarg_eq[l,es,d,t]) = 
  sqTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_eq[l,es,d,t], uTKexp.l[l,es,d,t], eP.l[l,es,d,t]);
pESmarg.l[es,d,t] = pESmarg_eq[es,d,t];

execute_unload 'output\supply_curves_abatement.gdx';