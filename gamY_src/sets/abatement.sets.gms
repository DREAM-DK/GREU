
set l "Technology name.";

$gdxIn ../data/data.gdx
$load l
$gdxIn


$onMulti

set l /
  set.l
  t_Electricity_calib "t_Electricity_calib"
  /;

$OffMulti


alias(l,ll);

