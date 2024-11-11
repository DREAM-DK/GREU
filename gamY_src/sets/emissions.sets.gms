set em  "Emission-types"; alias(em,em_a);
set em_accounts "Different accounting levels of emissions inventories";
set land5 "Five aggregate land-use categories";

$gdxIn ../data/data.gdx
$load em
$load em_accounts
$load land5
$gdxIn