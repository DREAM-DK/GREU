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
Alias(d,d_a);
Set i_; #sectors incl. tot
Set i(d); #sectors w.o. tot
Alias(i,i_a);
Set c(d); #private consumption
Set x(d); #export
Set g(d); #public final consumption
Set rx(d); #currently equal to i
Set re(d); #energy intermediate input
Set invt(d); #inventories
Set invt_ene(d)
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
  vIOE_y[i,d,t]
  vIOE_m[i,d,t]
  vIOE_a[a_rows_,d,t]

  nEmployed[t]
  qL[i,t]
  qK[k,i,t]
  qI_k_i[k,i,t]
  qCO2_ETS_freeallowances[i,t]
  qEmmLULUCF[t]
  qEmmBorderTrade[em,t]
  Energybalance[ebalitems,transaction,d,es,e,t] "Main data input with regards to energy and energy-related emissions"
  NonEnergyEmissions[ebalitems,transaction,d,t] "Main data input with regards to non-energy related emissions"
  ImportShareEnergy[e,t] "Import share"
  Share_re[re,e,t] ""
  FinalPurposeSharesSectors[re,t] ""
  vIOE_y_computed[i,d,t] ""
  vIOE_m_computed[i,d,t] ""
  vIOE_a_computed[a_rows_,d,t] ""

;
$gdxin dataa_ny.gdx
$load d,i,c,x,g,rx,re,invt,invt_ene,tl,out,e,t,t1,land5,em_accounts,i_,k_
$load factors_of_production, k, ebalitems, em,etaxes,a_rows_,transaction,demand_transaction,es
$load vIO_y=vIO_y.l, vIO_m=vIO_m.l, vIOxE_y=vIOxE_y.l, vIOxE_m=vIOxE_m.l, vIO_a=vIO_a.l,vIOxE_a=vIOxE_a.l
$load nEmployed=nEmployed.l, qL=qL.l, qK=qK.l, qI_k_i=qI_k_i.l
$load qEmmLULUCF=qEmmLULUCF.l,qEmmBorderTrade=qEmmBorderTrade.l,qCO2_ETS_freeallowances=qCO2_ETS_freeallowances.l
$load Energybalance=Energybalance.l
$load NonEnergyEmissions=NonEnergyemissions.l

#Energy-IO
vIOE_y[i,d,t]         = vIO_y[i,d,t] - vIOxE_y[i,d,t];
vIOE_m[i,d,t]         = vIO_m[i,d,t] - vIOxE_m[i,d,t];
vIOE_a[a_rows_,d,t]   = vIO_a[a_rows_,d,t] - vIOxE_a[a_rows_,d,t];

vIOE_y[i,'xENE',t] = vIOE_y[i,'xOth',t]; vIOE_y[i,'xOth',t] = 0; 
vIOE_m[i,'xENE',t] = vIOE_m[i,'xOth',t]; vIOE_m[i,'xOth',t] = 0;
vIOE_a[a_rows_,'xENE',t] =vIOE_a[a_rows_,'xOth',t]; vIOE_a[a_rows_,'xOth',t] = 0;

vIOE_y[i,'invt_ene',t] = vIOE_y[i,'invt',t]; vIOE_y[i,'invt',t] = 0; 
vIOE_m[i,'invt_ene',t] = vIOE_m[i,'invt',t]; vIOE_m[i,'invt',t] = 0;
vIOE_a[a_rows_,'invt_ene',t] =vIOE_a[a_rows_,'invt',t]; vIOE_a[a_rows_,'invt',t] = 0;

#Inserting energy-inputs into IO
vIO_y[i,'xENE',t] = vIOE_y[i,'xENE',t]; 
vIO_m[i,'xENE',t] = vIOE_m[i,'xENE',t]; 
vIO_a[a_rows_,'xENE',t] = vIO_a[a_rows_,'xENE',t];

vIO_y[i,'xOth',t] = vIO_y[i,'xOth',t] - vIOE_y[i,'xENE',t]; 
vIO_m[i,'xOth',t] = vIO_m[i,'xOth',t] - vIOE_m[i,'xENE',t]; 
vIO_a[a_rows_,'xOth',t] = vIO_a[a_rows_,'xOth',t] - vIO_a[a_rows_,'xENE',t];

vIO_y[i,'invt_ene',t] = vIOE_y[i,'invt_ene',t]; 
vIO_m[i,'invt_ene',t] = vIOE_m[i,'invt_ene',t]; 
vIO_a[a_rows_,'invt_ene',t] = vIO_a[a_rows_,'invt_ene',t];

