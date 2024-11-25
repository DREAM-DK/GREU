# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
  
  $SetGroup SG_energy_taxes_dummies 
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
  ;

  $SetGroup SG_energy_taxes_flat_dummies 
    SG_energy_taxes_dummies
  ;

  $SetGroup+ SG_flat_after_last_data_year
    SG_energy_taxes_flat_dummies
  ;

  $Group G_energy_taxes_rates
    tCO2_ETS[t]                                               "ETS1 carbon price, measured in kroner per ton CO2"
    tCO2_ETS2[t]                                              "ETS2 carbon price, measured in kroner per ton CO2"

    tE_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t])     "Marginal duty-rates on energy input. Measured in bio. kr. per PJ energy input"
    tEmarg_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t]) "Marginal duty-rates on energy input. Measured in bio. kr. per PJ energy input"
    tE_vat[es,e,d,t]$(d1tE_vat[es,e,d,t])                     "Marginal VAT-rates per PJ energy input"
    tCO2_Emarg[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t])           "Marginal CO2 tax per PJ energy input, measured in kroner per ton CO2"
    tCO2_Emarg_pj[em,es,e,d,t]$(d1tCO2_E[em,es,e,d,t])        "Marginal CO2 tax per PJ energy input, measured in bio. kroner per PJ energy input"
    tCO2_xEmarg[d,t]$(d1tCO2_xE[d,t])                         "Marginal CO2 tax per PJ energy input, measured in kroner per ton CO2"
    tCO2_ETS_pj[em,es,e,d,t]$(d1tCO2_ETS_E[em,es,e,d,t])      "ETS1 carbon price per PJ energy input, measured in kroner per ton CO2"
    tCO2_ETS2_pj[em,es,e,d,t]$(d1tCO2_ETS2_E[em,es,e,d,t])    "ETS2 carbon price per PJ energy input, measured in kroner per ton CO2"

  ;

    $Group G_energy_taxes_quantities
    qEpj_duty_deductible[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t]) "Marginal duty-rates on firms energy input. Measured in bio. kr. per PJ energy input"
    qCO2_ETS_freeallowances[i,t]$(d1tCO2_ETS[i,t]) "This one needs to have added non-energy related emissions"
  ;

  $Group G_energy_taxes_values 

    vtE_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t]) "Tax revenue from duties on energy"
    vtE_duty_tot[d,t]$(d1tE_duty_tot[d,t]) "Total tax revenue from duties on energy"
    vtE_vat[es,e,d,t]$(d1tE_vat[es,e,d,t]) "Tax revenue from VAT on energy"
    vtE_vat_tot[d,t]$(d1tE_vat_tot[d,t]) "Total VAT revenue from VAT on energy"
    vtE[es,e,d,t]$(sum(etaxes,d1tE_duty[etaxes,es,e,d,t]) or d1tE_vat[es,e,d,t]) "Total tax revenue from energy"
    vtEmarg[es,e,d,t]$(sum(etaxes,d1tE_duty[etaxes,es,e,d,t]) or d1tE_vat[es,e,d,t]) "Total marginal tax revenue from energy, used to compute total bottom deductions"

    vtCO2_ETS[d,t]$(d1tCO2_ETS[d,t]) "Tax revenue from ETS1"
    vtCO2_ETS2[d,t]$(d1tCO2_ETS2[d,t]) "Tax revenue from ETS2"
    vtCO2_ETS_xE[d,t]$(d1tCO2_ETS[d,t] and d1EmmxE['CO2ubio',d,t]) "Tax revenue from ETS1, non-energy related emissions"
    vtCO2_xE[d,t]$(d1tCO2_xE[d,t] and d1EmmxE['CO2ubio',d,t])      "Tax revenue from national carbon tax, non-energy related emissions"
  ;

  $Group G_energy_taxes_other 
    jvtE_duty[etaxes,es,e,d,t]$(d1tE_duty[etaxes,es,e,d,t]) "J-term to capture instances ,where data contains a revenue, but the marginal rate is zero."
  ;

  $Group+ G_flat_after_last_data_year
    G_energy_taxes_rates
    G_energy_taxes_quantities
    G_energy_taxes_values
    G_energy_taxes_other
  ;

  $Group G_energy_taxes_data  
    vtE_duty
    vtE_vat 
    tCO2_Emarg 
    tEmarg_duty
    qCO2_ETS_freeallowances
  ;

# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

	$Group+ quantity_variables
    G_energy_taxes_quantities
	;

  $Group+ value_variables
    G_energy_taxes_values
  ;

	$Group+ other_variables
    G_energy_taxes_rates
    G_energy_taxes_other
	;


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

  $BLOCK energy_and_emissions_taxes energy_and_emissions_taxes_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
     ..   vtE_duty[etaxes,es,e,d,t] =E= tEmarg_duty[etaxes,es,e,d,t] * (qEpj[es,e,d,t] - qEpj_duty_deductible[etaxes,es,e,d,t]) +  jvtE_duty[etaxes,es,e,d,t];

     ..   vtE_vat[es,e,d,t] =E= tE_vat[es,e,d,t] * (pEpj_base[es,e,d,t]*qEpj[es,e,d,t]
                                                  + sum(etaxes, tEmarg_duty[etaxes,es,e,d,t] * (qEpj[es,e,d,t] - qEpj_duty_deductible[etaxes,es,e,d,t]))
                                                  + pEAV[es,e,d,t]*qEpj[es,e,d,t]
                                                  + pDAV[es,e,d,t]*qEpj[es,e,d,t]
                                                  + pCAV[es,e,d,t]*qEpj[es,e,d,t]);

      ..   vtE[es,e,d,t] =E= vtE_vat[es,e,d,t] 
                            + sum(etaxes, vtE_duty[etaxes,es,e,d,t])
                            + sum(em, tCO2_ETS_pj[em,es,e,d,t]*qEpj[es,e,d,t])
                            + sum(em, tCO2_ETS2_pj[em,es,e,d,t]*qEpj[es,e,d,t])
                            ;                   

      ..   vtEmarg[es,e,d,t] =E= (1+tpE[es,e,d,t]) * pEpj_base[es,e,d,t] * qEpj[es,e,d,t];

      tpE[es,e,d,t]..
        (1+tpE[es,e,d,t]) * pEpj_base[es,e,d,t] 
          =E= (1+tE_vat[es,e,d,t]) * (pEpj_base[es,e,d,t]
                                      + sum(etaxes, tEmarg_duty[etaxes,es,e,d,t])
                                      + pEAV[es,e,d,t]
                                      + pDAV[es,e,d,t]
                                      + pCAV[es,e,d,t])
                                      + sum(em, tCO2_Emarg_pj[em,es,e,d,t])
                                      + sum(em, tCO2_ETS_pj[em,es,e,d,t])
                                      ;        

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
          
          #Non-energy   
            ..  vtCO2_ETS_xE[i,t] =E= tCO2_ETS[t]/10**6 * qEmmxE['CO2ubio',i,t];

        #ETS2 (note that whereas ETS1 is only households, ETS2 extends to households as well)
          tCO2_ETS2_pj&_notNatgas[em,es,e,d,t]$(not natgas[e])..
            tCO2_ETS2_pj[em,es,e,d,t] =E= tCO2_ETS2[t]/10**6 * uEmmE_BU[em,es,e,d,t];

          tCO2_ETS2_pj&_NatgasBio[em,es,e,d,t]$(natgas[e] and CO2bio[em])..
            tCO2_ETS2_pj[em,es,e,d,t] =E= tCO2_ETS2[t]/10**6 * uEmmE_BU[em,es,e,d,t] * sBioNatGas[t];

          tCO2_ETS2_pj&_NatgasuBio[em,es,e,d,t]$(natgas[e] and CO2ubio[em])..
            tCO2_ETS2_pj[em,es,e,d,t] =E= tCO2_ETS2[t]/10**6 * uEmmE_BU[em,es,e,d,t] * (1-sBioNatGas[t]);

  $ENDBLOCK           

  $BLOCK energy_and_emissions_taxes_links energy_and_emissions_taxes_links_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    #Bottom deductions 
      vtBotded[i,t]$(d1Y[i,t])..
        vtBotded[i,t] =E= sum((es,e), vtEmarg[es,e,i,t] - vtE[es,e,i,t])
                        - tCO2_ETS[t]/10**6 * qCO2_ETS_freeallowances[i,t]; 

    #Non-energy related taxes
      vtEmmRxE[i,t]$(d1Y[i,t])..
        vtEmmRxE[i,t] =E=  vtCO2_xE[i,t] + vtCO2_ETS_xE[i,t];


    ..    vtE_duty_tot[d,t] =E= sum((etaxes,es,e), vtE_duty[etaxes,es,e,d,t]);

    ..    vtE_vat_tot[d,t] =E= sum((es,e), vtE_vat[es,e,d,t]);
  $ENDBLOCK

  model main / 
          energy_and_emissions_taxes
          energy_and_emissions_taxes_links
            /;
  $Group+ main_endogenous 
    energy_and_emissions_taxes_endogenous
    energy_and_emissions_taxes_links_endogenous
  ;

