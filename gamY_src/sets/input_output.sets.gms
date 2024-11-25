Set d "Demand components.";
Set re[d<] "Energy types";
Set rx[d<] "Intermediate input types other than energy.";
Set k[d<] "Capital types.";
Set c[d<] "Private consumption types.";
Set g[d<] "Government consumption types.";
Set x[d<] "Export types.";
Singleton Set invt[d<] "Inventories" / invt /;
Singleton Set tl[d<] "Transmission losses" / tl /;

# Set i "Production industries."; alias(i,i_a);
Set i[d<] "Production industries."; alias(i,i_a);  # i should not be subset of d - use re or rx instead
Set m[i] "Industries with imports.";

$gdxIn ../data/data.gdx
$load i, m
$load rx=i, re, k, c, g, x
$gdxIn
;

Set i_refineries[i] / 19000 /;
Set i_gasdistribution[i] / 35002 /;
Set i_cardealers[i] / 45000 /;
Set i_wholesale[i] / 46000 /;
Set i_retail[i] / 47000 /;
Set i_service_for_industries[i] / 71000 /;
Set i_international_aviation[i] / 51009 /;