vIO_y[i,'invt',t] = vIO_y[i,'invt',t] - vIOE_y[i,'invt_ene',t]; 
vIO_m[i,'invt',t] = vIO_m[i,'invt',t] - vIOE_m[i,'invt_ene',t]; 
vIO_a[a_rows_,'invt',t] = vIO_a[a_rows_,'invt',t] - vIO_a[a_rows_,'invt_ene',t];

#Aligning energybalance with Energy-IO with respect to car dealerships margins on energy
Energybalance['CAV',transaction,d,es,e,t]$sum(d_a, vIOE_y['45000',d_a,t] + vIOE_y['47000',d_a,t]) 
  = Energybalance['DAV',transaction,d,es,e,t] * sum(d_a, vIOE_y['45000',d_a,t])/sum(d_a, vIOE_y['45000',d_a,t] + vIOE_y['47000',d_a,t]);

Energybalance['DAV',transaction,d,es,e,t] = Energybalance['DAV',transaction,d,es,e,t] - Energybalance['CAV',transaction,d,es,e,t];

#Should be moved to data treatment
ImportShareEnergy[e,t]$(sum((d,es), Energybalance['BASE','Imports',d,es,e,t] + Energybalance['BASE','production',d,es,e,t] + Energybalance['BASE','other_supply',d,es,e,t])) 
                        = sum((d,es), Energybalance['BASE','Imports',d,es,e,t])/
                          sum((d,es), Energybalance['BASE','Imports',d,es,e,t] + Energybalance['BASE','production',d,es,e,t] + Energybalance['BASE','other_supply',d,es,e,t]);

set es_transport[es]/'transport'/;
set es_machine[es]/'process_normal','process_special','in_ETS'/;
set es_heating[es]/'heating'/;

#BASE
$FOR {item} in ['BASE','DAV','EAV','CAV']:
  
  $IF '{item}'=='BASE':
  Share_re['transport_energy',e,t]$(sum((es,d), Energybalance['{item}','input_in_production',d,es,e,t])) 
                      = sum((es_transport,d), Energybalance['{item}','input_in_production',d,es_transport,e,t])
                                  /sum((es,d), Energybalance['{item}','input_in_production',d,es,e,t]);

  Share_re['machine_energy',e,t]$(sum((es,d), Energybalance['{item}','input_in_production',d,es,e,t])) 
                      = sum((es_machine,d), Energybalance['{item}','input_in_production',d,es_machine,e,t])
                                  /sum((es,d), Energybalance['{item}','input_in_production',d,es,e,t]);

  Share_re['heating_energy',e,t]$(sum((es,d), Energybalance['{item}','input_in_production',d,es,e,t])) 
                      = sum((es_heating,d), Energybalance['{item}','input_in_production',d,es_heating,e,t])
                                  /sum((es,d), Energybalance['{item}','input_in_production',d,es,e,t]);

  vIOE_y_computed[i,re,t] = sum((e,es), Energybalance['{item}','production',i,es,e,t] * Share_re[re,e,t]);
  vIOE_y_computed[i,re,t] = sum((e,es), Energybalance['{item}','production',i,es,e,t] * Share_re[re,e,t]);
  vIOE_y_computed[i,re,t] = sum((e,es), Energybalance['{item}','production',i,es,e,t] * Share_re[re,e,t]);

  vIOE_m_computed[i,re,t] = sum((e,es), Energybalance['{item}','production',i,es,e,t] * Share_re[re,e,t]);
  vIOE_m_computed[i,re,t] = sum((e,es), Energybalance['{item}','production',i,es,e,t] * Share_re[re,e,t]);
  vIOE_m_computed[i,re,t] = sum((e,es), Energybalance['{item}','production',i,es,e,t] * Share_re[re,e,t]);
  $ENDIF 

  $IF '{item}'!='BASE':
    $IF1 '{item}'=='DAV':
      vIOE_y_computed['46000','transport_energy',t] = sum((e,i,es_transport,transaction), Energybalance['{item}',transaction,i,es_transport,e,t]);
      vIOE_y_computed['46000','machine_energy',t]   = sum((e,i,es_machine,transaction), Energybalance['{item}',transaction,i,es_machine,e,t]);
      vIOE_y_computed['46000','heating_energy',t]   = sum((e,i,es_heating,transaction), Energybalance['{item}',transaction,i,es_heating,e,t]);
    $ENDIF1

    $IF1 '{item}'=='EAV':
      vIOE_y_computed['47000','transport_energy',t] = sum((e,i,es_transport,transaction), Energybalance['{item}',transaction,i,es_transport,e,t]);
      vIOE_y_computed['47000','machine_energy',t]   = sum((e,i,es_machine,transaction), Energybalance['{item}',transaction,i,es_machine,e,t]);
      vIOE_y_computed['47000','heating_energy',t]   = sum((e,i,es_heating,transaction), Energybalance['{item}',transaction,i,es_heating,e,t]);
    $ENDIF1

    $IF1 '{item}'=='CAV':
      vIOE_y_computed['45000','transport_energy',t] = sum((e,i,es_transport,transaction), Energybalance['{item}',transaction,i,es_transport,e,t]);
      vIOE_y_computed['45000','machine_energy',t]   = sum((e,i,es_machine,transaction), Energybalance['{item}',transaction,i,es_machine,e,t]);
      vIOE_y_computed['45000','heating_energy',t]   = sum((e,i,es_heating,transaction), Energybalance['{item}',transaction,i,es_heating,e,t]);
    $ENDIF1
  $ENDIF
