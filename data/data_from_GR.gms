$set data_path P:/akg/Til_EU_projekt

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
Set i_; #sectors incl. tot
Set i(d); #sectors w.o. tot
Alias(i,i_a);
Set c(d); #private consumption
Set x(d); #export
Set g(d); #public final consumption
Set rx(d); #currently equal to i
Set re(d); #energy intermediate input
Set invt(d); #inventories
Set tl(d); #transmission losses
Set out; #output types
Set e(out); #energy outputs
Set m(i);
Set land5; #land area types
Set em_accounts; #set of accounts for emissions
parameters
  vIO_y[i,d,t]
  vIO_m[i,d,t]
  vIO_a[a_rows_,d,t]
  vIOxE_y[i,d,t]
  vIOxE_m[i,d,t]
  vIOxE_a[a_rows_,d,t]
  nEmployed[t]
  qL[i,t]
  qK[k,i,t]
  qI_k_i[k,i,t]
  qCO2_ETS_freeallowances[i,t]
  qEmmLULUCF[t]
  qEmmBorderTrade[em,t]

;
$gdxin dataa_ny.gdx
$load d,i,c,x,g,rx,re,invt,tl,out,e,t,t1,land5,em_accounts,i_,k_
$load factors_of_production, k, ebalitems, em,etaxes,a_rows_,transaction,demand_transaction,es
$load vIO_y=vIO_y.l, vIO_m=vIO_m.l, vIOxE_y=vIOxE_y.l, vIOxE_m=vIOxE_m.l, vIO_a=vIO_a.l,vIOxE_a=vIOxE_a.l
$load nEmployed=nEmployed.l, qL=qL.l, qK=qK.l, qI_k_i=qI_k_i.l
$load qEmmLULUCF=qEmmLULUCF.l,qEmmBorderTrade=qEmmBorderTrade.l,qCO2_ETS_freeallowances=qCO2_ETS_freeallowances.l

$gdxIn %data_path%/EU_GR_data.gdx
#$load vIO_a, vIOxE_a
$gdxIn
m[i] = yes$sum((d,t1), vIO_m[i,d,t1]);


variables
  #nEmployed[t]

  #qK[k,i,t]
  #qI_s[*,i,t]
  pK[k,i,t]
  pL[i,t]
  #qL[i,t]
  qRxE[i,t]
  pRxE[i,t]

;


parameters GREU_data
  # Labor-market
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."
  vW[t] "Compensation pr. employee."

  # Input-output
  vY_i_d[i,d,t] "Output by industry and demand component."
  vM_i_d[i,d,t] "Imports by industry and demand component."
  vtY_i_d[i,d,t] "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t] "Net duties on imports by industry and demand component."
  vD[d,t] "Demand by demand component."
  qD[d,t] "Real demand by demand component."
  vtYM_d[d,t] "Net duties by demand component."

  # Factor demand
  qK_k_i[k,i,t] "Real capital stock by capital type and industry."
  qL_i[i,t] "Labor in efficiency units by industry."
  qR_i[i,t] "Intermediate input by industry."
  qI_k_i[k,i,t] "Real investments by capital type and industry."
  qInvt_i[i,t] "Inventory investments by industry."
  qE_re_i[re,i,t] "Energy demand from industry i, split on energy-types re"

  #Energy and emissions.
  Energybalance[ebalitems,transaction,d,es,e,t] "Main data input with regards to energy and energy-related emissions"
  NonEnergyEmissions[ebalitems,transaction,d,t] "Main data input with regards to non-energy related emissions"
  qEmmBorderTrade[em,t] ""
  pEpj_base[es,e,d,t] ""
  vtE_duty[etaxes,es,e,d,t] ""
  vtE_vat[es,e,d,t]  ""
  qEpj[es,e,d,t] ""
  vEAV[es,e,d,t] ""
  vCAV[es,e,d,t] ""
  vDAV[es,e,d,t] ""
  qEmmE_BU[em,es,e,d,t] ""
  qEmmxE[em,d,t] ""
  tCO2_Emarg[em,es,e,d,t]   
  tEmarg_duty[es,e,d,t]      
  qEtot[e,t] ""
  pE_avg[e,t] ""


  qProd[factors_of_production,i,t]
  pProd[factors_of_production,i,t]

  qEmmLULUCF5[land5,t]
  qEmmLULUCF[t] 
  sBioNatGas[t]

  GWP[em]

  vtCO2_ETS[i,t] 
  qCO2_ETS_freeallowances[i,t]

  vtNetproductionRest[i,t]
  vtCAP_prodsubsidy[i,t]

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


