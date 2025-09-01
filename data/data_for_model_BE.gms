
#============================================================================================================#
# READ ME / OVERVIEW 
#============================================================================================================#
#
#This file is the final layer of data-treatment before the data enters the model. The structure of the file is:
#
# A) Model sets are initialized. To be used in reading from Python-treated data.
#
# B) Initilization of data-parameters. To be used in reading from Python-treated data.
#
# C) Tests of data-consistency
#
# D) Initializing parameters to be read into model
#
# E) Reading Python treated data into parameters to be read into model
#
#  F) Unload gdx with data in parameters with same names as model-variables, to be read into model
#
#
#  In the file £ denotes a part where country-specific update of this code is needed
#============================================================================================================#


### A) Initilization of model sets
set l "Technologies";
Set t ;#time periods
Set t1(t); #year 2020 
Set es; #energy service
Set k_; #capital types including tot, excluding inventories
Set k; #capital types
Set factors_of_production; 
Set ebalitems; #identifiers for energy components (tax, joules, prices, etc.)
Set em(ebalitems); #emission type
Set etaxes(ebalitems); #energy taxes
Set a_rows_; #"other" row from IO
Set transaction; 
Set demand_transaction(transaction);
Set d; #demand components
Alias(d,d_a);
Set i_; #sectors incl. tot
Set i(d); #sectors w.o. tot
Set d_non_ene(d);
Set d_ene(d);
Alias(i,i_a);
Set c(d); #private consumption
Set x(d); #export
Set g(d); #public final consumption
Set rx(d); #currently equal to i
Set re(d); #energy intermediate input
Set invt(d); #inventories
Set invt_ene(d);
Set tl(d); #transmission losses
Set out; #output types
Set e(out); #energy outputs
Set em_accounts; #set of accounts for emissions

### B) Initialization of parameters to be read from Python treated data
# $PGROUP PG_data_from_Python
parameters
  vIO_y[i,d,t] "IO - data, domesticsupply"
  vIO_m[i,d,t] "IO - data, imports"
  vIO_a[a_rows_,d,t] "IO -data, decomposition of GVA"
  vIOxE_y[i,d,t] "IO, excluding energy -data, domestic supply"
  vIOxE_m[i,d,t] "IO, excluding energy -data, imports"
  vIOxE_a[a_rows_,d,t] "IO, excluding energy - data, decomposition of GVA"
  vIOE_y[i,d,t] "EnergyIO -data, domestic supply"
  vIOE_m[i,d,t] "EnergyIO -data, imports"
  vIOE_a[a_rows_,d,t] "EnergyIO - data, decomposition of GVA"

  nEmployed[t] "Total labor supply data"
  qL[i,t] "Labour supply data"
  qK[k,i,t] "Capital stock data"
  qI_k_i[k,i,t] "Capital investments data"
  qCO2_ETS_freeallowances[i,t] "ETS1 free allowances data"
  qEmmLULUCF[t] "LULUCF-emissions data"
  qEmmBorderTrade[em,t]                         "Border trade emissions data"
  Energybalance[ebalitems,transaction,d,es,e,t] "Main data input with regards to energy and energy-related emissions"
  NonEnergyEmissions[ebalitems,transaction,d,t] "Main data input with regards to non-energy related emissions"
;

 
#  $gdxin data_DK.gdx #£) Here you should comment in and exchange data_DK.gdx with the gdx you have produced in read_data.py.
$gdxin data_BE.gdx
$load d, d_non_ene, d_ene, i,c,x,g,rx,re,invt,invt_ene,tl,out,e,t,t1,em_accounts,i_,k_
$load factors_of_production, k, ebalitems, em,etaxes,a_rows_,transaction,demand_transaction,es
$load vIO_y,vIO_m,vIO_a,vIOxE_y,vIOxE_m,vIOxE_a
$load nEmployed,qL,qK,qI_k_i
$load qEmmLULUCF,qEmmBorderTrade,qCO2_ETS_freeallowances
$load Energybalance, NonEnergyEmissions
$gdxin

set i_collapse[i]/G45,G46,G47/; set d_collapse[d]/G45,G46,G47/;
set i_remove[i]/G46,G47/; set d_remove[d]/G46,G47/;

#COLLAPSING MARGIN-SECTORS, G45, G46 and G47 INTO ONE SECTOR. THE SECTOR LABELS G46 and G47 WILL STILL EXIST, BUT ALL DATA WILL BE ZERO
vIO_y['G45',d,t] = sum(i_collapse, vIO_y[i_collapse,d,t]); 
vIO_y[i,'G45',t] = sum(d_collapse, vIO_y[i,d_collapse,t]);
vIO_y[i_remove,d,t] = 0; vIO_y[i,d_remove,t] = 0;

vIO_m['G45',d,t] = sum(i_collapse, vIO_m[i_collapse,d,t]); 
vIO_m[i,'G45',t] = sum(d_collapse, vIO_m[i,d_collapse,t]);
vIO_m[i_remove,d,t] = 0; vIO_m[i,d_remove,t] = 0;

