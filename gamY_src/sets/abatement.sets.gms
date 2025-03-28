
set l "Technology name.";
set es "Energy service";
set e "Energy input";
set i "Industry";
set d "Demand component";

$gdxIn ../data/Abatement_data/Abatement_dummy_data.gdx
$load l, es, e, i 
$gdxIn

set d /
  set.i
  /;

alias(l,ll);