$gdxIn %data_path%/EU_tech_data_disagg.gdx
$load l=l, theta_load=theta.l, uTE_load=uTE.l, uTK_load=uTK.l
$gdxIn



# Labor-market
vWages_i[i,t] = vIO_a["SalEmpl",i,t];
nL[t] = nEmployed[t]; #nEmployed[t].l
vW[t]$(nL[t]) = sum(i, vWages_i[i,t]) / nL[t];

# Input-output
vY_i_d[i,d,t] = vIO_y[i,d,t];
vM_i_d[i,d,t] = vIO_m[i,d,t];
vY_i_d[i,rx,t] = vIOxE_y[i,rx,t];
vM_i_d[i,rx,t] = vIOxE_m[i,rx,t];
#below does not work
#vY_i_d[i,'energy',t] = sum(rx, vIO_y[i,rx,t] - vIOxE_y[i,rx,t]);
#vM_i_d[i,'energy',t]

vY_i_d[i,re,t] =  vIO_y[i,re,t] - vIOxE_y[i,re,t];
vM_i_d[i,re,t] =  vIO_m[i,re,t] - vIOxE_m[i,re,t];

vD[d,t] = sum(i, vY_i_d[i,d,t] + vM_i_d[i,d,t]);

vtYM_d[d,t]       = vIOxE_a["TaxSub",d,t] + vIOxE_a["Moms",d,t];
vtYM_d[d,t]$(sameas[d,'cHouEne'] or sameas[d,'cCarEne']) = vIO_a['TaxSub',d,t] + vIO_a['Moms',d,t] -  vIOxE_a["TaxSub",d,t] - vIOxE_a["Moms",d,t];
#Tried to add energy record manually to d, below still does not work
#vtYM_d['energy',t] = sum(d$(not (sameas[d,'cHouEne'] or sameas[d,'cCarEne'])), vIO_a['TaxSub',d,t] + vIO_a['Moms',d,t] -  vIOxE_a["TaxSub",d,t] - vIOxE_a["Moms",d,t]);
vtYM_d[re,t] =  vIO_a['TaxSub',re,t] + vIO_a['Moms',re,t] -  vIOxE_a["TaxSub",re,t] - vIOxE_a["Moms",re,t]);

vtY_i_d[i,d,t]$vD[d,t] = vY_i_d[i,d,t] / vD[d,t] * vtYM_d[d,t]; 
vtM_i_d[i,d,t]$vD[d,t] = vM_i_d[i,d,t] / vD[d,t] * vtYM_d[d,t]; 

qD[d,t] = vD[d,t];


#Energy and emissions.
  #$import create_energybalance.gms #Here GreenREFORM variables are combine to create the full energybalance as we would preferably receive it from the Statistical Office.
    $gdxin dataa_ny.gdx
    $load Energybalance=Energybalance.l
    $load NonEnergyEmissions=NonEnergyemissions.l

  pEpj_base[es,e,d,t]$(sum(demand_transaction, Energybalance['PJ',demand_transaction,d,es,e,t])) = sum(demand_transaction, Energybalance['BASE',demand_transaction,d,es,e,t])/sum(demand_transaction, Energybalance['PJ',demand_transaction,d,es,e,t]);
  qEpj[es,e,d,t] = sum(demand_transaction, Energybalance['PJ',demand_transaction,d,es,e,t]);

  vEAV[es,e,d,t] = sum(demand_transaction, Energybalance['EAV',demand_transaction,d,es,e,t]);
  # vCAV[es,e,d,t] = sum(demand_transaction, Energybalance['CAV',demand_transaction,d,es,e,t]);
  vDAV[es,e,d,t] = sum(demand_transaction, Energybalance['DAV',demand_transaction,d,es,e,t]);