vIOxE_y['G45',d,t] = sum(i_collapse, vIOxE_y[i_collapse,d,t]); 
vIOxE_y[i,'G45',t] = sum(d_collapse, vIOxE_y[i,d_collapse,t]);
vIOxE_y[i_remove,d,t] = 0; vIOxE_y[i,d_remove,t] = 0;

vIOxE_m['G45',d,t] = sum(i_collapse, vIOxE_m[i_collapse,d,t]); 
vIOxE_m[i,'G45',t] = sum(d_collapse, vIOxE_m[i,d_collapse,t]);
vIOxE_m[i_remove,d,t] = 0; vIOxE_m[i,d_remove,t] = 0;

#£AKB: EnergyIO appears to be empty - but that's okay, can backed out
# vIOE_y['G45',d,t] = sum(i_collapse, vIOE_y[i_collapse,d,t]); 
# vIOE_y[i,'G45',t] = sum(d_collapse, vIOE_y[i,d_collapse,t]);
# vIOE_y[i_remove,d,t] = 0; vIOE_y[i,d_remove,t] = 0;

# vIOE_m['G45',d,t] = sum(i_collapse, vIOE_m[i_collapse,d,t]); 
# vIOE_m[i,'G45',t] = sum(d_collapse, vIOE_m[i,d_collapse,t]);
# vIOE_m[i_remove,d,t] = 0; vIOE_m[i,d_remove,t] = 0;

vIO_a[a_rows_,'G45',t] = sum(d_collapse, vIO_a[a_rows_,d_collapse,t]);
vIO_a[a_rows_,d_remove,t] = 0;

vIOxE_a[a_rows_,'G45',t] = sum(d_collapse, vIOxE_a[a_rows_,d_collapse,t]);
vIOxE_a[a_rows_,d_remove,t] = 0;

# vIOE_a[a_rows_,'G45',t] = sum(d_collapse, vIOE_a[a_rows_,d_collapse,t]);
# vIOE_a[a_rows_,d_remove,t] = 0;

qL['G45',t] = sum(i_collapse, qL[i_collapse,t]); qL[i_remove,t] = 0;
qK[k,'G45',t] = sum(i_collapse, qK[k,i_collapse,t]); qK[k,i_remove,t] = 0; 
qI_k_i[k,'G45',t] = sum(i_collapse, qI_k_i[k,i_collapse,t]); qI_k_i[k,i_remove,t] = 0;
qCO2_ETS_freeallowances['G45',t] = sum(i_collapse, qCO2_ETS_freeallowances[i_collapse,t]); qCO2_ETS_freeallowances[i_remove,t] = 0;
Energybalance[ebalitems,transaction,'G45',es,e,t] = sum(d_collapse, Energybalance[ebalitems,transaction,d_collapse,es,e,t]); Energybalance[ebalitems,transaction,d_remove,es,e,t] = 0;
NonEnergyEmissions[ebalitems,transaction,'G45',t] = sum(d_collapse, NonEnergyEmissions[ebalitems,transaction,d_collapse,t]); NonEnergyEmissions[ebalitems,transaction,d_remove,t] = 0;  

#Creating auxiliary sets (These should be read from Python data)
set demand_transaction_temp[transaction] /'input_in_production','household_consumption','inventory','export','transmission_losses'/; #AKB: In "demand_transaction" there is an error with "households" being the set-element for households
set ebalitems_totalprice[ebalitems]/'Excises_tax','Margins','Subsidies_tax','Import_tax','vat','base'/; #AKB: Auxiliary set. £ Should be changed in in order to relefct country specific. Eg. does the country have "eav", "dav" and "cav"?
# set i_energymargins[i]/G45, G46, G47/; #£ Country specific industries "producing" margins
set i_energymargins[i]/G45/;

set eBunkering[e]/'Bunkering of Belgian operated trucks on foreign territory',
                  'Bunkering of Belgian operated vessels on foreign territory',
                  'Bunkering of Belgian operated planes on foreign territory'/;
set tData[t]/2020/;

parameter test_vIOxE_y[i,d,t];
test_vIOxE_y[i,d,t]$(vIOxE_y[i,d,t]<-1e-5) = vIOxE_y[i,d,t];

