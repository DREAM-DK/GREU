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
sets natgas[out]     /"Natural gas incl. biongas"/
     natgas_ext[out] /"Natural gas (Extraction)"/
     el[out]/"Electricity"/
     distheat[out]/"District heat"/
     straw[out]/"Straw for energy purposes"/
     biogas[out]/"Biogas"/
     crudeoil[out]/"Crude oil"/
     EnergyDistmargin[out]/"WholeAndRetailSaleMarginE"/
     ;

sets transport[es]/Transport/
     heating[es]/Heating/
     process_normal[es]/Process_normal/
     process_special[es]/Process_special/
     in_ETS[es]/In_ETS/
     ;
     