
set l "Technology name.";
set l_load "Technology name.";

$gdxIn ../data/data.gdx
$load l_load = l
$gdxIn


set l /
  set.l_load
  t_Electricity_calib "t_Electricity_calib"
  t_Electricity_calib_2 "t_Electricity_calib_2"
  /;


alias(l,ll);

