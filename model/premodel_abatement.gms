# ======================================================================================================================
# Pre-model Setup for Abatement Module
# ======================================================================================================================
# This module generates supply curves and sets initial values for the abatement model.
# It creates scenario-specific versions of the model for supply curve analysis.

# ----------------------------------------------------------------------------------------------------------------------
# 1. Supply Curve Parameters
# ----------------------------------------------------------------------------------------------------------------------
# 1.1 Scenario Set Definition
set scen / 1*100 /; # Number of steps for tracing the supply curve

# 1.2 Key Parameters
parameter
  d1Expensive_tech_smooth_scen[es,d,t] "Most expensive technology"
  uTKmarg_eq[l,es,d,t]  "The marginal cost of capital in equilibrium, ie. at the point where demand is satisified"
  pESmarg_eq[es,d,t]    "The marginal cost of energy service in equilibrium, ie. at the point where demand is satisified"
;

# ----------------------------------------------------------------------------------------------------------------------
# 2. Scenario-Specific Model Setup
# ----------------------------------------------------------------------------------------------------------------------
# 2.1 Scenario Variable Creation
$GROUP G_scenarios
  $LOOP abatement_endogenous_core:
    {name}_scen{sets}{$}[+scen]${conditions} "Alternate version of {name} used in {scenario} scenario."
  $ENDLOOP
;

# 2.2 Dummy Variable Setup
# Adding exists-dummies for scenario specific variables
$LOOP G_scenarios:
  {name}_exists_dummy{sets} = {conditions};
$ENDLOOP

# 2.3 Initial Value Assignment
# Set starting value of scenario specific variables equal to their original counterparts
$LOOP abatement_endogenous_core:
  {name}_scen.l{sets}{$}[+scen]${conditions} = {name}.l{sets};
$ENDLOOP

# 2.4 Scenario Model Creation
$BLOCK B_scenarios
  # Substitute each variable in g_replace_scen by adding '_scen' to the name and adding ',scen' to the sets.
  $REGEX(('(?<=[\s\+\*\(\-\/])('+'|'.join(self.groups['abatement_endogenous_core'].keys())+')\[(.+?)\]'), '\g<1>_scen[\g<2>,scen]')  
    $LOOP abatement_equations_core:
        {name}_scen{sets}{$}[+scen]${conditions}.. {LHS} =E= {RHS};
    $ENDLOOP
  $ENDREGEX
$ENDBLOCK

# ----------------------------------------------------------------------------------------------------------------------
# 3. Supply Curve Model
# ----------------------------------------------------------------------------------------------------------------------
# 3.1 Supply Curve Variables
$Group+ all_variables
  sqT_sum_scen[es,d,t,scen]$(sum(l, d1sqTPotential[l,es,d,t]))  "Smoothed aggregate supply curve"
;

# 3.2 Supply Curve Equations
$BLOCK abatement_equations_supply_curve abatement_endogenous_supply_curve $(t1.val <= t.val and t.val <= tEnd.val)  
  .. sqT_sum_scen[es,d,t,scen] =E= sum(l$(d1sqTPotential[l,es,d,t]), sqT_scen[l,es,d,t,scen]);
$ENDBLOCK

# ----------------------------------------------------------------------------------------------------------------------
# 4. Model Assembly
# ----------------------------------------------------------------------------------------------------------------------
# 4.1 Model Definition
$MODEL M_abatement_supply_curve
  B_scenarios
  -E_pESmarg_es_d_scen
  abatement_equations_supply_curve
  ;
execute_unload 'premodel_abatement_1.gdx';
# 4.2 Dummy Variable Management
@add_exist_dummies_to_model(M_abatement_supply_curve) # Limit the main model to only include elements that are not dummied out
@update_exist_dummies()

execute_unload 'premodel_abatement_2.gdx';

# 4.3 Variable Classification
# 4.3.1 Endogenous Variables
$GROUP G_abatement_supply_curve_endo
  G_scenarios
  -pESmarg_scen
  abatement_endogenous_supply_curve;

# 4.3.2 Exogenous Variables
$GROUP G_abatement_supply_curve_exo
  all_variables
  G_scenarios
;
