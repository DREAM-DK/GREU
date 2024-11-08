

set out "All product types produced by industries, including energy and margins";
set ene[out] "Energy products produced by industries"; alias(ene,ene_a);
set pps "End-purpose of energy";

set prd/heating,transport,OtherEnergy/;

#  set mapPrd2PPs(prd,pps)/
#  	heating . heating 
#  	transport . transport 
#  	OtherEnergy . (process_normal,process_special, in_ETS)
#  	/;

$gdxIn ../data/data.gdx
$load out, ene, pps
$gdxIn
#  execute_loaddc '..\data\data.gdx' out ene pps;