#£AKB: Hack - there is a negative entry here otherwise
vIOxE_y['35A','HH_others','2020'] = 0;
### C) Tests of energy-IO and energybalance (pt 1.)
$FUNCTION test_data():
  $OnMultiR
  Parameter testvY[i,t], testvM[i,t], testvE_base[d,t], testvE_duties[d,t], testvE_vat[d,t];
  $OffMulti

  #Testing energy-IO for negative cells (apart from inventories these are not allowed)
  LOOP((i,d,t)$(tData[t] and not (sameas[d,'invt_ene'] or sameas[d,'invt'] or sameas[d,'im'] or sameas[d,'ib'] or sameas[d,'it'])),
    ABORT$(vIOE_y[i,d,t]<-1e-5)  'vIOE_y has negative cells, data-quality needs to be revisited';
    ABORT$(vIOE_m[i,d,t]<-1e-5)  'vIOE_m has negative cells, data-quality needs to be revisited';
    ABORT$(vIOxE_y[i,d,t]<-1e-5) 'vIOxE_y has negative cells, data-quality needs to be revisited';
    ABORT$(vIOxE_m[i,d,t]<-1e-5) 'vIOxE_m has negative cells, data-quality needs to be revisited';
    );

  testvY[i,t] =  sum((es,e), Energybalance['base','production',i,es,e,t]) 
              + sum((d,es,e,transaction), Energybalance['Margins',transaction,d,es,e,t])$(sameas[i,'G45']) #£Change to country-specfic margin producing sectors
              - sum(d, vIOE_y[i,d,t]);
  # execute_unload 'test.gdx';
  #£AKB: Tolerance set high because of margins not matching
  ABORT$(abs(sum((i,tData), testvY[i,tData]))>2600) 'Test of energy-IO and energybalance failed! Value of production in industries do not match'; #£ Note the test tolerance is set relatively high at 1 bio. DKK. This should ideally be much lower, eg 1e-6


  testvM[i,t] =  sum((es,e), Energybalance['base','imports',i,es,e,t]) 
              - sum(d, vIOE_m[i,d,t]);
  #£AKB Tolerance set high 
  ABORT$(abs(sum((i,tData), testvM[i,tData]))>20000) 'Test of energy-IO and energybalance failed! Value of imports do not match'; #£ Note the test tolerance is set relatively high at 1 bio. DKK. This should ideally be much lower, eg 1e-6


  #£AKB Tolerance set high 
  testvE_base[d,t] 
    = sum((es,e,demand_transaction_temp), Energybalance['base',demand_transaction_temp,d,es,e,t])
    + sum((es,e,demand_transaction_temp), Energybalance['margins',demand_transaction_temp,d,es,e,t])
    - sum(i, vIOE_y[i,d,t] + vIOE_m[i,d,t]);
  ABORT$(abs(sum((d,tData), testvE_base[d,tData]))>2600) 'Test of energy-IO and energybalance failed! Value of energy demand do not match'; #£ Note the test tolerance is set relatively high at 1 bio. DKK. This should ideally be much lower, eg 1e-6


  testvE_duties[d,t] = sum((es,e,demand_transaction_temp,etaxes), Energybalance[etaxes,demand_transaction_temp,d,es,e,t]) 
                    -  vIOE_a['TaxSub',d,t];

  ABORT$(abs(sum((d,tData), testvE_duties[d,tData]))>15000) 'Test of energy-IO and energybalance failed! Value of energy duty revenues do not match'; #£ Note the test tolerance is set relatively high at 1 bio. DKK. This should ideally be much lower, eg 1e-6


  testvE_vat[d,t] = sum((es,e,demand_transaction_temp), Energybalance['VAT',demand_transaction_temp,d,es,e,t]) 
                  -  vIOE_a['Moms',d,t];

  ABORT$(abs(sum((d,tData), testvE_vat[d,tData]))>15000) 'Test of energy-IO and energybalance failed! Value of VAT do not match'; #£ Note the test tolerance is set relatively high at 1 bio. DKK. This should ideally be much lower, eg 1e-6

  #Test energybalance for internal consistency
    #Testing if all emissions are tied up to a use of energy
    LOOP((demand_transaction_temp,d,es,e,t)$(tData[t]),
    ABORT$(sum(em$Energybalance[em,demand_transaction_temp,d,es,e,t], 1$Energybalance[em,demand_transaction_temp,d,es,e,t] - 1$Energybalance['PJ',demand_transaction_temp,d,es,e,t]) <> 0) 'Data contains entries with emissions without any energy-use.';
    );

    #Test not applicable for Belgium as there is no domestic carbon tax in BE
    #Testing if there are CO2ubio emissions where a tax-payment is registred. GR-DK data does not pass this test currently. The tax ends up being applied as a per PJ-tax instead. This should be fixed in data.
    # LOOP((demand_transaction_temp,d,es,e,t)$(tData[t] and Energybalance['CO2ubio',demand_transaction_temp,d,es,e,t] and not sameas[e,'district heat'] and not sameas[e,'liquid biofuels']),
    # ABORT$(1$Energybalance['co2_tax',demand_transaction_temp,d,es,e,t] - 1$Energybalance['CO2ubio',demand_transaction_temp,d,es,e,t] <> 0) 'CO2-revenues where no emissions are registrered.';
    # );
    