#Emissions
  qEmmE_BU[em,es,e,d,t]     = sum(demand_transaction,Energybalance[em,demand_transaction,d,es,e,t]);
  qEmmxE[em,d,t]            = sum(demand_transaction,NonEnergyEmissions[em,demand_transaction,d,t]);

  #Production
  qProd['RxE',i,t]                 = sum(i_a,vY_i_d[i_a,i,t] + vM_i_d[i_a,i,t]) + vtYM_d[i,t]; # This should be good, we opted against using rows because vIO's are defined on demand_components incl. non sectors qRxE.l[i,t];
  qProd['labor',i,t]               = qL[i,t];
  qProd['iM',i,t]                  = qK['iM',i,t];
  qProd['iT',i,t]                  = qK['iT',i,t];
  qProd['iB',i,t]                  = qK['iB',i,t];
  qProd['machine_energy',i,t]      = sum((es,e)$(not (sameas[es,'Heating'] or sameas[es,'Transport'])), pEpj_base[es,e,i,t]*qEpj[es,e,i,t]);
  qProd['transport_energy',i,t]   = sum((es,e)$(sameas[es,'Transport']), pEpj_base[es,e,i,t]*qEpj[es,e,i,t]);
  qProd['heating_energy',i,t]      = sum((es,e)$(sameas[es,'heating']), pEpj_base[es,e,i,t]*qEpj[es,e,i,t]);
  pProd[factors_of_production,i,t] = 1;

#Margins 


# Factor demand
  qK_k_i[k,i,t] = qK[k,i,t]; 
  #qI_k_i[k,i,t] =qI_s.l[k,i,t]; #We read this variable directly
  qR_i[i,t] =sum(i_a,vY_i_d[i_a,i,t] + vM_i_d[i_a,i,t]) + vtYM_d[i,t]; #qRxE.l[i,t]; #sum(i_a,vY_i_d[i_a,i,t] + vM_i_d[i_a,i,t]) + vtYM_d[i,t]; #right?
  qL_i[i,t] = qL[i,t];
  qE_re_i['machine_energy',i,t]   = qProd['machine_energy',i,t];
  qE_re_i['transport_energy',i,t] = qProd['transport_energy',i,t];
  qE_re_i['heating_energy',i,t]   = qProd['heating_energy',i,t];
  qInvt_i[i,t] = 0.98;#qI_s.l['invt',i,t];

  #Retter:
  qD[re,t] = sum(i, qE_re_i[re,i,t]);



#Taxes 
  tCO2_Emarg[em,es,e,d,t] = 0.1;
  tEmarg_duty[es,e,d,t] = 0.1;

  vtE_duty[etaxes,es,e,d,t] = sum(demand_transaction, Energybalance[etaxes,demand_transaction,d,es,e,t]);
  vtE_vat[es,e,d,t]          = sum(demand_transaction, Energybalance['VAT',demand_transaction,d,es,e,t]);

  # Abatement
  theta[l,es,i,t] = sum(e, theta_load[l,es,i,e,t]);
  uTE[l,es,e,i,t] = uTE_load[l,es,i,e,t];
  uTK[l,es,i,t] = sum(e, uTK_load[l,es,i,e,t]);


execute_unloaddi "data",
  # Labor-market
  vWages_i, nL, vW
  
  # Input-output
  d, rx, re, k, c, g, x, i, m ,factors_of_production,demand_transaction
  vY_i_d, vM_i_d, vtY_i_d, vtM_i_d,
  qD

  # Factor demand
  qK_k_i, qI_k_i, qR_i, qInvt_i, qE_re_i

  es, out, e, invt,tl
  pE_avg, 
  vEAV, vDAV, vCAV,
  qProd, pProd,
  em, em_accounts, land5, qEmmE_BU, qEmmxE, qEmmLULUCF5, qEmmLULUCF, sBioNatGas, qEmmBorderTrade
  GWP,
  vtCO2_ETS, qCO2_ETS_freeallowances
  vtNetproductionRest,
  vtCAP_prodsubsidy
  pEpj_base, qEpj
  vtE_duty, vtE_vat, tCO2_Emarg, tEmarg_duty
  Energybalance, NonEnergyEmissions

  #theta, uTE, uTK,
  pEpj_base,qEpj

  vIOxE_y, vIOxE_m, vIOxE_a, vIO_y, vIO_m, vIO_a,vtYM_d
;