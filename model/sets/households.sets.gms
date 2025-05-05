
set cNest "Household consumption nests"
  /cHousing, cGoods, cGoodsFood, cGoodsNonFood, cCarTrans, cTouSer, cTouSerGoo, cNonHou, cTot/;

# set cNest2c[cNest,c] "Nesting structure for households"/

#   #First nest
#   cTot . (cHousing, cNonHou) 

#   #Second nest 
#   cHousing  . (cHou, cHouEne)
#   cNonHou . (cTouSerGoo, cCarTrans) 

#   #Third nest 
#   cCarTrans . (cCar, cCarEne)
#   cTouSerGoo . (cTouSer, cGoods)
  
#   #Fourth nest 
#   cTouSer . (cTou, cSer) 
#   cGoods . (cGoodsFood, cGoodsNonFood)

#   #Fifth nest
#   cGoodsFood . (cFoodVeg, cFoodMeat, cFoodFish, cFoodDairy, cFoodBev) 

#   /;