
Set sector "Sectors of the economy as defined in national accounts." /
  FinCorp "Financial corporations."
  NonFinCorp "Non-financial corporations."
  Gov "General government including subsectors."
  Hh "Households and non-profit institutions serving households."
  RoW "Rest of the world including subsectors."
/;

Set FinCorp[sector] / FinCorp /;
Set NonFinCorp[sector] / NonFinCorp /;
Set Gov[sector] / Gov /;
Set Hh[sector] / Hh /;
Set RoW[sector] / RoW /;

alias(sector, from_sector, to_sector)