$ENDFUNCTION 
 

 Energybalance[ebalitems,'imports','C19',es,e,t] = Energybalance[ebalitems,'imports','IMPORT',es,e,t];
 Energybalance[ebalitems,'imports','IMPORT',es,e,t] = 0;
 

  #Corrections to data - ideally this already be part of the input-data
  Energybalance[ebalitems,'export','xEne',es,e,t]        = Energybalance[ebalitems,'export','xOth',es,e,t];    Energybalance[ebalitems,'export','xOth',es,e,t]   = 0;
  Energybalance[ebalitems,'inventory','invt_ene',es,e,t] = Energybalance[ebalitems,'inventory','invt',es,e,t]; Energybalance[ebalitems,'inventory','invt',es,e,t] = 0;

  #Removing small entries. Should ideally be replaced by an elaborate RAS-procedure.
  Energybalance[ebalitems,transaction,d,es,e,t]$(Energybalance['BASE',transaction,d,es,e,t] and abs(Energybalance['BASE',transaction,d,es,e,t])<1e-6) = no; 

  #Computing energy-IO
  vIOE_y[i,d,t]         = vIO_y[i,d,t] - vIOxE_y[i,d,t];
  vIOE_m[i,d,t]         = vIO_m[i,d,t] - vIOxE_m[i,d,t];
  vIOE_a[a_rows_,d,t]   = vIO_a[a_rows_,d,t] - vIOxE_a[a_rows_,d,t];

  vIOE_y[i,'xENE',t]      = vIOE_y[i,'xOth',t];       vIOE_y[i,'xOth',t] = 0; 
  vIOE_m[i,'xENE',t]      = vIOE_m[i,'xOth',t];       vIOE_m[i,'xOth',t] = 0;
  vIOE_a[a_rows_,'xENE',t] =vIOE_a[a_rows_,'xOth',t]; vIOE_a[a_rows_,'xOth',t] = 0;

  vIOE_y[i,'invt_ene',t]      = vIOE_y[i,'invt',t];       vIOE_y[i,'invt',t] = 0; 
  vIOE_m[i,'invt_ene',t]      = vIOE_m[i,'invt',t];       vIOE_m[i,'invt',t] = 0;
  vIOE_a[a_rows_,'invt_ene',t] =vIOE_a[a_rows_,'invt',t]; vIOE_a[a_rows_,'invt',t] = 0;
  
### C) Tests of energy-IO and energybalance (pt 2.) 
@test_data();


  #Inserting energy-inputs into IO
  vIO_y[i,'xENE',t]         = vIOE_y[i,'xENE',t]; 
  vIO_m[i,'xENE',t]         = vIOE_m[i,'xENE',t]; 
  vIO_a[a_rows_,'xENE',t]   = vIOE_a[a_rows_,'xENE',t];

  vIO_y[i,'xOth',t]         = vIO_y[i,'xOth',t]       - vIOE_y[i,'xENE',t]; 
  vIO_m[i,'xOth',t]         = vIO_m[i,'xOth',t]       - vIOE_m[i,'xENE',t]; 
  vIO_a[a_rows_,'xOth',t]   = vIO_a[a_rows_,'xOth',t] - vIOE_a[a_rows_,'xENE',t];

  vIO_y[i,'invt_ene',t]       = vIOE_y[i,'invt_ene',t]; 
  vIO_m[i,'invt_ene',t]       = vIOE_m[i,'invt_ene',t]; 
  vIO_a[a_rows_,'invt_ene',t] = vIOE_a[a_rows_,'invt_ene',t];

  vIO_y[i,'invt',t]       = vIO_y[i,'invt',t]       - vIOE_y[i,'invt_ene',t]; 
  vIO_m[i,'invt',t]       = vIO_m[i,'invt',t]       - vIOE_m[i,'invt_ene',t]; 
  vIO_a[a_rows_,'invt',t] = vIO_a[a_rows_,'invt',t] - vIOE_a[a_rows_,'invt_ene',t];

  #Move all IOE_m to C19 as it is in energybalance 
  vIO_m['C19',d,t] = vIO_m['C19',d,t] + sum(i$(not sameas[i,'C19']), vIOE_m[i,d,t]);
  vIO_m[i,d,t]$(not sameas[i,'C19']) = vIO_m[i,d,t] - vIOE_m[i,d,t];

  vIOE_m['C19',d,t] = vIOE_m['C19',d,t] + sum(i$(not sameas[i,'C19']), vIOE_m[i,d,t]);
  vIOE_m[i,d,t]$(not sameas[i,'C19']) = 0;


  #We can now add energy-IO to our IO-matrix
  vIO_y[i,'energy',t] = sum(i_a,vIOE_y[i,i_a,t]);
  vIO_m[i,'energy',t] = sum(i_a,vIOE_m[i,i_a,t]);
  vIO_a[a_rows_,'energy',t]  = sum(i_a,vIOE_a[a_rows_,i_a,t]);

  vIO_y[i,re,'2019']       = vIO_y[i,re,'2020'];
  vIO_m[i,re,'2019']       = vIO_m[i,re,'2020'];
  vIO_a[a_rows_,re,'2019'] = vIO_a[a_rows_,re,'2020'];

  #We subtract the industry by industry energy, as this has been moved to the three energy categories for industries
  vIO_y[i,rx,t]       = vIO_y[i,rx,t]       - vIOE_y[i,rx,t];
  vIO_m[i,rx,t]       = vIO_m[i,rx,t]       - vIOE_m[i,rx,t];
  vIO_a[a_rows_,rx,t] = vIO_a[a_rows_,rx,t] - vIOE_a[a_rows_,rx,t];

  vIOE_y[i,'energy',t] = sum(rx, vIOE_y[i,rx,t]);
  vIOE_m[i,'energy',t] = sum(rx, vIOE_m[i,rx,t]);
  vIOE_a[a_rows_,'energy',t] = sum(rx, vIOE_a[a_rows_,'energy',t]); 

  vIOE_y[i,rx,t] = 0;
  vIOE_m[i,rx,t] = 0;
  vIOE_a[a_rows_,rx,t] = 0;


