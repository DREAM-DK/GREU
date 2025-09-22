# ------------------------------------------------------------------------------
# Calibrate decreasing capital costs for electrification technologies
# ------------------------------------------------------------------------------

# Define the electrification technologies
set electrification_techs[l] /
  't28'
  /;

# Technology potentials
sqTPotential.l[electrification_techs,es,d,t]$(sum(ll, sqTPotential.l[ll,es,d,t])) = sqTPotential.l['t26',es,d,t];

# Investment costs
vTI.l[electrification_techs,es,d,t]$(sum(ll, sqTPotential.l[ll,es,d,t])) = vTI.l['t26',es,d,t] + 0.05;

# Investment costs decrease by 1 pct. per year
# vTI.l[l,es,i,t]$(t.val > t1.val and t.val <= 2050 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
#   = vTI.l[l,es,i,t] * 0.995**(t.val - t1.val);

# Operating costs
vTC.l[electrification_techs,es,d,t]$(sum(ll, sqTPotential.l[ll,es,d,t])) = vTI.l[electrification_techs,es,d,t]/10;

# Operating costs decrease by 1 pct. per year
# vTC.l[l,es,i,t]$(t.val > t1.val and t.val <= 2050 and d1sqTPotential[l,es,i,t] and electrification_techs[l])
#   = vTC.l[l,es,i,t]  * 0.995**(t.val - t1.val);

# Energy input
uTE.l[electrification_techs,es,e,d,t]$(sum(ll, sqTPotential.l[ll,es,d,t])) = uTE.l['t26',es,e,d,t];

# Life span
LifeSpan[electrification_techs,es,d,t]$(sum(ll, sqTPotential.l[ll,es,d,t])) = 5;

# Set discount rate
DiscountRate[electrification_techs,es,d]$(sum((ll,t), sqTPotential.l[ll,es,d,t])) = 0.05;

# Set smoothing parameters
eP.l[electrification_techs,es,d,t]$(sum(ll, sqTPotential.l[ll,es,d,t])) = eP.l['t26',es,d,t];

# Set dummy determining the existence of technology potentials
d1sqTPotential[l,es,d,t] = yes$(sqTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));

# Supply Curve Visualization
$import Supply_curves_abatement.gms;

# # Solve partial abatement model
# $FIX all_variables;
# $UNFIX abatement_partial_endogenous;
# Solve abatement_partial_equations using CNS;
# execute_unload 'Output\calibration_electrification_abatement_partial.gdx';

# Solve model
# @add_exist_dummies_to_model(main);
$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
execute_unload 'Output\calibration_electrification.gdx';