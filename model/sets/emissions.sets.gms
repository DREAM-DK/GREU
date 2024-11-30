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
    unfccc[em_accounts]/UNFCCC/;