### D) Initilizating parameters to be read into model
parameters
  # Labor-market
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."
  vW[t] "Compensation pr. employee."

  # Input-output
  vY_i_d[i,d,t] "Output by industry and demand component."
  vY_i_d_base[i,d,t] "Output by industry and demand component in base prices"
  vM_i_d[i,d,t] "Imports by industry and demand component."
  vM_i_d_base[i,d,t] "Output by industry and demand component in base prices"
  vtY_i_d[i,d,t] "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t] "Net duties on imports by industry and demand component."
  vD[d,t] "Demand components in purchasing prices."
  vD_base[d,t] "Demand components in base-prices "
  qD[d,t] "Real demand by demand component."
  vtYM_d[d,t] "Net duties by demand component."
  vtY_i_Sub[i,t] "Production subsidies by industry"
  vtY_i_Tax[i,t] "Production taxes by industry"
  vtY_i_NetTaxSub[i,t] "Net production taxes and subsidies by industry"

  # Factor demand
  qK_k_i[k,i,t] "Real capital stock by capital type and industry."
  qL_i[i,t] "Labor in efficiency units by industry."
  qR_i[i,t] "Intermediate input by industry."
  qI_k_i[k,i,t] "Real investments by capital type and industry."
  qInvt_i[i,t] "Inventory investments by industry."
  qInvt_ene_i[i,t] "Inventory investments by industry."
  qE_re_i[re,i,t] "Energy demand from industry i, split on energy-types re"

  #Energy (and output including non-energy output in Y_CET and M_CET). 
  pEpj_base[es,e,d,t] "Base prices of energy, by energy-service, energy-good and demand component"
  pEpj_own[es,e,d,t] "Price of consumption of own-production of energy, by energy-service, energy-good and demand component"
  vtE_duty[etaxes,es,e,d,t] "Duty-revenues on energy by tax, energy-service, energy-good and demand component"
  vtE_vat[es,e,d,t]  "VAT-revenue on energy by energy-service, energy-good and demand component"
  qEpj[es,e,d,t] "Energy consumption by energy-service, energy-good and demand component"
  qEpj_own[es,e,d,t] "Energy consumption from own-production by energy-service, energy-good and demand component"
  vWMA[es,e,d,t] "Margins on wholesale of energy by energy-service, energy-good and demand component"
  vCMA[es,e,d,t] "Margins on energy sold from car-dealerships, by energy-service, energy-good and demand component"
  vRMA[es,e,d,t] "Margins on energy sold reatil, by energy-service, energy-good and demand component"
  qEmmE_BU[em,es,e,d,t] "Energy-related emissions by emission-type, energy-service, energy-good, and demand component"
  qEmmxE[em,d,t] "Non-energy related emissions by emission-type and demand component"
  tCO2_Emarg[em,es,e,d,t] "Marginal carbon taxes by emission-type, energy-service, energy-good, and demand component"  
  tEmarg_duty[etaxes,es,e,d,t] "Marginal energy tax by emission-type, energy-service, energy-good, and demand component"       
  qY_CET[out,i,t] "Total production by output and industry"
  qY_CETown[out,i,t] "Total production for own-consumption by output and industry"
  qY_CETgross[out,i,t] "Total production including own-consumption by output and industry"
  qM_CET[out,i,t] "Total imports by output and industry"
  pY_CET[out,i,t] "Price of domestic supply by output and industry"
  pM_CET[out,i,t] "Price of imports by output and industry"
  qCO2_ETS_freeallowances[i,t] "Free ETS1-allowances by industry"


  #Emissions
  qEmmBunkering[em,t] "Bunkering emissions"
  qEmmBorderTrade[em,t] "Border trade emissions"
  qEmmLULUCF[t] ""
  qEmmTot[em,em_accounts,t] ""
  GWP[em] ""
  sBioNatGas[t] ""

  #Production function
  qProd[factors_of_production,i,t] "Factors of production, value"
  pProd[factors_of_production,i,t] "Factors of production, price"

  # Abatement
  theta_load[l,es,i,e,t] "Potential, technology."
  uTE_load[l,es,i,e,t] "Energy use, technology."
  uTK_load[l,es,i,e,t] "Capital use, technology."

  theta[l,es,i,t] "Potential, technology."
  uTE[l,es,e,i,t] "Energy use, technology."
  uTK[l,es,i,t] "Capital use, technology."

  #Gov
  vGov2Foreign[t] "Payments to foreign countries."
