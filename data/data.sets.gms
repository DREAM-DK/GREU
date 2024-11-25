$onMulti

set t "Time periods." / 1980*2099/;
singleton set t1[t] /2019/;
set out "All product types produced by industries, including ergy and margins";
set e[out] "ergy products produced by industries";
set es "Energy-service";
set em_load "Emissiontype" ;
set em_accounts "Different accounting levels of emissions inventories";
set land5 "Five aggregate land-use categories";

set a_rows_ "Other rows of the input-output table.";

set d "Demand components.";
set re[d<] "Energy types";
set rx[d<] "Intermediate input types.";
set k[d<] "Capital types.";
set c[d<] "Private consumption types.";
set g[d<] "Government consumption types.";
set x[d<] "Export types." / xOth /;
Singleton Set invt[d<] "Inventories" / invt /;
Singleton Set tl[d<] "Transmission losses" / tl /;

set i[d<] "Production industries."; alias(i,i_a);
set m[i] "Industries with imports.";

$gdxIn %data_path%
$load a_rows_
$gdxIn

$gdxIn %data_path%
$load rx=s, re=energy19, k, c, g
$load i=s
$load em_load = emm_eq
$gdxIn

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

set demand_transaction[transaction] / 
  "input_in_production"
  "household_consumption"
  "export"
  "inventory"
  "transmission_losses"
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