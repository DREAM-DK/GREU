
set factors_of_production;
$gdxin ../data/data.gdx
$load factors_of_production
$gdxin

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

set machine_energy[pf] /machine_energy/;
set transport_energy[pf] /transport_energy/;
set heating_energy[pf] /heating_energy/;

set labor[pf] /labor/;

set RxE[pf] /RxE/;

set pf_bottom[pf] /set.factors_of_production/;
set pfNest[pf] /set.production_nests/;
set pf_top[pf] /TopPfunction/;

set pf_bottom_e[pf]/
  machine_energy
  transport_energy
  heating_energy
/;

set pf_bottom_capital[pf] /set.k/;

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

# set pf_bottom_e2re[pf_bottom_e,re]/
#     machine_energy  .  machine_energy
#     transport_energy .   transport_energy
#     heating_energy .   heating_energy
# /;

#£Temp
set pf_bottom_e2re[pf_bottom_e,re]/
    machine_energy   .  heating_energy
    transport_energy .   heating_energy
    heating_energy .   heating_energy
/;