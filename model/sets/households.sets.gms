# set types_of_consumption /
#   set.c
# /;


set consumption_nests /
  Meat "Pig, cow, poultry and fish"
  Food "All food"
  Goods "Goods" 
  TourServ "Tourisme and services"
  GooTouSer "Goods, tourisme and services"
  CarSer "Cars incl. energy"
  NonHou "Consumption exluding housing"
  HouSer "Housing incl. energy"
  TopCfunction "The top nest of consumption function"
/;


set cf "Inputs and their nests in consumption function" /
  set.c
  set.consumption_nests
/;

set cf_bottom[cf] /set.c/;
set cfNest[cf] /set.consumption_nests/;
set cf_top[cf] /TopCfunction/;


set cf_mapping[cfNest,cf] /
  Meat . (cFoodPig, cFoodCow, cFoodPoul, cFoodFish)
  Food . (Meat, cFoodDairy, cFoodVeg, cFoodBev)
  Goods . (Food, cNonFood)
  TourServ . (cSer, cTou)
  GooTouSer . (Goods, TourServ)
  CarSer . (cCarEne, cCar)
  NonHou . (GooTouSer, CarSer)
  HouSer . (cHouEne, cHou)
  TopCfunction . (NonHou, HouSer)
/;  

set c2cf_bottom_mapping[c,cf_bottom] /
  cFoodPig.cFoodPig
  cFoodCow.cFoodCow
  cFoodPoul.cFoodPoul
  cFoodFish.cFoodFish
  cFoodDairy.cFoodDairy
  cFoodVeg.cFoodVeg
  cFoodBev.cFoodBev
  cNonFood.cNonFood
  cSer.cSer
  cTou.cTou
  cCarEne.cCarEne
  cCar.cCar
  cHouEne.cHouEne
  cHou.cHou
/;  
