# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------

$IF %stage% == "variables":

  $SetGroup+ SG_flat_after_last_data_year 
    d1tE_duty_tot[d,t] "" 
    d1tE_vat_tot[d,t] ""
    
    d1tE_duty[etaxes,es,e,d,t] "" 
    d1tE_vat[es,e,d,t] ""  
    d1tE[es,e,d,t] ""
    d1tCO2_ETS[d,t] ""
    d1tCO2_ETS2[d,t] ""
    d1tCO2_E[em,es,e,d,t] ""
    d1tCO2_xE[d,t] ""
    d1tCO2_ETS_E[em,es,e,d,t] ""
    d1tCO2_ETS2_E[em,es,e,d,t] ""

    d1pEpj[es,e,d,t] "Dummy for priced energy. This includes if the energy does not have a base price but is taxed"
    d1tqEpj[es,e,d,t] "Dummy for non-priced energy that is taxed"

  ;

  $Group+ all_variables
    tCO2_ETS[t]                                                        "ETS1 carbon price, measured in kroner per ton CO2"
    tCO2_ETS2[t]                                                       "ETS2 carbon price, measured in kroner per ton CO2"

    tE_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t])              "Marginal duty-rates on energy input. Measured in bio. kr. per PJ energy input"
    tEmarg_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t])          "Marginal duty-rates on energy input. Measured in bio. kr. per PJ energy input"
    tE_vat[es,e,d,t]$(d1tE_vat[es,e,d,t])                              "Marginal VAT-rates per PJ energy input"
    tCO2_Emarg[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t])                    "Marginal CO2 tax per PJ energy input, measured in kroner per ton CO2"
    tCO2_Emarg_pj[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t])                 "Marginal CO2 tax per PJ energy input, measured in bio. kroner per PJ energy input"
    tCO2_xEmarg[d,t]$(d1tCO2_xE[d,t])                                  "Marginal CO2 tax per PJ energy input, measured in kroner per ton CO2"
    tCO2_ETS_pj[em,es,e,d,t]$(d1tCO2_ETS_E[em,es,e,d,t])               "ETS1 carbon price per PJ energy input, measured in kroner per ton CO2"
    tCO2_ETS2_pj[em,es,e,d,t]$(d1tCO2_ETS2_E[em,es,e,d,t])             "ETS2 carbon price per PJ energy input, measured in kroner per ton CO2"
    qEpj_duty_deductible[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t]) "Marginal duty-rates on firms energy input. Measured in bio. kr. per PJ energy input"
    qCO2_ETS_freeallowances[i,t]$(d1tCO2_ETS[i,t])                     "This one needs to have added non-energy related emissions"

		tpE_marg[es,e,d,t]$(d1pEpj_base[es,e,d,t]) 										 "Aggregate marginal tax-rate on priced energy, measured as a mark-up over base price"
		tpE[es,e,d,t]$(d1pEpj_base[es,e,d,t]) 									    	 "Aggregate average tax-rate on priced energy, measured as a mark-up over base price"
		tqE_marg[es,e,d,t]$(d1tqEpj[es,e,d,t]) 												 "Aggregate marginal tax-rate on non-priced energy, measured as bio. kroner per PJ (or equivalently 1000 DKR per GJ)" 
    tqE[es,e,d,t]$(d1tqEpj[es,e,d,t])                              "Aggregate average tax-rate on non-priced energy, measured as bio. kroner per PJ (or equivalently 1000 DKR PER GJ)"

    vtE_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t]) "Tax revenue from duties on energy"
    vtE_duty_tot[d,t]$(d1tE_duty_tot[d,t]) "Total tax revenue from duties on energy"
    vtE_vat[es,e,d,t]$(d1tE_vat[es,e,d,t]) "Tax revenue from VAT on energy"
    vtE_vat_tot[d,t]$(d1tE_vat_tot[d,t]) "Total VAT revenue from VAT on energy"
    vtE[es,e,d,t]$(sum(etaxes,d1tE_duty[etaxes,es,e,d,t]) or d1tE_vat[es,e,d,t] or sum(em, d1tCO2_ETS_E[em,es,e,d,t]) or sum(em, d1tCO2_ETS2_E[em,es,e,d,t]))     "Total tax revenue from energy"
    vtEmarg[es,e,d,t]$(sum(etaxes,d1tE_duty[etaxes,es,e,d,t]) or d1tE_vat[es,e,d,t] or sum(em, d1tCO2_ETS_E[em,es,e,d,t]) or sum(em, d1tCO2_ETS2_E[em,es,e,d,t])) "Total marginal tax revenue from energy, used to compute total bottom deductions"
    vtE_NAS[es,e,d,t]$(sum(etaxes,d1tE_duty[etaxes,es,e,d,t]) or d1tE_vat[es,e,d,t]) "Total tax revenue excluding ETS, the National Accounts demarkation"
    vtCO2_xE[d,t]$(d1tCO2_xE[d,t] and d1EmmxE['CO2ubio',d,t])      "Tax revenue from national carbon tax, non-energy related emissions"

    vtCO2_ETS[d,t]$(d1tCO2_ETS[d,t]) "Revenue from ETS1, total"
    vtCO2_ETS_E[d,t]$(d1tCO2_ETS[d,t]) "Revenue from ETS1, energy-related"
    vtCO2_ETS_xE[d,t]$(d1tCO2_ETS[d,t] and d1EmmxE['CO2ubio',d,t]) "Tax revenue from ETS1, non-energy related emissions"
    vtCO2_ETS2[d,t]$(d1tCO2_ETS2[d,t]) "Tax revenue from ETS2, total"
    vtCO2_ETS2_E[d,t]$(d1tCO2_ETS2[d,t]) "Revenue from ETS2, energy"
    vtCO2_ETS2_xE[d,t]$(d1tCO2_ETS[d,t] and d1EmmxE['CO2ubio',d,t]) "Tax revenue from ETS2, non-energy related emissions"
    vtCO2_ETS_tot[t] "Total revenue from ETS1 and ETS2"



    jvtE_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t]) "J-term to capture instances ,where data contains a revenue, but the marginal rate is zero."

    #Links 
    vtY_i_d_calib[i,d,t]$(d1Y_i_d[i,d,t]) ""
    vtM_i_d_calib[i,d,t]$(d1M_i_d[i,d,t]) ""

    adj_jvtY_i_d[t] ""
    adj_jvtM_i_d[t] ""


  ;

  $Group G_energy_taxes_data  
    vtE_duty
    vtE_vat 
    tCO2_Emarg 
    tEmarg_duty
    qCO2_ETS_freeallowances
  ;
