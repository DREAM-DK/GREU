Set d "Demand components.";
Set d_non_ene[d<];
Set d_ene[d<];
Set re[d<] "Intermediate energy-input";
Set rx[d<] "Intermediate input types other than energy.";
Set energy[d<] "Energy.";
Set k[d<] "Capital types.";
Set c[d<] "Private consumption types.";
Set g[d<] "Government consumption types.";
Set x[d<] "Export types.";
Set invt[d<] "Inventories"; #/ invt /;
Set invt_ene[d<] "Energy inventories"

# Set i "Production industries."; alias(i,i_a);
Set i[d<] "Production industries."; # i should not be subset of d - use re or rx instead
Set m[i] "Industries with imports.";
Set i_public[i] "Public industries.";
Set i_private[i] "Private industries.";
Set i_private_fin[i] "Private financial industry.";
Set i_private_nonfin[i] "Private non-financial industries.";

$gdxIn ../data/data.gdx
$load d, d_non_ene, d_ene
$load i, m, i_public, i_private, i_private_fin, i_private_nonfin
$load rx, re, energy, k, c, g, x, invt, invt_ene
$gdxIn
;
