
set l "Technology name.";

$gdxIn ../data/data.gdx
$load l
$gdxIn


$onMulti

set l /
  set.l
  t_Electricity_calib "t_Electricity_calib"
  t_Electricity_calib_2 "t_Electricity_calib_2"
  /;

$OffMulti


alias(l,ll);