$ENDIF 

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

$IF %stage% == "equations":

  $BLOCK energy_and_emissions_taxes energy_and_emissions_taxes_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
     #Total duties, net of bottom deductions
     ..   vtE_duty[etaxes,es,e,d,t] =E= tEmarg_duty[etaxes,es,e,d,t] * (qEpj[es,e,d,t] - qEpj_duty_deductible[etaxes,es,e,d,t]) +  jvtE_duty[etaxes,es,e,d,t];

    #Total VAT paid on energy
     ..   vtE_vat[es,e,d,t] =E= tE_vat[es,e,d,t] * (pEpj_base[es,e,d,t]*qEpj[es,e,d,t]
                                                  + sum(etaxes, tEmarg_duty[etaxes,es,e,d,t] * (qEpj[es,e,d,t] - qEpj_duty_deductible[etaxes,es,e,d,t]))
                                                  + pWMA[es,e,d,t]*qEpj[es,e,d,t]
                                                  + pRMA[es,e,d,t]*qEpj[es,e,d,t]
                                                  + pCMA[es,e,d,t]*qEpj[es,e,d,t]);

      #Total taxes on energy, excluding ETS, i.e. how it is computed in Danish National Accounts
      ..   vtE_NAS[es,e,d,t] =E= vtE_vat[es,e,d,t] 
                            + sum(etaxes, vtE_duty[etaxes,es,e,d,t])
                            ;
                            
      #Total taxes on energy, including ETS
      ..   vtE[es,e,d,t] =E= vtE_NAS[es,e,d,t]
                            + sum(em, tCO2_ETS_pj[em,es,e,d,t]*qEpj[es,e,d,t])
                            + sum(em, tCO2_ETS2_pj[em,es,e,d,t]*qEpj[es,e,d,t])
                            ; 

      #Total taxes, if marginal rates applied to all energy-use                      
      ..   vtEmarg[es,e,d,t] =E= (1+tpE_marg[es,e,d,t]) * pEpj_base[es,e,d,t] * qEpj[es,e,d,t];

      #Marginal tax-rate on priced-energy
      tpE_marg[es,e,d,t]..
        (1+tpE_marg[es,e,d,t]) * pEpj_base[es,e,d,t] 
          =E= (1+tE_vat[es,e,d,t]) * (pEpj_base[es,e,d,t]
                                      + sum(etaxes, tEmarg_duty[etaxes,es,e,d,t]) #Marginal domestic CO2-tax is contained in tEmarg_duty
                                      + pWMA[es,e,d,t]
                                      + pRMA[es,e,d,t]
                                      + pCMA[es,e,d,t])
                                      + sum(em, tCO2_ETS_pj[em,es,e,d,t])
                                      + sum(em, tCO2_ETS2_pj[em,es,e,d,t])
                                      ;     
                                         
      #Average tax-rate on energy
      tpE[es,e,d,t]..
         (1+tpE[es,e,d,t]) * pEpj_base[es,e,d,t] * qEpj[es,e,d,t]
          =E= vEpj[es,e,d,t];
      
      #Marginal tax-rate on non-priced energy
      tqE_marg[es,e,d,t]..
        tqE_marg[es,e,d,t] 
          =E= sum(etaxes, tEmarg_duty[etaxes,es,e,d,t])
             +sum(em, tCO2_ETS_pj[em,es,e,d,t])
             +sum(em, tCO2_ETS2_pj[em,es,e,d,t]);

      tqE[es,e,d,t]..
        tqE[es,e,d,t] =E= sum(etaxes,vtE_duty[etaxes,es,e,d,t]/qEpj[es,e,d,t]) 
                        + sum(em, tCO2_ETS_pj[em,es,e,d,t])
                        + sum(em, tCO2_ETS2_pj[em,es,e,d,t]);

        #CO2-taxes based on emissions (currently only industries) 
          #Domestic CO2-tax                                                                                                                                                                                     #AKB: Depending on how EOP-abatement i modelled this should be adjusted for EOP
          tCO2_Emarg_pj&_notNatgas[em,es,e,i,t]$(not natgas[e]).. tCO2_Emarg_pj[em,es,e,i,t] =E= tCO2_Emarg[em,es,e,i,t] /10**6 * uEmmE_BU[em,es,e,i,t];

          #Consider removing as emission coefficient is the same for ubio/bio
          tCO2_Emarg_pj&_NatgasBio[em,es,e,i,t]$(natgas[e] and CO2bio[em]).. 
            tCO2_Emarg_pj[em,es,e,i,t] =E= tCO2_Emarg[em,es,e,i,t] /10**6 * uEmmE_BU[em,es,e,i,t] * sBioNatGas[t]; 

          tCO2_Emarg_pj&_NatgasuBio[em,es,e,i,t]$(natgas[e] and CO2ubio[em]).. 
              tCO2_Emarg_pj[em,es,e,i,t] =E= tCO2_Emarg[em,es,e,i,t] /10**6 * uEmmE_BU[em,es,e,i,t] * (1-sBioNatGas[t]); 

          #Linking to per PJ tax-rate (currently only industries)   #AKB: Kan ikke fjerne dummies her, undersøg hvorfor
          tEmarg_duty[etaxes,es,e,i,t]$(sum(em,d1tCO2_E[em,es,e,i,t]) and d1tE_duty[etaxes,es,e,i,t] and CO2_tax[etaxes]).. 
            tEmarg_duty[etaxes,es,e,i,t] =E= sum(em$(d1tCO2_E[em,es,e,i,t]), tCO2_Emarg_pj[em,es,e,i,t]); 

          #Non-energy related emissions
          .. vtCO2_xE[d,t] =E=  tCO2_xEmarg[d,t]/10**6 * qEmmxE['CO2ubio',d,t];

        #ETS1
          #Energy
          tCO2_ETS_pj&_notNatgas[em,es,e,i,t]$(d1tCO2_ETS_E[em,es,e,i,t] and not natgas[e]).. #Kan heller ikke umiddelbart fjerne disse dummies
            tCO2_ETS_pj[em,es,e,i,t] =E= tCO2_ETS[t]/10**6 * uEmmE_BU[em,es,e,i,t];

          tCO2_ETS_pj&_NatgasBio[em,es,e,i,t]$(d1tCO2_ETS_E[em,es,e,i,t] and natgas[e] and CO2bio[em])..
            tCO2_ETS_pj[em,es,e,i,t] =E= tCO2_ETS[t]/10**6 * uEmmE_BU[em,es,e,i,t] * sBioNatGas[t];

          tCO2_ETS_pj&_NatgasuBio[em,es,e,i,t]$(d1tCO2_ETS_E[em,es,e,i,t] and natgas[e] and CO2ubio[em])..
            tCO2_ETS_pj[em,es,e,i,t] =E= tCO2_ETS[t]/10**6 * uEmmE_BU[em,es,e,i,t] * (1-sBioNatGas[t]);

          
          .. vtCO2_ETS_E[i,t] =E= sum((em,es,e), tCO2_ETS_pj[em,es,e,i,t] * qEpj[es,e,i,t]);
          
          #Non-energy   
            ..  vtCO2_ETS_xE[i,t] =E= tCO2_ETS[t]/10**6 * qEmmxE['CO2ubio',i,t];

          #Total revenue from ET1
            .. vtCO2_ETS[i,t] =E= vtCO2_ETS_E[i,t] + vtCO2_ETS_xE[i,t] - tCO2_ETS[t]/10**6 * qCO2_ETS_freeallowances[i,t]; 

        #ETS2 (note that whereas ETS1 is only households, ETS2 extends to households as well)
          tCO2_ETS2_pj&_notNatgas[em,es,e,d,t]$(not natgas[e])..
            tCO2_ETS2_pj[em,es,e,d,t] =E= tCO2_ETS2[t]/10**6 * uEmmE_BU[em,es,e,d,t];

          tCO2_ETS2_pj&_NatgasBio[em,es,e,d,t]$(natgas[e] and CO2bio[em])..
            tCO2_ETS2_pj[em,es,e,d,t] =E= tCO2_ETS2[t]/10**6 * uEmmE_BU[em,es,e,d,t] * sBioNatGas[t];

          tCO2_ETS2_pj&_NatgasuBio[em,es,e,d,t]$(natgas[e] and CO2ubio[em])..
            tCO2_ETS2_pj[em,es,e,d,t] =E= tCO2_ETS2[t]/10**6 * uEmmE_BU[em,es,e,d,t] * (1-sBioNatGas[t]);

          .. vtCO2_ETS2_E[d,t] =E= sum((em,es,e), tCO2_ETS2_pj[em,es,e,d,t] * qEpj[es,e,d,t]);

          .. vtCO2_ETS2[d,t] =E= vtCO2_ETS2_E[d,t] + vtCO2_ETS2_xE[d,t];

  $ENDBLOCK           

  $BLOCK energy_and_emissions_taxes_links energy_and_emissions_taxes_links_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    #Bottom deductions (we meausure with positive sign and deduct them in production.gms)
      vtBotded[i,t]$(d1Y_i[i,t])..
        vtBotded[i,t] =E= sum((es,e), vtEmarg[es,e,i,t] - vtE[es,e,i,t])
                        + tCO2_ETS[t]/10**6 * qCO2_ETS_freeallowances[i,t]; 

    #Non-energy related taxes
      vtEmmRxE[i,t]$(d1Y_i[i,t])..
        vtEmmRxE[i,t] =E=  vtCO2_xE[i,t] + vtCO2_ETS_xE[i,t];


    ..    vtE_duty_tot[d,t] =E= sum((etaxes,es,e), vtE_duty[etaxes,es,e,d,t]);

    ..    vtE_vat_tot[d,t] =E= sum((es,e), vtE_vat[es,e,d,t]);

    #Taxes 
    tY_i_d&_not_energymargins[i,d,t]$(d1Y_i_d[i,d,t] and not i_energymargins[i] and d_ene[d])..
						vtY_i_d[i,d,t]
							=E=   sum((e,es,d_a)$es_d2d(es,d_a,d),  sSupply_d_e_i_adj[d,e,i,t] * vte_NAS[es,e,d_a,t]) 
                  # + sum((e,es,d_a)$(es_d2d(es,d_a,d) and d1pY_CET[e,i,t] and d1tqEpj[es,e,d_a,t]), vte_NAS[es,e,d_a,t]) #Allocating energy-taxes on non-priced energy
                  + vtY_i_d_calib[i,d,t]; 

    tY_i_d&energymargins[i,d,t]$(d1Y_i_d[i,d,t] and i_energymargins[i] and d_ene[d])..
						vtY_i_d[i,d,t]
							=E= sum((e,es,d_a)$es_d2d(es,d_a,d),  sSupply_d_e_i_adj[d,e,i,t] * vte_NAS[es,e,d_a,t]) + vtY_i_d_calib[i,d,t]; 

    tM_i_d&_not_energymargins[i,d,t]$(d1M_i_d[i,d,t] and not i_energymargins[i] and d_ene[d])..
						vtM_i_d[i,d,t]
							=E=   sum((e,es,d_a)$es_d2d(es,d_a,d),  (1-sum(i_a,sSupply_d_e_i_adj[d,e,i_a,t])) * vte_NAS[es,e,d_a,t]) 
                  # + sum((e,es,d_a)$(es_d2d(es,d_a,d) and d1pM_CET[e,i,t] and not d1pY_CET[e,i,t] and d1tqEpj[es,e,d_a,t]), vte_NAS[es,e,d_a,t]) #Allocating energy-taxes on non-priced energy
                  + vtM_i_d_calib[i,d,t]; 


  $ENDBLOCK

  model main / 
          energy_and_emissions_taxes
          energy_and_emissions_taxes_links
            /;
  $Group+ main_endogenous 
    energy_and_emissions_taxes_endogenous
    energy_and_emissions_taxes_links_endogenous
  ;

