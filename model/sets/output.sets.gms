set out "All product types produced by industries, including ergy and margins";
set e[out] "ergy products produced by industries"; alias(e,e_a);
set es "End-purpose of ergy";
set eBunkering[e] "Bunkering energy types";

set prd/heating,transport,Otherergy/;

$gdxIn %path_data%
$load out, e, es, eBunkering
$gdxIn

#  execute_loaddc '..\data\data.gdx' out e es;

sets out_other[out]/out_other/
     natgas[out]/"Natural gas"/
#     natgas_ext[out] /"Natural gas (Extraction)"/
     el[out]/"Electrical energy"/
#     distheat[out]/"Heat"/
#     straw[out]/"Straw for energy purposes"/
     biogas[out]/"Biogas"/
     crudeoil[out]/"Crude oil, NGL, and other hydrocarbons"/
     ;

sets transport[es]/Transport/
     heating[es]/Heating/
     process_normal[es]/Process_normal/
     process_special[es]/Process_special/
     in_ETS[es]/In_ETS/
     ;


# set es2re(es,re)
#      /
#        heating . heating_energy
#        transport . transport_energy
#        (process_normal,process_special,in_ETS) . machine_energy 
#        /;

#£Temp until IO-split       
set es2re(es,re)
     /
       heating . energy
       transport . energy
       (process_normal,process_special,in_ETS) . energy 
       /;

set es_d2d(es,d_a,d)/
     (heating,appliances) . HH_heating . HH_heating
     transport . HH_transport . HH_transport
     set.es . set.i . energy
     set.es . xEne . xEne 
     set.es . invt_ene . invt_ene
     /;


# set d2i_own(e,d,i)/
#      'natural gas (extraction)' . d . 0600a 
#      /;