
set a       "Age - year in which an agent turns x years old." /0*111/;
singleton set aEnd[a] "Oldest age cohort modeled (terminal age)." /110/;
set a0_[a] "Ages 0 to 110." /0*110/;
set a18_[a] "Ages 18 to 110." /18*110/;

set energy_sectors /
  energy
/;
set non_energy_private_sectors /
  tradables
  non_tradables
/;
set public_sectors /
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
set export_types "Export sectors" /
  tradables_export
/;

set d "Demand components" /
  sets.energy_sectors
  sets.non_energy_private_sectors
  sets.public_sectors
  sets.private_consumption_types
  sets.government_consumption_types
  sets.investment_types
  sets.export_types
/;

set s[d] "Production sectors." /
  sets.energy_sectors
  sets.non_energy_private_sectors
  sets.public_sectors
/;
set m[s] "Sectors with imports" /
  tradables
  energy
/;

alias(s, ds, ss); # ds=demand sector, ss=supply sector

set c[d] "Private consumption types" / sets.private_consumption_types /;
set g[d] "Government consumption types" / sets.government_consumption_types /;
set i[d] "Investment types" / sets.investment_types /;
set x[d] "Export sectors" / sets.export_types /;

set e[s] "Energy sectors" / sets.energy_sectors /;
set r[s] "Non-energy sectors" / sets.non_energy_private_sectors, sets.public_sectors /;

set t "Year." / %first_data_year% * %terminal_year% /;
set t1_[t] "Endogenous years.";
set t2_[t] "Endogenous years except first.";
set t1_tEnd[t] "Endogenous years except last.";

singleton set t0[t] "Year before first endogenous year.";
singleton set t1[t] "First endogenous year.";
singleton set t2[t] "Second endogenous year.";
singleton set tEnd[t] "Final year modeled (terminal year).";
singleton set tBase[t] "Base year where prices are set to 1." / %base_year% /;

$MACRO set_time_periods(start, end) \
  t0[t]   = yes$(t.val=&start-1);\
  t1[t]   = yes$(t.val=&start);\
  t2[t]   = yes$(t.val=(&start+1));\
  tEnd[t] = yes$(t.val=&end);\
  t1_[t]  = yes$(t.val>=&start and t.val<=&end);\
  t2_[t]  = yes$(t.val>&start and t.val<=&end);\
  t1_tEnd[t] = yes$(t.val>=&start and t.val<&end);\