$ENDIF

# ------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------

$IF %stage% == "exogenous_values":

  @inf_growth_adjust()
  @load(G_energy_taxes_data, %path_data%)
  @remove_inf_growth_adjustment()
  $Group+ data_covered_variables G_energy_taxes_data$(t.val <= %calibration_year%), -tEmarg_duty,-tCO2_Emarg; #Find ud af hvad, der går galt med de to her


  # ------------------------------------------------------------------------------
  # Initial values 
  # ------------------------------------------------------------------------------

   tCO2_ETS.l[t] = 750;
   tCO2_ETS2.l[t] = 375; 

   tCO2_xEmarg.l['23001',t] = 125;
   tCO2_xEmarg.l['23002',t] = 125;


   
  # ------------------------------------------------------------------------------
  # Dummies 
  # ------------------------------------------------------------------------------
    
    d1tE_duty[etaxes,es,e,d,t] = yes$((vtE_duty.l[etaxes,es,e,d,t] or (sameas[etaxes,'co2_tax'] and sum(em,tCO2_Emarg.l[em,es,e,d,t]))) and d1qEpj[es,e,d,t]);
    d1tE_duty_tot[d,t]         = yes$(sum((etaxes,es,e), d1tE_duty[etaxes,es,e,d,t]));
    d1tE_vat[es,e,d,t]         = yes$(vtE_vat.l[es,e,d,t] and pEpj_base.l[es,e,d,t]);
    d1tE_vat_tot[d,t]          = yes$(sum((es,e), d1tE_vat[es,e,d,t]));
 
    d1tCO2_E[em,es,e,d,t]      = yes$(tCO2_Emarg.l[em,es,e,d,t] and qEpj.l[es,e,d,t]);
    d1tCO2_xE[d,t]             = yes$(tCO2_xEmarg.l[d,t]);
    d1tCO2_ETS_E[em,es,e,d,t]  = yes$(qEmmE_BU.l[em,es,e,d,t] and CO2ubio[em] and qEpj.l[es,e,d,t] and in_ETS[es]);
    d1tCO2_ETS_E[em,es,e,d,t]$(qEmmE_BU.l[em,es,e,d,t] and CO2bio[em] and qEpj.l[es,e,d,t] and in_ETS[es] and natgas[e]) = yes;
    d1tCO2_ETS[i,t]             = yes$(sum((em,es,e), d1tCO2_ETS_E[em,es,e,i,t]));

    d1tCO2_ETS2_E[em,es,e,d,t]  = yes$(qEmmE_BU.l[em,es,e,d,t] and CO2ubio[em] and qEpj.l[es,e,d,t] and not in_ETS[es]);
    d1tCO2_ETS2_E[em,es,e,d,t]$(qEmmE_BU.l[em,es,e,d,t] and CO2bio[em] and qEpj.l[es,e,d,t] and not in_ETS[es] and natgas[e]) = yes;

    d1tE[es,e,d,t]             = yes$((sum(etaxes,d1tE_duty[etaxes,es,e,d,t])  or d1tE_vat[es,e,d,t] or sum(em,d1tCO2_ETS_E[em,es,e,d,t]) or sum(em, d1tCO2_ETS2_E[em,es,e,d,t])) and (pEpj_base.l[es,e,d,t] or pEpj_own.l[es,e,d,t]));
    d1tqEpj[es,e,d,t]          = yes$((sum(etaxes, d1tE_duty[etaxes,es,e,d,t]) or sum(em,d1tCO2_ETS_E[em,es,e,d,t]) or sum(em, d1tCO2_ETS2_E[em,es,e,d,t])) and d1qEpj[es,e,d,t] and not (pEpj_base.l[es,e,d,t] or pEpj_own.l[es,e,d,t]));

    d1pEpj[es,e,d,t]           = yes$(d1pEpj_base[es,e,d,t] or d1tqEpj[es,e,d,t] or d1pEpj_own[es,e,d,t]); #There is a price if a) There is a base-price or b) if the energy-good is taxed.

    #From production_CES_energydemand.gms
    d1pREa_NotinNest[es,e_a,i,t]$(d1pEpj[es,e_a,i,t] and process_special[es] and crudeoil[e_a] and i_refineries[i]) = yes; #Refinery feedstock of crude oil
	  d1pREa_NotinNest[es,e_a,i,t]$(d1pEpj[es,e_a,i,t] and process_special[es] and natgas_ext[e_a] and i_gasdistribution[i]) = yes; #Input of fossile natural gas in gas distribution sector
	  d1pREa_NotinNest[es,e_a,i,t]$(d1pEpj[es,e_a,i,t] and process_special[es] and biogas[e_a] and i_gasdistribution[i]) = yes; #Input of biogas for converting to natural gas in gas distribution sector
	  d1pREa_NotinNest[es,e_a,i,t]$(d1pEpj[es,e_a,i,t] and process_special[es] and el[e_a] and i_service_for_industries[i]) = yes; #Electricity for data centers (only applies when calibrated to Climate Outlook)

	  d1pREa_inNest[es,e_a,i,t]    = yes$(d1pEpj[es,e_a,i,t] and not d1pREa_NotinNest[es,e_a,i,t]);
	  d1pREa[es,e_a,i,t]           = yes$(d1pREa_inNest[es,e_a,i,t] or d1pREa_NotinNest[es,e_a,i,t]);

	  d1pEes[es,i,t] 			 				 = yes$(sum(e_a, d1pREa_inNest[es,e_a,i,t]));	
	  d1pREmachine[i,t]            = yes$(sum(es$(not (heating[es] or transport[es])), d1pEes[es,i,t]));
	  d1Prod[pf,i,t]               = yes$(pProd.l[pf,i,t]);


