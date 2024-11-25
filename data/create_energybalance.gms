#Energybalance (non energy below)
  #Production (lacking renewable energy
    Energybalance['PJ','production',i,'unspecified',e,t]   = qY_CET[e,i,t];
    Energybalance['BASE','production',i,'unspecified',e,t] = pY_CET[e,i,t] * qY_CET[e,i,t];

  #Imports
    Energybalance['PJ','imports',i,'unspecified',e,t]   = qM_CET[e,i,t];
    Energybalance['BASE','imports',i,'unspecified',e,t] = pM_CET[e,i,t] * qM_CET[e,i,t];

  #Firms, input in production 
    Energybalance['PJ','input_in_production',i,es,e,t]      = qREpj[es,e,i,t];
    Energybalance['BASE','input_in_production',i,es,e,t]    = pREpj_base[es,e,i,t] * qREpj[es,e,i,t];
    Energybalance['EAV','input_in_production',i,es,e,t]     = vEAV_RE[es,e,i,t];
    Energybalance['DAV','input_in_production',i,es,e,t]     = vDAV_RE[es,e,i,t];
    Energybalance['CAV','input_in_production',i,es,e,t]     = vCAV_RE[es,e,i,t];
    Energybalance['CO2_tax','input_in_production',i,es,e,t] = vtCO2_RE[es,e,i,t];
    Energybalance['EAFG_tax','input_in_production',i,es,e,t]= vtEAFG_RE[es,e,i,t];
    Energybalance['SO2_tax','input_in_production',i,es,e,t] = vtSO2_RE[es,e,i,t];
    Energybalance['NOX_tax','input_in_production',i,es,e,t] = vtNOx_RE[es,e,i,t];
    Energybalance['PSO_tax','input_in_production',i,es,e,t] = vtPSO_RE[es,e,i,t];
    Energybalance['VAT','input_in_production',i,es,e,t]     = vtVAT_RE[es,e,i,t];

    Energybalance[em,'input_in_production',i,es,e,t] = qEmmRE_load[i,t,em,es,e];

  #Households 
    #Energy not related to transport
    Energybalance['PJ','household_consumption',c,es,e,t]      $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= qCEpj[es,e,t];
    Energybalance['BASE','household_consumption',c,es,e,t]    $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= pCEpj_base[es,e,t] * qCEpj[es,e,t];
    Energybalance['EAV','household_consumption',c,es,e,t]     $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vEAV_CE[es,e,t];
    Energybalance['DAV','household_consumption',c,es,e,t]     $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vDAV_CE[es,e,t];
    Energybalance['CAV','household_consumption',c,es,e,t]     $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vCAV_CE[es,e,t];
    Energybalance['CO2_tax','household_consumption',c,es,e,t] $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vtCO2_CE[es,e,t];
    Energybalance['EAFG_tax','household_consumption',c,es,e,t]$(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vtEAFG_CE[es,e,t];
    Energybalance['SO2_tax','household_consumption',c,es,e,t] $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vtSO2_CE[es,e,t];
    Energybalance['NOX_tax','household_consumption',c,es,e,t] $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vtNOx_CE[es,e,t];
    Energybalance['PSO_tax','household_consumption',c,es,e,t] $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vtPSO_CE[es,e,t];
    Energybalance['VAT','household_consumption',c,es,e,t]     $(sameas[c,'cHouEne'] and not sameas[es,'Transport'])= vtVAT_CE[es,e,t];

    Energybalance[em,'household_consumption',c,es,e,t]$(sameas[c,'cHouEne'] and not sameas[es,'Transport']) = qEmmCE_load[t,em,es,e];
    
    #Energy related to transport
    Energybalance['PJ','household_consumption',c,es,e,t]      $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= qCEpj[es,e,t];
    Energybalance['BASE','household_consumption',c,es,e,t]    $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= pCEpj_base[es,e,t] * qCEpj[es,e,t];
    Energybalance['EAV','household_consumption',c,es,e,t]     $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vEAV_CE[es,e,t];
    Energybalance['DAV','household_consumption',c,es,e,t]     $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vDAV_CE[es,e,t];
    Energybalance['CAV','household_consumption',c,es,e,t]     $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vCAV_CE[es,e,t];
    Energybalance['CO2_tax','household_consumption',c,es,e,t] $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vtCO2_CE[es,e,t];
    Energybalance['EAFG_tax','household_consumption',c,es,e,t]$(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vtEAFG_CE[es,e,t];
    Energybalance['SO2_tax','household_consumption',c,es,e,t] $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vtSO2_CE[es,e,t];
    Energybalance['NOX_tax','household_consumption',c,es,e,t] $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vtNOx_CE[es,e,t];
    Energybalance['PSO_tax','household_consumption',c,es,e,t] $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vtPSO_CE[es,e,t];
    Energybalance['VAT','household_consumption',c,es,e,t]     $(sameas[c,'cCarEne'] and sameas[es,'Transport'])= vtVAT_CE[es,e,t];

    Energybalance[em,'household_consumption',c,es,e,t]$(sameas[c,'cCarEne'] and sameas[es,'Transport'])     = qEmmCE_load[t,em,es,e];


  #Exports
    Energybalance['PJ','export','xOth',es,e,t]   = qXEpj[es,e,t];
    Energybalance['BASE','export','xOth',es,e,t] = pXEpj_base[es,e,t] * qXEpj[es,e,t];
    # Energybalance['CO2_tax']

  #Inventories 
    Energybalance['PJ','inventory','invt',es,e,t]   = qLEpj[es,e,t];  
    Energybalance['BASE','inventory','invt',es,e,t] = pLEpj_base[es,e,t] * qLEpj[es,e,t];

  #Transmission losses
    Energybalance['PJ','transmission_losses','tl',es,e,t] = qTLpj[es,e,t];


  #Non-energy related emissions
    NonEnergyEmissions[em,'input_in_production',i,t]           = qEmmRxE_load[i,t,em];
    NonEnergyEmissions[em,'household_consumption','cHouEne',t] = qEmmCxE_load[t,em];
