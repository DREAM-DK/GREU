# ==============================================================================
# Module for generating supply curves and setting initial values
# ==============================================================================

# ------------------------------------------------------------------------------
# Defining sets and parameters for tracing the supply curve
# ------------------------------------------------------------------------------

# Choosing the number of steps when tracing the supply curve
set scen / 1*100 /;

parameter
  d1Expensive_tech_smooth_scen[es,d,t] "Most expensive technology"
  uTKmarg_eq[l,es,d,t]  "The marginal cost of capital in equilibrium, ie. at the point where demand is satisified"
  pESmarg_eq[es,d,t]    "The marginal cost of energy service in equilibrium, ie. at the point where demand is satisified"
;

# ------------------------------------------------------------------------------
# Copying the core model to a scenario specific version
# ------------------------------------------------------------------------------

## Create scenario specific versions of all endogenous variables
$GROUP G_scenarios
  $LOOP abatement_endogenous_core:
    {name}_scen{sets}{$}[+scen]${conditions} "Alternate version of {name} used in {scenario} scenario."
  $ENDLOOP
;
# Adding exists-dummies for scenario specific variables
$LOOP G_scenarios:
  {name}_exists_dummy{sets} = {conditions};
$ENDLOOP

# Set starting value of scenario specific variables equal to their original counterparts
$LOOP abatement_endogenous_core:
  {name}_scen.l{sets}{$}[+scen]${conditions} = {name}.l{sets};
$ENDLOOP

# Create scenario specific versions of entire model, with all endogenous variables replaced by scenario specific counterparts
$BLOCK B_scenarios
  # Substitute each variable in g_replace_scen by adding '_scen' to the name and adding ',scen' to the sets.
  $REGEX(('(?<=[\s\+\*\(\-\/])('+'|'.join(self.groups['abatement_endogenous_core'].keys())+')\[(.+?)\]'), '\g<1>_scen[\g<2>,scen]')  
    $LOOP abatement_equations_core:
        {name}_scen{sets}{$}[+scen]${conditions}.. {LHS} =E= {RHS};
    $ENDLOOP
  $ENDREGEX
$ENDBLOCK

# ------------------------------------------------------------------------------
# Creating new equations and variables for the supply curve
# ------------------------------------------------------------------------------

# Creating a variable to determine supply of energy service relative to demand (aggregated across all technologies)
$Group+ all_variables
  sqT2qES_sum_scen[es,d,t,scen]$(sum(l, d1sTPotential[l,es,d,t]))  "Smoothed aggregate supply curve"
;

$BLOCK abatement_equations_supply_curve abatement_endogenous_supply_curve $(t1.val <= t.val and t.val <= tEnd.val)  
  .. sqT2qES_sum_scen[es,d,t,scen] =E= sum(l$(d1sTPotential[l,es,d,t]), sqT2qES_scen[l,es,d,t,scen]);
$ENDBLOCK

# ------------------------------------------------------------------------------
# Creating and solving the model for supply curve calculation
# ------------------------------------------------------------------------------

# Setting up the model
$MODEL M_abatement_supply_curve
  B_scenarios
  -E_pESmarg_es_d_scen
  abatement_equations_supply_curve
  ;

# Generating exist-dummies for the model
@add_exist_dummies_to_model(M_abatement_supply_curve) # Limit the main model to only include elements that are not dummied out
@update_exist_dummies()

# Defining endogenous variables
$GROUP G_abatement_supply_curve_endo
  G_scenarios
  -pESmarg_scen
  abatement_endogenous_supply_curve;

# Defining exogenous variables
$GROUP G_abatement_supply_curve_exo
  all_variables
  G_scenarios
;
