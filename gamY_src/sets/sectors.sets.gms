
set sector "Sectors of the economy as defined in national accounts." /
  Corp "Financial and non-financial corporations including subsectors."
  Gov "Geral government including subsectors."
  Hh "Households and non-profit institutions serving households."
  RoW "Rest of the world including subsectors."
/;

set ESA10_sectors "ESA 2010 sectors as defined in the European System of Accounts." /
  S11 "Financial corporations including subsectors."
  S12 "Non-financial corporations including subsectors."
  S13 "Geral government including subsectors."
  S14 "Households."
  S15 "Non-profit institutions serving households."
  S2 "Rest of the world including subsectors."
/;

singleton set Corp[sectors] / Corp /;
singleton set Gov[sectors] / Gov /;
singleton set Hh[sectors] / Hh /;
singleton set RoW[sectors] / RoW /;

set sectors2ESA10_sector[sector] "Mapping to ESA 2010 sector codes" /
  Corp . (S11, S12)
  Gov . S13
  Hh . (S14, S15)
  RoW . S2
/;

alias(sector, from_sector, to_sector)