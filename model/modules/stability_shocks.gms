#this, dafuq
set_time_periods(%first_forecast_year%,%terminal_year%);

#Define group for warning-report
$GROUP G_warnings
main_endogenous;

Scalar Shock1_Level /0.10/;
Scalar Shock2_Level /0.03/;

#SHOCK 1
  vArtificialExtraCost.l[i,t]$(t.val>t1.val) 
 = Shock1_Level * vY_i.l[i,t1];
$FIX all_variables; $UNFIX main_endogenous;
Solve main using CNS;
execute_unload '../Output/shock_artifical_extra_cost.gdx';
#10 percent tolerance
@warn_if_changed_from_tDataEnd(G_warnings,10);


#Re-set all variables to their baseline values
execute_loadpoint '../Output/main_CGE.gdx';
#SHOCK 2
  rHurdleRate_i.l[i,t]$(t.val>t1.val) 
  = rHurdleRate_i.l[i,t] + Shock2_Level;
  $FIX all_variables; $UNFIX main_endogenous;
  Solve main using CNS;
  execute_unload '../Output/shock_hurdle_rate.gdx';