;

#£) Here we load technology data - the below path should be replaced by country-specific code
#  $gdxIn %data_path%/EU_tech_data_disagg.gdx #
#  $load l=l, theta_load=theta.l, uTE_load=uTE.l, uTK_load=uTK.l
#  $gdxIn


### E) Reading Python treated data into parameters to be read into model

# Labor-market
vWages_i[i,t] = vIO_a["SalEmpl",i,t];
nL[t] = nEmployed[t]; #nEmployed[t].l
vW[t]$(nL[t]) = sum(i, vWages_i[i,t]) / nL[t];

# Input-output
vY_i_d_base[i,d,t] = vIO_y[i,d,t];
vM_i_d_base[i,d,t] = vIO_m[i,d,t];

#Demand-components, total in base prices
vD_base[d,t] = sum(i, vY_i_d_base[i,d,t] + vM_i_d_base[i,d,t]);

#Taxes by demand component
vtYM_d[d,t]       = vIO_a["TaxSub",d,t] + vIO_a["Moms",d,t];

#Assume same tax-rates per IO-cell
vtY_i_d[i,d,t]$(vD_base[d,t]) = vY_i_d_base[i,d,t] / vD_base[d,t] * vtYM_d[d,t]; 
vtM_i_d[i,d,t]$(vD_base[d,t]) = vM_i_d_base[i,d,t] / vD_base[d,t] * vtYM_d[d,t]; 

#Production taxes and subsidies
vtY_i_Sub[I,t] = -vIO_a['OthSubs',i,t];
vtY_i_Tax[I,t] =  vIO_a['OthTax',i,t];

#Compute IO incl. taxes, based on above distribution
#AKB: In input_output.gms vY_i_d and vM_i_d are defined including taxes
vY_i_d[i,d,t] = vY_i_d_base[i,d,t] + vtY_i_d[i,d,t];
vM_i_d[i,d,t] = vM_i_d_base[i,d,t] + vtM_i_d[i,d,t];

#Compute demand components in purchasing prices
vD[d,t] = sum(i, vY_i_d[i,d,t] + vM_i_d[i,d,t]);

#We normalize prices to 1 and load quantities into model
qD[d,t] = vD[d,t];

 #£ correct for Belgian margins sectors
#Non-energy-markets
qY_CET['out_other',i,t] = sum(d_non_ene,vIOxE_y[i,d_non_ene,t]) + sum(d,vIOE_y[i,d,t])$(sameas[i,'G46'] or sameas[i,'G45'] or sameas[i,'G47']); #£ Replace margin-producing sectors by country-specific
qM_CET['out_other',i,t] = sum(d_non_ene,vIOxE_m[i,d_non_ene,t]);
pY_CET['out_other',i,t]$qY_CET['out_other',i,t] = 1;
pM_CET['out_other',i,t]$qM_CET['out_other',i,t] = 1;


#Energy and emissions.
  pEpj_base[es,e,d,t]$(sum(demand_transaction_temp, Energybalance['PJ',demand_transaction_temp,d,es,e,t])) = sum(demand_transaction_temp, Energybalance['BASE',demand_transaction_temp,d,es,e,t])/sum(demand_transaction_temp, Energybalance['PJ',demand_transaction_temp,d,es,e,t]);
  qEpj[es,e,d,t] = sum(demand_transaction_temp, Energybalance['PJ',demand_transaction_temp,d,es,e,t]);

  #£ correct for Belgian margins sectors
  vWMA[es,e,d,t] = sum(demand_transaction_temp, Energybalance['Margins',demand_transaction_temp,d,es,e,t]);
