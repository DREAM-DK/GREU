Set d "Demand components.";
Alias(d,d_a);
Set d_non_ene[d<];
Alias(d_non_ene,d_non_ene_a);
Set d_ene[d<];
Alias(d_ene,d_ene_a);
# Set re[d<] "Energy types" /energy/;
Set re[d<] "Intermediate energy-input";
Set rx[d<] "Intermediate input types other than energy.";
Set k[d<] "Capital types.";
Set c[d<] "Private consumption types.";
Set g[d<] "Government consumption types.";
Set x[d<] "Export types.";
Set invt[d<] "Inventories"; #/ invt /;
Set invt_ene[d<] "Energy inventories"
Set tl[d<] "Transmission losses"; #/ tl /;

# Set i "Production industries."; alias(i,i_a);
Set i[d<] "Production industries."; alias(i,i_a);  # i should not be subset of d - use re or rx instead
Set m[i] "Industries with imports.";

Set i2rx(i,rx);
Set d_non_ene2i(d,i);
Set d_non_ene2k(d,k);

$gdxIn %path_data%
$load d, d_non_ene, d_ene
$load i, m
$load rx=i, re, k, c, g, x,tl,invt, invt_ene
$gdxIn
;


i2rx(i,rx) = yes$(sameas[i,rx]);
d_non_ene2i(d_non_ene,i) = yes$(sameas[d_non_ene,i]);
d_non_ene2k(d_non_ene,k) = yes$(sameas[d_non_ene,k]);

# set energy[d]/energy/;

Set xEne[d]/xEne/;

Set i_public[i] "Public industries." / off /;
Set i_private[i] "Private industries.";
i_private[i] = not i_public[i];

Set i_refineries[i] / C19 /;
Set i_gasdistribution[i] / 35B /;
Set i_cardealers[i] / G45 /;
Set i_wholesale[i] / G46 /;
Set i_retail[i] / G47 /;
Set i_energymargins[i]/G45,G46,G47/;

Set i_service_for_industries[i] / serv_to_business /;
Set i_international_aviation[i] / H51 /;
SEt i_control[i]/set.i/;