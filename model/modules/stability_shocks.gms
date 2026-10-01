#SHOCK 1
  vArtificialExtraCost.l[i,t]$(t.val>t1.val) 
 = 0.05 * vY_i.l[i,t1];
$FIX all_variables; $UNFIX main_endogenous;
Solve main using CNS;
execute_unload '../Output/shock_artifical_extra_cost.gdx';

#SHOCK 2
# rHurdleRate_i.l[i,t]$(t.val>t1.val) 
#  = rHurdleRate_i.l[i,t] + 0.05;
# $FIX all_variables; $UNFIX main_endogenous;
# Solve main using CNS;
# execute_unload 'Output/shock_hurdle_rate.gdx';
