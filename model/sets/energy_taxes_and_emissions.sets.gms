Set etaxes;
$gdxIn ../data/data.gdx
$load etaxes
$gdxin 
#sets etaxes 
#    / CO2_tax
#      EAFG_tax
#      SO2_tax
#      NOx_tax
#      PM_tax
#      VOC_tax
#      NH3_tax
#      BC_tax
#      OC_tax
#      CH4_tax
#      N2O_tax
#      F_gas_tax
#      HFCs_tax
#      PFCs_tax
#      SF6_tax
#      NF3_tax
#      CFCs_tax
#      HCFCs_tax
#      HFOs_tax
#      PSO_tax
#  /
sets 
  CO2_tax[etaxes]/CO2_tax/
  ;
      
set CO2etax "Categories of CO2e-taxation" /
    "energy_Corp"
    "energy_Hh"
    "non_energy"/
;

set energy_Corp[CO2etax] "Energy used in industries" /"energy_Corp"/;
set energy_Hh[CO2etax] "Household use of energy" /"energy_Hh"/;
set non_energy[CO2etax] "Non-energy use" /"non_energy"/;
set energy[CO2etax] "Energy use" /"energy_Corp", "energy_Hh"/;


set c_co2_tax[d]  "Consumer demand that is taxed with the CO2-tax" /cCarEne, cHouEne/;