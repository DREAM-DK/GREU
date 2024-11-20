

set out "All product types produced by industries, including energy and margins";
set ene[out] "Energy products produced by industries";
set pps "End-purpose of energy";



$gdxIn ../data/data.gdx
$load out, ene, pps
$gdxIn
#  execute_loaddc '..\data\data.gdx' out ene pps;
