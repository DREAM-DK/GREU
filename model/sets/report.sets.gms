Set iagg "Aggregration of industries" /Agriculture, manufacturing, power_and_utility, construction, service/;

set iagg2i(iagg,i) "Mapping from i to iagg"/
  Agriculture .('01011','01012','01020','01031','01032','01051','01052','01061','01062','01070','01080','02000','03000')
  manufacturing .('10010','10020','10030','10040','10120','13150','16000','20000','21000','23001','23002','25000')
  power_and_utility .('0600a','19000','35011','35002','36000','37000','38391','38392','38393','38394','38395')
  construction .('41430')
  service .('45000','46000','47000','49011','49012','49022','49024','49025','49031','49509','50001','51001','51009','52000','53000','55560','64000','68203','71000','off')
  /;


Set emission_categories "Emission categories"/
  Total
  ETS1
  ETS2
  Energy_NotETS
  NonEnergyEmissions
  /;

Set NotETS_industries(i) "Industries not in ETS2"/
  '01011','01012','01020','01031','01032','01051','01052','01061','01062','01070','01080'
  /;



# Set emission_categories2purpose(emission_categories,es,d) "Mapping from emission categories to purpose"/
#   ETS1.('in_ETS')
#   ETS2. (heating,transport,appliances,process_normal,process_special,unspecified)
#   /;

set esXin_ETS[es];
esXin_ETS[es]=yes;
esxin_ETS['in_ETS']=no;

Set map_emission_categories(emission_categories,es,i) "Mapping from purpose and industries to emission categories";
map_emission_categories('ETS1','in_ETS',i)=yes;
map_emission_categories('ETS2',esxin_ETS,i)=yes;
map_emission_categories('ETS2',esxin_ETS,NotETS_industries)=no;
map_emission_categories('Energy_NotETS',esxin_ETS,NotETS_industries)=yes;


Set flow "Types of flows between sectors" /
  CashFlow
  Interests
  Wages
  Transfers
  HhTaxes
  CorpTaxes
  Y
  C
  I
  ETS
  X
  M
  NetTaxSub  
  G
  Duties
  Lumpsum
  Test
  /;


# set EV_set_incl_Weight "Types of equivalent variations" /
#   Income_d
#   Income_f
#   Price_d
#   Price_f
#   Wealth_d
#   Wealth_f
#   r_fv
#   Weight
#   /;

set EV_set "Types of equivalent variations" /
  Income_d
  Income_f
  Price_d
  Price_f
  Wealth_d
  Wealth_f
  /;

set Shadow_price_set "Components of shadow prices" /
  EV
  Emissions
  Shadow_price
  /;


set income_set "Types of income" /
  Wages
  Lumpsum
  Transfers
  HhTaxes
  /;

set EVt_display_set "Types of equivalent variations for display" /
  EV
  Weight
  /; 

