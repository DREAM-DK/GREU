set t "Time periods." / 1980*2099/;
set out "All product types produced by industries, including ergy and margins";
set e[out] "ergy products produced by industries";
set es "Energy-service";
set em_load "Emissiontype" ;
set em_accounts "Different accounting levels of emissions inventories";
set land5 "Five aggregate land-use categories";

set i_load "Production industries.";
set k_load "Capital types.";
set c_load "Private consumption types.";
set g_load "Government consumption types.";
set x_load "Export types.";

$gdxIn P:\akg\Til_EU_projekt\EU_GR_data.gdx
$load i_load = s
$load k_load = k 
$load c_load = c 
$load g_load = g 
$load x_load = x
$load em_load = emm_eq
$gdxIn

set d "Demand components."/
  set.i_load 
  set.k_load 
  set.c_load 
  set.g_load 
  set.x_load
  invt 
  tl 
  /;
  
set di[d] "Intermediate input types."
  /set.i_load/
  ;

set i[d] "Industries producing demand components."
  /set.i_load/
  ;

set i "Production industries."; alias(i,i_a);
set m[i] "Industries with imports.";

set k[d] "Capital types."
  /set.k_load/
  ;

set invt[d] "Invetories"
  /
  invt 
  /
;

set tl[d] "Transmission losses"
  /
  tl 
  /;

set c[d] "Consumption categories."
  /set.c_load/
  ;

set g[d] "Public consumption categories"
  /set.g_load/
  ;

set x[d] "Export types."
  /set.x_load/
  ;


set ebalitems
     /
      BASE
      PJ 


      #Margins
      EAV 
      DAV 
      CAV 

      #Taxes
      CO2_tax
      EAFG_tax
      SO2_tax
      NOx_tax
      PM_tax
      VOC_tax
      NH3_tax
      BC_tax
      OC_tax
      CH4_tax
      N2O_tax
      F_gas_tax
      HFCs_tax
      PFCs_tax
      SF6_tax
      NF3_tax
      CFCs_tax
      HCFCs_tax
      HFOs_tax
      PSO_tax
      VAT
      
      #Emissions
      set.em_load

/;

set em[ebalitems] "Emission types" /set.em_load/;

set transaction / 
  "production"
  "imports"
  "input_in_production"
  "export"
  "inventory"
  "transmission_losses"
  "household_consumption"
  /;

set etaxes[ebalitems] 
    / CO2_tax
      EAFG_tax
      SO2_tax
      NOx_tax
      PM_tax
      VOC_tax
      NH3_tax
      BC_tax
      OC_tax
      CH4_tax
      N2O_tax
      F_gas_tax
      HFCs_tax
      PFCs_tax
      SF6_tax
      NF3_tax
      CFCs_tax
      HCFCs_tax
      HFOs_tax
      PSO_tax
  /;


set factors_of_production /
  "labor"
  RxE #Non-ergy input
  set.k, # Types of capital
  machine_energy
  transport_energy
  heating_energy

  refinery_crudeoil
  naturalgas_for_distribution
  biogas_for_processing
/;