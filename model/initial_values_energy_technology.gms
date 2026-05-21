# ======================================================================================================================
# Supply Curves for Energy Technology Choice Model
# ======================================================================================================================
# This module solves a pre-model in order to calculate supply curves for the main energy technology choice model.

# ----------------------------------------------------------------------------------------------------------------------
# 1. Update energy dummies and prices
# ----------------------------------------------------------------------------------------------------------------------

$FIX all_variables; $UNFIX energy_price_partial_endogenous;
# execute_unload 'energy_price_partial_pre.gdx';
Solve energy_price_partial using CNS;
# execute_unload 'energy_price_partial_post.gdx';

# ----------------------------------------------------------------------------------------------------------------------
# 2. Price Initialization
# ----------------------------------------------------------------------------------------------------------------------
# 2.1 Starting values for Levelized Cost of Energy (LCOE)
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

# 2.2 Technology Prices
# Technology price for plotting the discrete supply curve
pTPotential.l[l,es,d,t] = 
  sum(e$(d1pEpj[es,e,d,t] and d1uTE[l,es,e,d,t]), 
    uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t])
  + uTKexp.l[l,es,d,t]*pTK.l[d,t];

# ----------------------------------------------------------------------------------------------------------------------
# 3. Supply Curve Initialization
# ----------------------------------------------------------------------------------------------------------------------
# 3.1 Technology Range Determination
# Determining the price of the marginal technology
# Rank technologies by price at full potential (per es,d,t); break ties with ord(l)
pTPotential_position[l,es,d,t]$(d1sqTPotential[l,es,d,t]) 
  = sum(ll$(d1sqTPotential[ll,es,d,t] and pTPotential.l(ll,es,d,t) < pTPotential.l(l,es,d,t)), 1)
  + sum(ll$(d1sqTPotential[ll,es,d,t]
      and pTPotential.l(ll,es,d,t) = pTPotential.l(l,es,d,t) and ord(ll) < ord(l)), 1)
  + 1;

# Sort technologies by price at full potential
pTPotential_sorted[l_ord,es,d,t]
  = sum(l$(pTpotential_position[l,es,d,t] = ord(l_ord)), pTPotential.l[l,es,d,t]);
sqTPotential_sorted[l_ord,es,d,t]
  = sum(l$(pTpotential_position[l,es,d,t] = ord(l_ord)), sqTPotential.l[l,es,d,t]);
sqTPotential_sorted_sum[l_ord,es,d,t]
  = sum(ll_ord$(ord(ll_ord) <= ord(l_ord)), sqTPotential_sorted[ll_ord,es,d,t]);
pTPotential_marginal[es,d,t]
  = sum(l_ord$(sqTPotential_sorted_sum[l_ord,es,d,t] >= 1 and sqTPotential_sorted_sum[l_ord-1,es,d,t] < 1), 
      pTPotential_sorted[l_ord,es,d,t]);

# 3.2 Marginal Cost Setup
# Defining marginal costs for each trace (100 steps in the interval +- 4 standard deviations from the marginal technology in the discrete case)
pESmarg_scen.l[es,d,t,scen]$(sum(l, d1sqTPotential[l,es,d,t])) 
  = pTPotential_marginal[es,d,t] 
  * ((1 - 3 * smooth_factor)
  +  6 * smooth_factor*ord(scen)/100);

# 3.3 Initial Capital Costs
# Random starting values for the marginal costs of capital
uTKmarg_scen.l[l,es,d,t,scen]$(sqTPotential.l[l,es,d,t]) = 1;
uTKmargNobound_scen.l[l,es,d,t,scen]$(sqTPotential.l[l,es,d,t]) = uTKmarg_scen.l[l,es,d,t,scen];

# ----------------------------------------------------------------------------------------------------------------------
# 4. Supply Curve Solution
# ----------------------------------------------------------------------------------------------------------------------
@update_exist_dummies()
$FIX G_energy_technology_supply_curve_exo;
$UNFIX G_energy_technology_supply_curve_endo;
@Setbounds_energy_technology();
Solve M_energy_technology_supply_curve using CNS;

# ----------------------------------------------------------------------------------------------------------------------
# 5. Main Model Initialization
# ----------------------------------------------------------------------------------------------------------------------
# 5.1 Equilibrium Values
# Determining uTKmarg, uTKmargNobound and pESmarg in equilibrium
uTKmarg_eq[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = 
  sum(scen$(sqT_sum_scen.l[es,d,t,scen] >= 1 and sqT_sum_scen.l[es,d,t,scen-1] < 1), 
    uTKmarg_scen.l[l,es,d,t,scen]);

uTKmargNobound.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = 
  sum(scen$(sqT_sum_scen.l[es,d,t,scen] >= 1 and sqT_sum_scen.l[es,d,t,scen-1] < 1), 
    uTKmargNobound_scen.l[l,es,d,t,scen]);

pESmarg_eq[es,d,t] = smax(l, sum(e, uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t]) + uTKmarg_eq[l,es,d,t]*pTK.l[d,t]);

# 5.2 Starting Values, Marginal Capital Intensity
# Setting starting values for the main model
uTKmarg.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = uTKmarg_eq[l,es,d,t]; 

# For some reason, the model can't solve when given too good starting values for uTKmarg
uTKmarg.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = uTKmarg.l[l,es,d,t] * 1; 

# 5.3 Starting Values, Other Core Variables
sqT.l[l,es,d,t]$(sqTPotential.l[l,es,d,t] and uTKmarg_eq[l,es,d,t]) = 
  sqTPotential.l[l,es,d,t]*@cdfLogNorm(uTKmarg_eq[l,es,d,t], uTKexp.l[l,es,d,t], eP.l[l,es,d,t]);
pESmarg.l[es,d,t] = pESmarg_eq[es,d,t];
