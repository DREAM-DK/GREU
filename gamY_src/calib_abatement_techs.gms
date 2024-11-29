## ----------------------------------------------------------------------------------------
## Creating electrification technologies
## ----------------------------------------------------------------------------------------

$onMulti

set l /
  set.l
  t_Electricity_calib "t_Electricity_calib"
  /;

$OffMulti

theta.l['t_Electricity_calib',es,i,t]$(t.val>2018 and sum(l, d1theta[l,es,i,t])) = 0.5;
d1theta[l,es,i,t] = yes$(theta.l[l,es,i,t]);

uTE.l['t_Electricity_calib',es,'Electricity',i,t]$(t.val>2018 and sum(l, d1theta[l,es,i,t])) = 1;
uTK.l['t_Electricity_calib',es,i,t]$(t.val=2019 and sum(l, d1theta[l,es,i,t])) = 1;
# # uTK.l['t_Electricity_calib',es,i,t]$(t.val=2020 and sum(l, d1theta[l,es,i,t])) = 0.95;
# # uTK.l['t_Electricity_calib',es,i,t]$(t.val=2021 and sum(l, d1theta[l,es,i,t])) = 0.6;
# # uTK.l['t_Electricity_calib',es,i,t]$(t.val=2022 and sum(l, d1theta[l,es,i,t])) = 0.5;
# # uTK.l['t_Electricity_calib',es,i,t]$(t.val>=2023 and sum(l, d1theta[l,es,i,t])) = 0.4;

d1pK_abatement[i,t] = yes$(sum((l,es), d1theta[l,es,i,t]));
d1uTE[l,es,e,i,t] = yes$(uTE.l[l,es,e,i,t]);

svP.l[es,i,t]$(sum(l, d1theta[l,es,i,t])) = 1;

# $IMPORT exist_dummies.gms

# eP.l[l,es,i,t]$(d1theta[l,es,i,t]) = 0.5;

## ----------------------------------------------------------------------------------------
## Running the model
## ----------------------------------------------------------------------------------------

# $SETLOCAL calibration_year 2019;
# $SETLOCAL terminal_year 2023;

# set_time_periods(%calibration_year%, %terminal_year%);

# $FIX all_variables; $UNFIX calibration_endogenous;
# execute_unload 'calib_abatement_techs_pre.gdx';
# solve calibration using CNS;
# execute_unload 'static_calibration.gdx';


# eP.l[l,es,i,t]$(d1theta[l,es,i,t]) = 0.1;

# $IMPORT calibration.gms

# eP.l[l,es,i,t]$(d1theta[l,es,i,t]) = 0.05;

# $IMPORT calibration.gms

# theta.l['t_Electricity','in_ETS','10040',t]$(t.val>2018) = 1.05;
# uTE.l['t_Electricity','in_ETS','Electricity','10040',t]$(t.val>2018) = 1;
# uTK.l['t_Electricity','in_ETS','10040',t]$(t.val=2019) = 1;
# uTK.l['t_Electricity','in_ETS','10040',t]$(t.val=2020) = 0.95;
# uTK.l['t_Electricity','in_ETS','10040',t]$(t.val=2021) = 0.9;
# uTK.l['t_Electricity','in_ETS','10040',t]$(t.val=2022) = 0.85;
# uTK.l['t_Electricity','in_ETS','10040',t]$(t.val>=2023) = 0.8;

# execute_unloaddi "calib_abatement_techs.gdx";