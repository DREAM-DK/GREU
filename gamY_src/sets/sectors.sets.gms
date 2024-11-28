
Set sector "Sectors of the economy as defined in national accounts." /
  Corp "Financial and non-financial corporations including subsectors."
  Gov "Geral government including subsectors."
  Hh "Households and non-profit institutions serving households."
  RoW "Rest of the world including subsectors."
/;

Set Corp[sector] / Corp /;
Set Gov[sector] / Gov /;
Set Hh[sector] / Hh /;
Set RoW[sector] / RoW /;

alias(sector, from_sector, to_sector)