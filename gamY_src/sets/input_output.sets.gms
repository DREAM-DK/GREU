
set i "Production industries."; alias(i,i_a);
set m[i] "Industries with imports.";

set d "Demand components.";
set k "Capital types.";
set c "Private consumption types.";
set g "Government consumption types.";
set x "Export types.";
set di "Intermediate input types.";

$gdxIn ../data/data.gdx
$load i
$load k
$gdxIn