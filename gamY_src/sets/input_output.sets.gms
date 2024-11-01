
set i "Production industries.";
set m[i] "Industries with imports.";

set d "Demand components.";
set k[d] "Capital types.";
set c[d] "Private consumption types.";
set g[d] "Government consumption types.";
set x[d] "Export types.";
set di[d] "Intermediate input types.";

$gdxIn ../data/data.gdx
$load i
$gdxIn