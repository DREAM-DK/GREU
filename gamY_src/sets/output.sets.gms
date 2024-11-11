

set out "All product types produced by industries, including ergy and margins";
set e[out] "ergy products produced by industries"; alias(e,e_a);
set es "End-purpose of ergy";

set prd/heating,transport,Otherergy/;

#  set mapPrd2es(prd,es)/
#  	heating . heating 
#  	transport . transport 
#  	Otherergy . (process_normal,process_special, in_ETS)
#  	/;

$gdxIn ../data/data.gdx
$load out, e, es
$gdxIn
#  execute_loaddc '..\data\data.gdx' out e es;
