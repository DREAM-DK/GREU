Set d "Demand components.";
# Set re[d<] "Energy types" /energy/;
Set re[d<] "Intermediate energy-input";
Set rx[d<] "Intermediate input types other than energy.";
Set k[d<] "Capital types.";
Set c[d<] "Private consumption types.";
Set g[d<] "Government consumption types.";
Set x[d<] "Export types.";
Set invt[d<] "Inventories" / invt /;
Set tl[d<] "Transmission losses" / tl /;

# Set i "Production industries."; alias(i,i_a);
Set i[d<] "Production industries."; alias(i,i_a);  # i should not be subset of d - use re or rx instead
Set m[i] "Industries with imports.";

Set rx2re(rx,re);
Set i2re(i,re);
Set i2rx(i,rx);

$gdxIn ../data/data.gdx
$load i, m
$load rx=i, k, c, g, x
$load re, rx2re
$gdxIn
;

i2rx(i,rx) = yes$(sameas[i,rx]);
i2re(i,re) = yes$(sum(rx$rx2re(rx,re), i2rx(i,rx)));

# set energy[d]/energy/;

Set i_public[i] "Public industries." / off /;
Set i_private[i] "Private industries." / set.i - off /;

Set i_refineries[i] / 19000 /;
Set i_gasdistribution[i] / 35002 /;
Set i_cardealers[i] / 45000 /;
Set i_wholesale[i] / 46000 /;
Set i_retail[i] / 47000 /;
Set i_service_for_industries[i] / 71000 /;
Set i_international_aviation[i] / 51009 /;