$ENDFOR

  vIOE_a_computed['TaxSub','transport_energy',t] = sum((es_transport,i,e), EnergyBalance['ener_tax','input_in_production',i,es_transport,e,t] 
                                                                      +  EnergyBalance['co2_tax','input_in_production',i,es_transport,e,t]
                                                                      +  EnergyBalance['nox_tax','input_in_production',i,es_transport,e,t]
                                                                      +  EnergyBalance['pso_tax','input_in_production',i,es_transport,e,t]
                                                                      +  EnergyBalance['so2_tax','input_in_production',i,es_transport,e,t]);

  vIOE_a_computed['TaxSub','heating_energy',t] = sum((es_heating,i,e), EnergyBalance['ener_tax','input_in_production',i,es_heating,e,t] 
                                                                      +  EnergyBalance['co2_tax','input_in_production',i,es_heating,e,t]
                                                                      +  EnergyBalance['nox_tax','input_in_production',i,es_heating,e,t]
                                                                      +  EnergyBalance['pso_tax','input_in_production',i,es_heating,e,t]
                                                                      +  EnergyBalance['so2_tax','input_in_production',i,es_heating,e,t]);

  vIOE_a_computed['TaxSub','machine_energy',t] = sum((es_machine,i,e), EnergyBalance['ener_tax','input_in_production',i,es_machine,e,t] 
                                                                      +  EnergyBalance['co2_tax','input_in_production',i,es_machine,e,t]
                                                                      +  EnergyBalance['nox_tax','input_in_production',i,es_machine,e,t]
                                                                      +  EnergyBalance['pso_tax','input_in_production',i,es_machine,e,t]
                                                                      +  EnergyBalance['so2_tax','input_in_production',i,es_machine,e,t]);



  vIOE_a_computed['Moms','transport_energy',t] = sum((es_transport,i,e), EnergyBalance['ener_tax','input_in_production',i,es_transport,e,t]);
  vIOE_a_computed['Moms','heating_energy',t]   = sum((es_heating,i,e), EnergyBalance['ener_tax','input_in_production',i,es_heating,e,t]);
  vIOE_a_computed['Moms','machine_energy',t]   = sum((es_machine,i,e), EnergyBalance['ener_tax','input_in_production',i,es_machine,e,t]);

#We can now add energy-IO to our IO-matrix
vIO_y[i,re,t] = vIOE_y_computed[i,re,t];
vIO_m[i,re,t] = vIOE_m_computed[i,re,t];
vIO_a[a_rows_,re,t] = vIOE_a_computed[a_rows_,re,t];

vIO_y[i,re,'2019']       = vIOE_y_computed[i,re,'2020'];
vIO_m[i,re,'2019']       = vIOE_m_computed[i,re,'2020'];
vIO_a[a_rows_,re,'2019'] = vIOE_a_computed[a_rows_,re,'2020'];


m[i] = yes$sum((d,t1), vIO_m[i,d,t1]);


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
  qInvt_ene_i[i,t] "Inventory investments by industry."
  qE_re_i[re,i,t] "Energy demand from industry i, split on energy-types re"

  #Energy and emissions.
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

#Demand-components, total
vD[d,t] = sum(i, vY_i_d[i,d,t] + vM_i_d[i,d,t]);

