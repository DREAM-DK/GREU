set i "Production industries."; alias(i,i_a);
set m[i] "Industries with imports.";

set d "Demand components.";
set e[d<] "Energy types";
set r[d<] "Intermediate input types.";
set k[d<] "Capital types.";
set c[d<] "Private consumption types.";
set g[d<] "Government consumption types.";
set x[d<] "Export types.";

$gdxIn ../data/data.gdx
$load i, m
$load r=i, e, k, c, g, x
$gdxIn
;