# ------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------

  @load(G_energy_taxes_data, "../data/data.gdx")
  $Group+ data_covered_variables G_energy_taxes_data;


# ------------------------------------------------------------------------------
# Initial values 
# ------------------------------------------------------------------------------

   tCO2_Emarg.l[em,es,'District heat',d,t] = no;

   tCO2_ETS.l[t] = 750;
   tCO2_ETS2.l[t] = 375; 

   tCO2_xEmarg.l['23001',t] = 125;
   tCO2_xEmarg.l['23002',t] = 125;
   
# ------------------------------------------------------------------------------
# Dummies 
# ------------------------------------------------------------------------------

    d1tE_duty[etaxes,es,e,d,t] = yes$(vtE_duty.l[etaxes,es,e,d,t] and d1pEpj_base[es,e,d,t]);
    d1tE_duty_tot[d,t]         = yes$(sum((etaxes,es,e), d1tE_duty[etaxes,es,e,d,t]));
    d1tE_vat[es,e,d,t]         = yes$(vtE_vat.l[es,e,d,t] and d1pEpj_base[es,e,d,t]);
    d1tE_vat_tot[d,t]          = yes$(sum((es,e), d1tE_vat[es,e,d,t]));
    d1tE[es,e,d,t]             = yes$(sum(etaxes,d1tE_duty[etaxes,es,e,d,t]) or d1tE_vat[es,e,d,t]);

    d1tCO2_E[em,es,e,d,t]      = yes$(tCO2_Emarg.l[em,es,e,d,t] and d1pEpj_base[es,e,d,t]);
    d1tCO2_xE[d,t]             = yes$(tCO2_xEmarg.l[d,t]);
    d1tCO2_ETS_E[em,es,e,d,t]  = yes$(d1EmmE_BU[em,es,e,d,t] and CO2ubio[em] and d1pEpj_base[es,e,d,t] and in_ETS[es]);
    d1tCO2_ETS_E[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t] and CO2bio[em] and d1pEpj_base[es,e,d,t] and in_ETS[es] and natgas[e]) = yes;
    d1tCO2_ETS[i,t]             = yes$(sum((em,es,e), d1tCO2_ETS_E[em,es,e,i,t]));

    d1tCO2_ETS2_E[em,es,e,d,t]  = yes$(d1EmmE_BU[em,es,e,d,t] and CO2ubio[em] and d1pEpj_base[es,e,d,t] and not in_ETS[es]);
    d1tCO2_ETS2_E[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t] and CO2bio[em] and d1pEpj_base[es,e,d,t] and not in_ETS[es] and natgas[e]) = yes;


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

# Add equations and calibration equations to calibration model
model calibration /
  energy_and_emissions_taxes
  energy_and_emissions_taxes_links
/;

# Add endogenous variables to calibration model
$Group calibration_endogenous
  energy_and_emissions_taxes_endogenous 
  -vtE_duty[etaxes,es,e,d,t1], tEmarg_duty[etaxes,es,e,d,t1]
  -tEmarg_duty['EAFG_tax',es,e,i,t1]$(d1tE_duty['EAFG_tax',es,e,i,t1] and tEmarg_duty.l['EAFG_tax',es,e,i,t1] <>0), qEpj_duty_deductible['EAFG_tax',es,e,i,t1]$(d1tE_duty['EAFG_tax',es,e,i,t1] and tEmarg_duty.l['EAFG_tax',es,e,i,t1] <>0)
  -tEmarg_duty['EAFG_tax',es,e,i,t1]$(d1tE_duty['EAFG_tax',es,e,i,t1] and tEmarg_duty.l['EAFG_tax',es,e,i,t1] =0), jvtE_duty['EAFG_tax',es,e,i,t1]$(d1tE_duty['EAFG_tax',es,e,i,t1] and tEmarg_duty.l['EAFG_tax',es,e,i,t1] =0)
  -vtE_vat[es,e,d,t1], tE_vat[es,e,d,t1]

  qEpj_duty_deductible[etaxes,es,e,d,t1]$(d1tE_duty[etaxes,es,e,d,t] and CO2_tax[etaxes] and sum(em,d1tCO2_E[em,es,e,d,t]) and i[d])

  energy_and_emissions_taxes_links_endogenous

  calibration_endogenous
;