#Taxes by demand component
vtYM_d[d,t]       = vIO_a["TaxSub",d,t] + vIO_a["Moms",d,t];

#Assume same tax-rates per IO-cell
vtY_i_d[i,d,t]$vD[d,t] = vY_i_d[i,d,t] / vD[d,t] * vtYM_d[d,t]; 
vtM_i_d[i,d,t]$vD[d,t] = vM_i_d[i,d,t] / vD[d,t] * vtYM_d[d,t]; 

#We normalize prices to 1 and load quantities into model
qD[d,t] = vD[d,t];


#Energy and emissions.
  #$import create_energybalance.gms #Here GreenREFORM variables are combine to create the full energybalance as we would preferably receive it from the Statistical Office.

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
  qK_k_i[k,i,t] = qK[k,i,t]; qK_k_i[k,i,t] = qK_k_i[k,i,'2020'];
  #qI_k_i[k,i,t] =qI_s.l[k,i,t]; #We read this variable directly
  qR_i[i,t] =sum(i_a,vY_i_d[i_a,i,t] + vM_i_d[i_a,i,t]) + vtYM_d[i,t]; #qRxE.l[i,t]; #sum(i_a,vY_i_d[i_a,i,t] + vM_i_d[i_a,i,t]) + vtYM_d[i,t]; #right?
  qL_i[i,t] = qL[i,t];
  qE_re_i['machine_energy',i,t]   = qProd['machine_energy',i,t];      #qE_re_i['machine_energy',i,'2019']   = qProd['machine_energy',i,'2020'];
  qE_re_i['transport_energy',i,t] = qProd['transport_energy',i,t];    #qE_re_i['transport_energy',i,'2019'] = qProd['transport_energy',i,'2020'];
  qE_re_i['heating_energy',i,t]   = qProd['heating_energy',i,t];      #qE_re_i['heating_energy',i,'2019']   = qProd['heating_energy',i,'2020'];
  qInvt_i[i,t] = vY_i_d[i,'invt',t] + vM_i_d[i,'invt',t] + vtYM_d['invt',t];
  qInvt_ene_i[i,t] = vY_i_d[i,'invt_ene',t] + vM_i_d[i,'invt_ene',t] + vtYM_d['invt_ene',t];

  #Retter:
  # qD[re,t] = sum(i, qE_re_i[re,i,t]);
  # vD[re,'2019'] = qD[re,'2020']



#Taxes 
  tCO2_Emarg[em,es,e,d,t] = 0.1;
  tEmarg_duty[es,e,d,t] = 0.1;

  vtE_duty[etaxes,es,e,d,t] = sum(demand_transaction, Energybalance[etaxes,demand_transaction,d,es,e,t]);
  vtE_vat[es,e,d,t]          = sum(demand_transaction, Energybalance['VAT',demand_transaction,d,es,e,t]);

  # Abatement
  theta[l,es,i,t] = sum(e, theta_load[l,es,i,e,t]);
  uTE[l,es,e,i,t] = uTE_load[l,es,i,e,t];
  uTK[l,es,i,t] = sum(e, uTK_load[l,es,i,e,t]);


execute_unload 'data'

# execute_unloaddi "data",
#   # Labor-market
#   vIOE_y, vIOE_m, vIOE_a
#   vWages_i, nL, vW
  
#   # Input-output
#   d, rx, re, k, c, g, x, i, m ,factors_of_production,demand_transaction
#   vY_i_d, vM_i_d, vtY_i_d, vtM_i_d,
#   qD

#   # Factor demand
#   qK_k_i, qI_k_i, qR_i, qInvt_i, qE_re_i

#   es, out, e, invt,tl
#   pE_avg, 
#   vEAV, vDAV, vCAV,
#   qProd, pProd,
#   em, em_accounts, land5, qEmmE_BU, qEmmxE, qEmmLULUCF5, qEmmLULUCF, sBioNatGas, qEmmBorderTrade
#   GWP,
#   vtCO2_ETS, qCO2_ETS_freeallowances
#   vtNetproductionRest,
#   vtCAP_prodsubsidy
#   pEpj_base, qEpj
#   vtE_duty, vtE_vat, tCO2_Emarg, tEmarg_duty
#   Energybalance, NonEnergyEmissions

#   #theta, uTE, uTK,
#   pEpj_base,qEpj

#   vIOxE_y, vIOxE_m, vIOxE_a, vIO_y, vIO_m, vIO_a,vtYM_d
# ;