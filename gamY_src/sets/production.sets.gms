
set factors_of_production /
  "labor"
  RxE #Non-ergy input
  set.k, # Types of capital
  machine_energy
  transport_energy
  heating_energy

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

set machine_energy[pf]/machine_energy/;
set transport_energy[pf]/transport_energy/;
set heating_energy[pf]/heating_energy/;

set pf_bottom[pf] / set.factors_of_production /;
set pfNest[pf] / set.production_nests /;
set pf_top[pf]/ TopPfunction/;

set pf_bottom_e[pf]/  machine_energy
                        transport_energy
                        heating_energy
                      /;

set pf_bottom_capital[pf]/set.k/;

set pf_bottom_note[pf];
pf_bottom_note[pf] = not pf_bottom_e[pf];


# @define_set_complement(i_standard,i,['35002','19000'],'fromlist');
 set i_standard[i]/set.i/;
#  i_standard[i] = not (sameas[i,'35002'] or sameas[i,'19000']);

set pf_mapping[pfNest,pf,i] /
  #Standard sectors
  KE . (im, machine_energy)      . set.i_standard
  TE . (it, transport_energy)    . set.i_standard
  BE . (ib, heating_energy)      . set.i_standard

  KETE     . (KE      , TE)      . set.i_standard
  KETEL    . (KETE    , labor)   . set.i_standard
  KETELBE  . (KETEL   , BE)      . set.i_standard
  TopPfunction . (KETELBE , RxE) . set.i_standard

/;
