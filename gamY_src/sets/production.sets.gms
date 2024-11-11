
set factors_of_production /
  "labor"
  RxE #Non-ergy input
  set.k, # Types of capital
  machine_ergy
  transport_ergy
  heating_ergy

  refinery_crudeoil
  naturalgas_for_distribution
  biogas_for_processing
/;


set production_nests /
  KE "machine capial and ergy for machine"
  TE "Transport capital and ergy for transport"
  BE "Structures capital and heating ergy"
  KETE "Nest of KE and TE"
  KETEL    
  KETELBE  
  # KETELBER 
  TopPfunction "The top nest of production function, currently KETELBER"
/;

set pf "Factor inputs and their nests in production function" /
  set.factors_of_production
  set.production_nests
/;

set pf_bottom[pf] / set.factors_of_production /;
set pfNest[pf] / set.production_nests /;
set pf_top[pf]/ TopPfunction/;

set pf_bottom_e[pf]/  machine_ergy
                        transport_ergy
                        heating_ergy

                        refinery_crudeoil
                        naturalgas_for_distribution
                        biogas_for_processing
                      /;

set pf_bottom_capital[pf]/set.k/;

set pf_bottom_note[pf];
pf_bottom_note[pf] = not pf_bottom_e[pf];


@define_set_complement(i_standard,i,['35002','19000'],'fromlist');
#  set i_standard[i]/set.i/;
#  i_standard[i] = not (sameas[i,'35002'] or sameas[i,'19000']);

set pf_mapping[pfNest,pf,i] /
  #Standard sectors
  KE . (im, machine_ergy) . set.i_standard
  TE . (it, transport_ergy) . set.i_standard
  BE . (ib, heating_ergy) . set.i_standard

  KETE     . (KE      , TE) . set.i_standard
  KETEL    . (KETE    , labor) . set.i_standard
  KETELBE  . (KETEL   , BE) . set.i_standard
  TopPfunction . (KETELBE , RxE) . set.i_standard

  #35002
  KE . (im, machine_ergy) . 35002
  TE . (it, transport_ergy) . 35002
  BE . (ib, heating_ergy) . 35002

  KETE . (KE , TE) . 35002
  KETEL . (KETE , labor) . 35002
  KETELBE . (KETEL , BE) . 35002
  TopPfunction . (KETELBE , RxE , naturalgas_for_distribution, biogas_for_processing) . 35002


  #19000
  KE . (im, machine_ergy) . 19000
  TE . (it, transport_ergy) . 19000
  BE . (ib, heating_ergy) . 19000

  KETE . (KE , TE) . 19000
  KETEL . (KETE , labor) . 19000
  KETELBE . (KETEL , BE) . 19000
  TopPfunction . (KETELBE , RxE , refinery_crudeoil) . 19000

/;

# parameter test_pf_mapping[pf,i];
# test_pf_mapping[pf,i] = 1$sum(pfNest, pf_mapping[pfNest,pf,i]);  
# execute_unload 'test_pf_mapping.gdx', test_pf_mapping;
# LOOP((pf,i), 
#   ABORT$(test_pf_mapping[pf,i] <> 1)  'Not all factors and nests are mapped in pf_mapping. Revisit pf_mapping for errors';
# );

	# LOOP((sCRF,categoryENS,GSR_ag,purpose,s)$(sCRF_2_sENS2GR_e(sCRF,categoryENS,GSR_ag,purpose,s)),
	# 	tjek = 1-1$sCRF_2_sENS2GR_e(sCRF,categoryENS,GSR_ag,purpose,s);
	# 	ABORT$(tjek <> 0) tjek, "Et element i sCRF_2_sENS2GR_e bliver mappet to steder hen. Ret i mappingen";
	# 	);

# set pf_mapping_readdata[pfNest,pf,i];
#   pf_mapping_readdata[pfNest,pf,i] = 

#  set pf_ergy2(pf_bottom_e,es)
#    machine_ergy . 

#Right-side of the separate nests to enable writign CES-shares as 1-sum(OtherShares)
#  set pf_right[pf]/
#    machine_ergy
#    transport_ergy
#    heating_ergy

