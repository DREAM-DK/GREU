set energy_industries /
  energy
/;
set non_energy_private_industries /
  tradables
  non_tradables
/;
set public_industries /
  public
/;

set private_consumption_types "Consumption types" / 
  C "Consumption of goods and services"
/;
set government_consumption_types "Government consumption types" / 
  G "Government consumption"
/;
set investment_types "Investment types" /
  k "Equipment"
  b "Structures"
/;
set export_types "Export industries" /
  tradables_export
/;

set d "Demand components" /
  sets.energy_industries
  sets.non_energy_private_industries
  sets.public_industries
  sets.private_consumption_types
  sets.government_consumption_types
  sets.investment_types
  sets.export_types
/;

set i[d] "Production industries." /
  sets.energy_industries
  sets.non_energy_private_industries
  sets.public_industries
/;
set m[i] "industries with imports" /
  tradables
  energy
/;

alias(i, di, si); # di=demand industry, si=supply industry

set c[d] "Private consumption types" / sets.private_consumption_types /;
set g[d] "Government consumption types" / sets.government_consumption_types /;
set k[d] "Investment types" / sets.investment_types /;
set x[d] "Export industries" / sets.export_types /;

set e[i] "Energy industries" / sets.energy_industries /;
set r[i] "Non-energy industries" / sets.non_energy_private_industries, sets.public_industries /;

