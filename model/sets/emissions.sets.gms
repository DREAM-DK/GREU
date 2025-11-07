set em  "Emission-types"; alias(em,em_a);
set em_accounts "Different accounting levels of emissions inventories";
set land5 "Five aggregate land-use categories";

$gdxIn ../data/data.gdx
$load em
$load em_accounts
$load land5
$gdxIn

set CO2e[em]/CO2e/;
set CO2bio[em]/CO2bio/;
set CO2ubio[em]/CO2ubio/;

set gna[em_accounts]/GNA/
    gna_lulufc[em_accounts]/gna_lulucf/
    unfccc[em_accounts]/UNFCCC/
    unfccc_lulucf[em_accounts]/unfccc_lulucf/;


set CO2etax "Categories of CO2e-taxation" /
    "energy_Corp"
    "energy_Hh"
    "non_energy"/
;

set energy_Corp[CO2etax] "Energy used in industries" /"energy_Corp"/;
set energy_Hh[CO2etax] "Household use of energy" /"energy_Hh"/;
set non_energy[CO2etax] "Non-energy use" /"non_energy"/;
set energy[CO2etax] "Energy use" /"energy_Corp", "energy_Hh"/;

