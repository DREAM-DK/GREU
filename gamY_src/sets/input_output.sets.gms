
set i "Production industries."; alias(i,i_a);
set m[i] "Industries with imports.";

set d "Demand components.";
set k[d] "Capital types.";
set c[d] "Private consumption types.";
set g[d] "Government consumption types.";
set x[d] "Export types.";
set e[d] "Energy types";

$gdxIn ../data/data.gdx
$load i, d, k, c, g, x, m
$gdxIn
;

set r[d] "Intermediate input types." / set.i /;