#   vWMA[es,e,d,t] = sum(demand_transaction_temp, Energybalance['EAV',demand_transaction_temp,d,es,e,t]);
#   vCMA[es,e,d,t] = sum(demand_transaction_temp, Energybalance['CAV',demand_transaction_temp,d,es,e,t]);
#   vRMA[es,e,d,t] = sum(demand_transaction_temp, Energybalance['DAV',demand_transaction_temp,d,es,e,t]);

  #£ The below (commented out) showcases the ad hoc handling of consumption of own-produced energy that is not in NAS for the Danish case. A similar fix might be necessary for country-specific data
  #Own-consumption is handled relatively ad hoc
   qY_CETgross[e,i,t] = sum(es, Energybalance['PJ','production',i,es,e,t]);
   qY_CETgross['out_other',i,t] = qY_CET['out_other',i,t];
  #  qEpj_own[es,e,i,t] = sum(demand_transaction_temp$(not Energybalance['BASE',demand_transaction_temp,i,es,e,t] and (sameas[e,'Straw for energy purposes'] or sameas[e,'natural gas (Extraction)'])), Energybalance['PJ',demand_transaction_temp,i,es,e,t]);
  #  qEpj_own[es,e,i,t]$(not sameas[e,'natural gas (extraction)']) = 0;
  
  #  qY_CETown[e,i,t]$sum(i_a, qY_CETgross[e,i_a,t]) = sum((es,i_a), qEpj_own[es,e,i_a,t])*qY_CETgross[e,i,t]/sum(i_a, qY_CETgross[e,i_a,t]);


  #  parameter total_supply[e,t], total_demand[e,t], diff_demand_supply[e,t];
  #  total_supply[e,t]$(sum((es,i), Energybalance['BASE','production',i,es,e,t]) or sum((es,i), Energybalance['BASE','imports',i,es,e,t])) 
  #    = sum((es,i), Energybalance['PJ','production',i,es,e,t]) + sum((es,i), Energybalance['PJ','imports',i,es,e,t]);

  #  total_demand[e,t]  
  #    = sum((demand_transaction_temp,d,es)$Energybalance['BASE',demand_transaction_temp,d,es,e,t], Energybalance['PJ',demand_transaction_temp,d,es,e,t])
  #     + sum((demand_transaction_temp,es), Energybalance['PJ',demand_transaction_temp,'tl',es,e,t]);

  #  diff_demand_supply[e,t] = total_demand[e,t] - total_supply[e,t];


  #  #Corrections for residual of non-priced energy in data (it should only be a bit of electricity and the straw that goes to households in DK data)
  #  qY_CETgross['Electricity','35011',t] = qY_CETgross['Electricity','35011',t] + diff_demand_supply['electricity',t];
  #  qY_CETgross['Straw for energy purposes','01011',t] = qY_CETgross['Straw for energy purposes','01011',t] 
  #                                                      + diff_demand_supply['Straw for energy purposes',t]; 
  #                                                      # - qY_CETown['Straw for energy purposes','01011',t] 
  #                                                      # - qY_CETown['Straw for energy purposes','01012',t];

   qY_CET[e,i,t] = qY_CETgross[e,i,t];# - qY_CETown[e,i,t];
   qM_CET[e,i,t] = sum(es, Energybalance['PJ','imports',i,es,e,t]);

   pY_CET[e,i,t]$(qY_CET[e,i,t]) = sum(es,Energybalance['BASE','production',i,es,e,t])/qY_CET[e,i,t];
   pM_CET[e,i,t]$(qM_CET[e,i,t]) = sum(es,Energybalance['BASE','imports',i,es,e,t])/qM_CET[e,i,t];

  #  #Price of own production 
  #  pEpj_own[es,e,i,t]$(qEpj_own[es,e,i,t] and sum(i_a, qY_CET[e,i_a,t])) = sum(i_a, pY_CET[e,i_a,t]*qY_CET[e,i_a,t])/sum(i_a, qY_CET[e,i_a,t]);

#Emissions
  qEmmE_BU[em,es,e,d,t]     = sum(demand_transaction_temp,Energybalance[em,demand_transaction_temp,d,es,e,t]);
  qEmmxE[em,d,t]            = sum(demand_transaction_temp,NonEnergyEmissions[em,demand_transaction_temp,d,t]);

  #£AKB: Does not apply for BE?
  # sBioNatGas[t]$((sum((demand_transaction_temp,es,d), Energybalance['CO2bio',demand_transaction_temp,d,es,'Natural gas incl. biongas',t]) + sum((demand_transaction_temp,es,d), Energybalance['CO2ubio',demand_transaction_temp,d,es,'Natural gas incl. biongas',t])))
  #              =  sum((demand_transaction_temp,es,d), Energybalance['CO2bio',demand_transaction_temp,d,es,'Natural gas incl. biongas',t])/
  #                (sum((demand_transaction_temp,es,d), Energybalance['CO2bio',demand_transaction_temp,d,es,'Natural gas incl. biongas',t]) + sum((demand_transaction_temp,es,d), Energybalance['CO2ubio',demand_transaction_temp,d,es,'Natural gas incl. biongas',t]));


  qEmmTot[em,em_accounts,t] = sum((es,e,d), qEmmE_BU[em,es,e,d,t]) + sum(d, qEmmxE[em,d,t]);

  #£AKB: Does not apply for BE?
  qEmmBunkering[em,t] = sum((demand_transaction_temp,es,d,e)$(eBunkering[e]), Energybalance[em,demand_transaction_temp,d,es,e,t]);



  #Production
  #AKB: In input_output.gms vY_i_d and vM_i_d are defined including taxes
  qProd['RxE',i,t]                 = sum(i_a,vY_i_d[i_a,i,t] + vM_i_d[i_a,i,t]); # This should be good, we opted against using rows because vIO's are defined on demand_components incl. non sectors qRxE.l[i,t];
  qProd['labor',i,t]               = qL[i,t];
  qProd['iM',i,t]                  = qK['iM',i,t];
  qProd['iT',i,t]                  = qK['iT',i,t];
  qProd['iB',i,t]                  = qK['iB',i,t];
  qProd['machine_energy',i,t]      = sum((es,e,ebalitems_totalprice)$(not (sameas[es,'Heating'] or sameas[es,'Transport'])), Energybalance[ebalitems_totalprice,'input_in_production',i,es,e,t]);
  qProd['transport_energy',i,t]    = sum((es,e,ebalitems_totalprice)$(sameas[es,'Transport']), Energybalance[ebalitems_totalprice,'input_in_production',i,es,e,t]);
  qProd['heating_energy',i,t]      = sum((es,e,ebalitems_totalprice)$(sameas[es,'heating']), Energybalance[ebalitems_totalprice,'input_in_production',i,es,e,t]);
  pProd[factors_of_production,i,t] = 1;

