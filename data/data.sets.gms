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
# set re[d<] "Energy intermediate input types" /energy/;
set re[d<] "Energy intermediate input types"
  /01011_re	"Planteproduktion, konventionel"
   01012_re	"Planteproduktion, Ã¸kologisk"
   01020_re	"Gartneri"
   01031_re	"MalkekvÃ¦g, konventionelt"
   01032_re	"MalkekvÃ¦g Ã¸kologisk"
   01051_re	"Svinebrug, konventionelt"
   01052_re	"Svinebrug, Ã¸kologisk"
   01061_re	"FjerkrÃ¦, konventionelt"
   01062_re	"FjerkrÃ¦, Ã¸kologisk"
   01070_re	"Pelsdyr"
   01080_re	"Maskinstationer"
   02000_re	"Skovbrug"
   03000_re	"Fiskeri"
   0600a_re	"Indvinding af olie og gas"
   10020_re	"Fiskeindustri"
   10030_re	"Mejerier"
   10040_re	"Bagerier, brÃ¸dfabrikker mv."
   10120_re	"Anden fÃ¸devareindustri"
   13150_re	"Maskin- og elektronikindustri"
   16000_re	"TrÃ¦industri"
   19000_re	"Olieraffinaderier mv."
   20000_re	"Fremst. af kemikalier, maling, sÃ¦be mv."
   21000_re	"Medicinalindustri"
   25000_re	"Anden fremstillingsvirksomhed"
   35011_re	"El- og varmeproduktion, samt transmission og transmission af el"
   35002_re	"Gasforsyning"
   36000_re	"Vandforsyning"
   37000_re	"Kloak- og rensningsanlÃ¦g"
   38391_re	"Indsamling af affald"
   38392_re	"Behandling og bortskaffelse"
   38393_re	"ForbrÃ¦nding af affald"
   41430_re	"Byggebranchen"
   45000_re	"Engros- og detailsalg af biler, samt reparation af motorkÃ¸retÃ¸jer"
   46000_re	"Engroshandel"
   47000_re	"Detailhandel"
   49011_re	"Passagertransport med regional- eller fjerntog, godstransport med tog, S-togstrafik, lokaltog og metro"
   49024_re	"BuskÃ¸rsel, nÃ¦r og fjern, samt taxikÃ¸rsel"
   49031_re	"Vejgods-transport, flytteforret-ninger og rÃ¸rtransport"
   50001_re	"Passagertransport (sÃ¸-, kyst- og transport ad indre vandveje)"
   51001_re	"Passagertransport med fly"
   51009_re	"Passager- og godstransport med fly i udlandet"
   55560_re	"Service overvejende til privat forbrug"
   64000_re	"Finansiel sektor"
   68203_re	"Boligbranchen, samt husholdningernes boligbehold."
   71000_re	"Service overvejende til virksomheder og eksport"
   53000_re	"Supportaktiviteter til transportbranchen og Post- og kurertjenester"
   10011_re	"KvÃ¦gslagterier"
   10012_re	"Svineslagterier"
   10013_re	"FjerkrÃ¦slagterier"
   23001_re	"Cementproduktion"
   23002_re	"Oevrig mineralogisk vsh."
   49509_re	"International transport ad vand- og landveje"
   off_re	"Offentlig sektor"
   /
  ;
set rx[d<] "Non-energy intermediate input types.";
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
$load rx=s, k, c, g
$load i=s
$load em_load = emm_eq
$gdxIn


set rx2re(rx,re)/
  01011 . 01011_re
  01012 . 01012_re
  01020 . 01020_re
  01031 . 01031_re
  01032 . 01032_re
  01051 . 01051_re
  01052 . 01052_re
  01061 . 01061_re
  01062 . 01062_re
  01070 . 01070_re
  01080 . 01080_re
  02000 . 02000_re
  03000 . 03000_re
  0600a . 0600a_re
  10020 . 10020_re
  10030 . 10030_re
  10040 . 10040_re
  10120 . 10120_re
  13150 . 13150_re
  16000 . 16000_re
  19000 . 19000_re
  20000 . 20000_re
  21000 . 21000_re
  25000 . 25000_re
  35011 . 35011_re
  35002 . 35002_re
  36000 . 36000_re
  37000 . 37000_re
  38391 . 38391_re
  38392 . 38392_re
  38393 . 38393_re
  41430 . 41430_re
  45000 . 45000_re
  46000 . 46000_re
  47000 . 47000_re
  49011 . 49011_re
  49024 . 49024_re
  49031 . 49031_re
  50001 . 50001_re
  51001 . 51001_re
  51009 . 51009_re
  55560 . 55560_re
  64000 . 64000_re
  68203 . 68203_re
  71000 . 71000_re
  53000 . 53000_re
  10011 . 10011_re
  10012 . 10012_re
  10013 . 10013_re
  23001 . 23001_re
  23002 . 23002_re
  49509 . 49509_re
  off . off_re
  /
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


