set consumption_nests /
#   Food "All food"
#   Goods "Goods"
#   TourServ "Tourisme and services"
#   GooTouSer "Goods, tourisme and services"
#   CarSer "Cars incl. energy"
#   NonHou "Consumption exluding housing"
#   HouSer "Housing incl. energy"

  TopCfunction "The top nest of consumption function"
/;


set cf "Inputs and their nests in consumption function" /
  set.c
  set.consumption_nests
/;

set cf_bottom[cf] /set.c/;
set cfNest[cf] /set.consumption_nests/;
set cf_top[cf] /TopCfunction/;
set cf_ene[cf]/HH_heating,HH_transport/;


set cf_mapping[cfNest,cf] /
#   Food . (cFoodMeat, cFoodDairy, cFoodVeg, cFoodBev,cFoodFish)
#   Goods . (Food, cNonFood)
#   TourServ . (cSer, cTou)
#   GooTouSer . (Goods, TourServ)
#   CarSer . (HH_transport, cCar)
#   NonHou . (GooTouSer, CarSer)
#   HouSer . (HH_heating, cHou)
#   TopCfunction . (NonHou, HouSer)
  TopCfunction . (HH_heating, HH_transport, HH_others)
/;  

set c2cf_bottom_mapping[c,cf_bottom];
c2cf_bottom_mapping[c,cf_bottom] = yes$(sameas[c,cf_bottom]);


set es2cf2d(es,cf,d)/
  (heating, appliances) . HH_heating . HH_heating
  (Transport) . HH_transport . HH_transport
  /;