$ENDIF
# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":
  $BLOCK energy_and_emissions_taxes_calibration energy_and_emissions_taxes_calibration_endogenous $(t1.val <= t.val and t.val <=tEnd.val)
    vtY_i_d_calib[i,d,t]$(t.val > t1.val and d1Y_i_d[i,d,t] and not i_energymargins[i] and d_ene[d])..
      vtY_i_d_calib[i,d,t] =E= 0;

    vtY_i_d_calib&_energymargins[i,d,t]$(t.val > t1.val and d1Y_i_d[i,d,t] and i_energymargins[i] and d_ene[d])..
      vtY_i_d_calib[i,d,t] =E= 0;

    vtM_i_d_calib[i,d,t]$(t.val > t1.val and d1M_i_d[i,d,t] and d_ene[d])..
      vtM_i_d_calib[i,d,t] =E= 0;

  $ENDBLOCK 

  # Add equations and calibration equations to calibration model
  model calibration /
    energy_and_emissions_taxes
    energy_and_emissions_taxes_links
    energy_and_emissions_taxes_calibration
  /;

  # Add endogenous variables to calibration model
  $Group calibration_endogenous
    energy_and_emissions_taxes_endogenous 
    -vtE_duty[etaxes,es,e,d,t1], tEmarg_duty[etaxes,es,e,d,t1]
    -tEmarg_duty['ener_tax',es,e,i,t1]$(d1tE_duty['ener_tax',es,e,i,t1] and tEmarg_duty.l['ener_tax',es,e,i,t1] <>0), qEpj_duty_deductible['ener_tax',es,e,i,t1]$(d1tE_duty['ener_tax',es,e,i,t1] and tEmarg_duty.l['ener_tax',es,e,i,t1] <>0)
    -tEmarg_duty['ener_tax',es,e,i,t1]$(d1tE_duty['ener_tax',es,e,i,t1] and tEmarg_duty.l['ener_tax',es,e,i,t1] =0), jvtE_duty['ener_tax',es,e,i,t1]$(d1tE_duty['ener_tax',es,e,i,t1] and tEmarg_duty.l['ener_tax',es,e,i,t1] =0)
    -vtE_vat[es,e,d,t1], tE_vat[es,e,d,t1]

    qEpj_duty_deductible[etaxes,es,e,d,t1]$(d1tE_duty[etaxes,es,e,d,t] and CO2_tax[etaxes] and sum(em,d1tCO2_E[em,es,e,d,t]) and i[d])

    energy_and_emissions_taxes_links_endogenous

    energy_and_emissions_taxes_calibration_endogenous
    vtY_i_d[i,d,t]$(d1Y_i_d[i,d,t] and not i_energymargins[i] and d_ene[d] and t1[t])
    vtY_i_d[i,d,t]$(d1Y_i_d[i,d,t] and i_energymargins[i] and d_ene[d] and t1[t])
    vtM_i_d[i,d,t]$(d1M_i_d[i,d,t] and not i_energymargins[i] and d_ene[d] and t1[t])
    
    calibration_endogenous
  ;
$ENDIF