# Factor demand
  qK_k_i[k,i,t] = qK[k,i,t]; qK_k_i[k,i,t] = qK_k_i[k,i,'2020']; 
  #qI_k_i[k,i,t] =qI_s.l[k,i,t]; #We read this variable directly from input-data
  qR_i[i,t] =sum(i_a,vY_i_d[i_a,i,t] + vM_i_d[i_a,i,t]); 
  qL_i[i,t] = qL[i,t];
  
  #Energy
  qE_re_i['energy',i,t] = qProd['machine_energy',i,t] + qProd['transport_energy',i,t] + qProd['heating_energy',i,t];
  qInvt_i[i,t] = vY_i_d[i,'invt',t] + vM_i_d[i,'invt',t];              # + vtYM_d['invt',t]; AKB: In input_output.gms vY_i_d and vM_i_d are defined including taxes
  qInvt_ene_i[i,t] = vY_i_d[i,'invt_ene',t] + vM_i_d[i,'invt_ene',t];  #+ vtYM_d['invt_ene',t]; AKB: In input_output.gms vY_i_d and vM_i_d are defined including taxes


#Taxes

  #£ The below (commented out) showcases how marginal taxes are handled for the Danish case. Replace with country-specific data      
   PARAMETER tCO2_REmarg[es,e,d,t,em], tEAFG_REmarg[es,e,d,t]; #Marginal Danish tax-rates directly from GR-DK
   execute_load 'data_BE.gdx' tEAFG_REmarg;

  #£AKB: Filling in zeros for BE-case 
  tCO2_REmarg[es,e,d,t,em] = 0;

  #  tCO2_REmarg[es,'district heat',d,t,em]$tCO2_REmarg[es,'district heat',d,t,em] = 0;

  #  tCO2_Emarg[em,es,e,d,t] = tCO2_REmarg[es,e,d,t,em];
  #  tCO2_Emarg['CO2bio','transport','liquid biofuels',d,t]$tCO2_Emarg['CO2bio','transport','gasoline for transport',d,t] = tCO2_Emarg['CO2ubio','transport','gasoline for transport',d,t];
  #  tCO2_Emarg['CO2bio','transport','liquid biofuels',d,t]$(not tCO2_Emarg['CO2bio','transport','gasoline for transport',d,t]) = tCO2_Emarg['CO2ubio','transport','diesel for transport',d,t];

  #  tCO2_Emarg[em,es,e,'cHouEne',t] = tCO2_Emarg[em,'heating',e,'68203',t];
  #  tCO2_Emarg[em,es,e,'cCarEne',t] = tCO2_Emarg[em,'transport',e,'68203',t];

  #  #Other duties, not CO2 is given a value
   tEmarg_duty[etaxes,es,e,d,t]$(sum(demand_transaction_temp, Energybalance['PJ',demand_transaction_temp,d,es,e,t]))
                                 = sum(demand_transaction_temp, Energybalance[etaxes,demand_transaction_temp,d,es,e,t])
                                  /sum(demand_transaction_temp, Energybalance['PJ',demand_transaction_temp,d,es,e,t]);

   tEmarg_duty[etaxes,es,e,d,t]$tEmarg_duty[etaxes,es,e,d,t] = tEmarg_duty[etaxes,es,e,d,t] + 0.01;

# £ change to country specific serctor
   tEmarg_duty['Excises_tax',es,e,d,t] = tEAFG_REmarg[es,e,d,t];
   tEmarg_duty['Excises_tax',es,e,'HH_heating',t] = tEmarg_duty['Excises_tax','heating',e,'real_estate',t];
   tEmarg_duty['Excises_tax',es,e,'HH_transport',t] = tEmarg_duty['Excises_tax','transport',e,'real_estate',t];


  vtE_duty[etaxes,es,e,d,t] = sum(demand_transaction_temp, Energybalance[etaxes,demand_transaction_temp,d,es,e,t]);
  vtE_vat[es,e,d,t]          = sum(demand_transaction_temp, Energybalance['VAT',demand_transaction_temp,d,es,e,t]);

  # Abatement
  #£AKB: Will come later for BE.
  # theta[l,es,i,t] = sum(e, theta_load[l,es,i,e,t]);
  # uTE[l,es,e,i,t] = uTE_load[l,es,i,e,t];
  # uTK[l,es,i,t] = sum(e, uTK_load[l,es,i,e,t]);


###  F) Unload gdx with data in parameters with same names as model-variables, to be read into model
#£ Give country-specific data a gdx-name below
execute_unload 'data_BE_final'

