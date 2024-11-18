# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
  
  $PGROUP PG_energy_taxes_dummies 
    d1tRE_duty[etaxes,es,e,i,t] "Dummy for revenue on duty-rates on firms energy input. Measured in bio. kr. per PJ energy input"
    d1tRE_vat[es,e,i,t]         "Dummy for revenue on VAT-rates per PJ energy input"
    d1tRE[es,e,i,t]                 "Dummy for total revenue from energy taxes per PJ energy input"

    d1tCO2_RE[em,es,e,i,t]       "Dummy for marginal CO2 tax per PJ energy input, measured in kroner per ton CO2"
    d1tCO2_RxE[i,t]              "Dummy for marginal CO2 tax per kt CO2, measured in kroner per ton CO2"
    d1tCO2_ETS_RE[em,es,e,i,t]     "Dummy for ETS1 carbon price per PJ energy input, measured in kroner per ton CO2"
    d1tCO2_ETS[i,t]
    d1tCO2_ETS_RxE[i,t]
    d1tCO2_ETS2_RE[em,es,e,i,t]   "Dummy for ETS2 carbon price per PJ energy input, measured in kroner per ton CO2"

    d1tCE_duty[etaxes,es,e,t]         "Dummy for duty-rates on households energy input. Measured in bio. kr. per PJ energy input"
    d1tCE_vat[es,e,t]                 "Dummy for VAT on households energy input"
    d1tCE[es,e,t]                     "Dummy for total revenue from energy taxes on households energy input"

    d1tRE_duty_tot[i,t]
    d1tRE_vat_tot[i,t]
  ;

  $PGROUP PG_energy_taxes_flat_dummies 
    PG_energy_taxes_dummies
  ;

  $GROUP G_energy_taxes_rates
    tREmarg_duty[etaxes,es,e,i,t]$(d1tRE_duty[etaxes,es,e,i,t]) "Marginal duty-rates on firms energy input. Measured in bio. kr. per PJ energy input"    
    tRE_vat[es,e,i,t]$(d1tRE_vat[es,e,i,t])  "Marginal VAT-rates per PJ energy input" 
    tREmarg[es,e,i,t]$(sum(etaxes,d1tRE_duty[etaxes,es,e,i,t]) or d1tRE_vat[es,e,i,t]) "Marginal energy tax per PJ energy input, measured in bio. kr. per PJ energy input"
    tCO2_REmarg[em,es,e,i,t]$(d1tCO2_RE[em,es,e,i,t])  "Marginal CO2 tax per PJ energy input, measured in kroner per ton CO2"
    tCO2_RxE[i,t]$(d1tCO2_RxE[i,t])                      "CO2 tax rate on non-energy related emissions measured in kroner per ton CO2"
    tCO2_REmarg_pj[em,es,e,i,t]$(d1tCO2_RE[em,es,e,i,t]) "Marginal CO2 tax per PJ energy input, measured in bio. kroner per PJ energy input"

    tCE_duty[etaxes,es,e,t]$(d1tCE_duty[etaxes,es,e,t]) "Marginal duty-rates on households energy input. Measured in bio. kr. per PJ energy input"
    tCE_vat[es,e,t]$(d1tCE_vat[es,e,t]) "Marginal VAT-rates per PJ energy input"
    tCO2_ETS[t] "ETS1 carbon price, measured in kroner per ton CO2"
    tCO2_ETS2[t] "ETS2 carbon price, measured in kroner per ton CO2"

    tCO2_ETS_RE_pj[em,es,e,i,t]$(d1tCO2_ETS_RE[em,es,e,i,t]) "ETS1 carbon price measured in bio. kroner per PJ energy input for industries"
    tCO2_ETS2_RE_pj[em,es,e,i,t]$(d1tCO2_ETS2_RE[em,es,e,i,t]) "ETS1 carbon price measured in bio. kroner per PJ energy input for industries"

  ;

    $GROUP G_energy_taxes_quantities
    qREpj_duty_deductible[etaxes,es,e,i,t]$(d1tRE_duty[etaxes,es,e,i,t]) "Marginal duty-rates on firms energy input. Measured in bio. kr. per PJ energy input"    
    qREpj_vat_deductible[es,e,i,t]$(d1tRE_vat[es,e,i,t])  "Marginal VAT-rates per PJ energy input" 
    # tREmarg[es,e,i,t] "Marginal energy tax per PJ energy input, measured in bio. kr. per PJ energy input"
    qCO2_ETS_freeallowances[i,t]$(d1tCO2_ETS[i,t]) "This one needs to have added non-energy related emissions"
    
    # qCEpj_duty[etaxes,es,e,t]$(d1tCE_duty[etaxes,es,e,t]) "Marginal duty-rates on firms energy input. Measured in bio. kr. per PJ energy input"
  ;

  $GROUP G_energy_taxes_values 
    vtRE_duty[etaxes,es,e,i,t]$(d1tRE_duty[etaxes,es,e,i,t]) "Tax revenue from duties on energy, industries"
    vtRE_vat[es,e,i,t]$(d1tRE_vat[es,e,i,t]) "Tax revenue from VAT on energy, industries"
    vtRE[es,e,i,t]$(sum(etaxes,d1tRE_duty[etaxes,es,e,i,t]) or d1tRE_vat[es,e,i,t]) "Total tax revenue from energy, industries"
    vtREmarg[es,e,i,t]$(sum(etaxes,d1tRE_duty[etaxes,es,e,i,t]) or d1tRE_vat[es,e,i,t]) "Total marginal tax revenue from energy, industries, used to compute total bottom deductions"

    vtCE_duty[etaxes,es,e,t]$(d1tCE_duty[etaxes,es,e,t]) "Tax revenue from duties on energy, households"
    vtCE_vat[es,e,t]$(d1tCE_vat[es,e,t]) "Tax revenue from VAT on energy, households"
    vtCE[es,e,t]$(sum(etaxes,d1tCE_duty[etaxes,es,e,t]) or d1tCE_vat[es,e,t]) "Total tax revenue from energy, households"

    vtCO2_ETS[i,t]$(d1tCO2_ETS[i,t]) "Tax revenue from ETS1"
    vtCO2_ETS_RxE[i,t]$(d1tCO2_ETS[i,t] and d1EmmRxE['CO2ubio',i,t]) "Tax revenue from ETS1, non-energy related emissions"
    vtCO2_RxE[i,t]$(d1tCO2_RxE[i,t] and d1EmmRxE['CO2ubio',i,t]) "Tax revenue from ETS1, non-energy related emissions"

    vtRE_duty_tot[i,t]$(d1tRE_duty_tot[i,t]) "Total tax revenue from duties on energy, industries"
    vtRE_vat_tot[i,t]$(d1tRE_vat_tot[i,t]) "Total VAT revenue from VAT on energy, industries"

  ;

  $GROUP G_energy_taxes_flat_after_last_data_year
    G_energy_taxes_rates
    G_energy_taxes_quantities
    G_energy_taxes_values
  ;

  $GROUP G_energy_taxes_data  
    vtRE_duty
    vtRE_vat
    vtCE_duty 
    vtCE_vat

    tCO2_REmarg
    tREmarg_duty
    qCO2_ETS_freeallowances
  ;

# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

	$GROUP+ quantity_variables
    G_energy_taxes_quantities
	;

  $GROUP+ value_variables
    G_energy_taxes_values
  ;

	$GROUP+ other_variables
    G_energy_taxes_rates
	;

	#Add dummies to main flat-group 
	$PGROUP+ PG_flat_after_last_data_year
    PG_energy_taxes_flat_dummies
	;
		# Add dummies to main groups
	$GROUP+ G_flat_after_last_data_year
    G_energy_taxes_flat_after_last_data_year
	;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

  $BLOCK energy_and_emissions_taxes energy_and_emissions_taxes_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    #INDUSTRIES
      vtRE_duty[etaxes,es,e,i,t]$(d1tRE_duty[etaxes,es,e,i,t]).. 
        vtRE_duty[etaxes,es,e,i,t] =E= tREmarg_duty[etaxes,es,e,i,t] * (qREpj[es,e,i,t] - qREpj_duty_deductible[etaxes,es,e,i,t]);

      vtRE_vat[es,e,i,t]$(d1tRE_vat[es,e,i,t])..
        vtRE_vat[es,e,i,t] =E=  tRE_vat[es,e,i,t] *(pREpj_base[es,e,i,t]*qREpj[es,e,i,t] 
                                                      + sum(etaxes$(d1tRE_duty[etaxes,es,e,i,t]), tREmarg_duty[etaxes,es,e,i,t] * (qREpj[es,e,i,t] - qREpj_duty_deductible[etaxes,es,e,i,t]))
                                                      + pEAV_RE[es,e,i,t]*qREpj[es,e,i,t]
                                                      + pDAV_RE[es,e,i,t]*qREpj[es,e,i,t]
                                                      + pCAV_RE[es,e,i,t]*qREpj[es,e,i,t]);


      vtRE[es,e,i,t]$(d1tRE[es,e,i,t])..
        vtRE[es,e,i,t] =E= vtRE_vat[es,e,i,t] 
                          + sum(etaxes, vtRE_duty[etaxes,es,e,i,t])
                          + sum(em$d1tCO2_ETS_RE[em,es,e,i,t], tCO2_ETS_RE_pj[em,es,e,i,t]*qREpj[es,e,i,t])
                          + sum(em$d1tCO2_ETS2_RE[em,es,e,i,t], tCO2_ETS2_RE_pj[em,es,e,i,t]*qREpj[es,e,i,t]);                   ;

      tpRE[es,e,i,t]$(d1tRE[es,e,i,t])..
        (1+tpRE[es,e,i,t]) * pREpj_base[es,e,i,t] 
          =E= (1+tRE_vat[es,e,i,t]) * (pREpj_base[es,e,i,t] 
                                          + sum(etaxes$(d1tRE_duty[etaxes,es,e,i,t]), tREmarg_duty[etaxes,es,e,i,t])
                                          + pEAV_RE[es,e,i,t]
                                          + pDAV_RE[es,e,i,t]
                                          + pCAV_RE[es,e,i,t])
                                          + sum(em$d1tCO2_ETS_RE[em,es,e,i,t], tCO2_ETS_RE_pj[em,es,e,i,t]) #Quotas are paid at end-use, and hence are not levied VAT. This is in likelihood going to be different for ETS2, but so far it is modelled the same as ETS1
                                          + sum(em$d1tCO2_ETS2_RE[em,es,e,i,t], tCO2_ETS2_RE_pj[em,es,e,i,t]) 
                                          ;

        vtREmarg[es,e,i,t]$(d1tRE[es,e,i,t])..
          vtREmarg[es,e,i,t] =E= (1+tpRE[es,e,i,t]) * pREpj_base[es,e,i,t] * qREpj[es,e,i,t];

        #CO2-taxes based on emissions                                                                                                                                                                                       #AKB: Depending on how EOP-abatement i modelled this should be adjusted for EOP
          tCO2_REmarg_pj&_notNatgas[em,es,e,i,t]$(d1tCO2_RE[em,es,e,i,t] and not sameas[e,'Natural gas incl. biongas']).. tCO2_REmarg_pj[em,es,e,i,t] =E= tCO2_REmarg[em,es,e,i,t] /10**6 * uEmmRE[em,es,e,i,t];

          #Consider removing as emission coefficient is the same for ubio/bio
          tCO2_REmarg_pj&_NatgasBio[em,es,e,i,t]$(d1tCO2_RE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio']).. 
            tCO2_REmarg_pj[em,es,e,i,t] =E= tCO2_REmarg[em,es,e,i,t] /10**6 * uEmmRE[em,es,e,i,t] * sBioNatGas[t]; 

          tCO2_REmarg_pj&_NatgasuBio[em,es,e,i,t]$(d1tCO2_RE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2ubio']).. 
              tCO2_REmarg_pj[em,es,e,i,t] =E= tCO2_REmarg[em,es,e,i,t] /10**6 * uEmmRE[em,es,e,i,t] * (1-sBioNatGas[t]); 

          #Linking to per PJ tax-rate 
          tREmarg_duty[etaxes,es,e,i,t]$(sum(em,d1tCO2_RE[em,es,e,i,t]) and d1tRE_duty[etaxes,es,e,i,t] and sameas[etaxes,'CO2_tax']).. 
            tREmarg_duty[etaxes,es,e,i,t] =E= sum(em$(d1tCO2_RE[em,es,e,i,t]), tCO2_REmarg_pj[em,es,e,i,t]);

          
          #Non-energy related CO2-tax 
          vtCO2_RxE[i,t]$(d1tCO2_RxE[i,t]).. 
            vtCO2_RxE[i,t] =E= tCO2_RxE[i,t] /10**6 * qEmmRxE['CO2ubio',i,t]/fqt[t];
      

        #ETS1
          #Energy
          tCO2_ETS_RE_pj&_notNatgas[em,es,e,i,t]$(d1tCO2_ETS_RE[em,es,e,i,t] and not sameas[e,'Natural gas incl. biongas'])..
            tCO2_ETS_RE_pj[em,es,e,i,t] =E= tCO2_ETS[t]/10**6 * uEmmRE[em,es,e,i,t];

          tCO2_ETS_RE_pj&_NatgasBio[em,es,e,i,t]$(d1tCO2_ETS_RE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio'])..
            tCO2_ETS_RE_pj[em,es,e,i,t] =E= tCO2_ETS[t]/10**6 * uEmmRE[em,es,e,i,t] * sBioNatGas[t];

          tCO2_ETS_RE_pj&_NatgasuBio[em,es,e,i,t]$(d1tCO2_ETS_RE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2uio'])..
            tCO2_ETS_RE_pj[em,es,e,i,t] =E= tCO2_ETS[t]/10**6 * uEmmRE[em,es,e,i,t] * (1-sBioNatGas[t]);
          
          #Non-energy   
            vtCO2_ETS_RxE[i,t]$(d1tCO2_ets_rxe[i,t])..
              vtCO2_ETS_RxE[i,t] =E= tCO2_RxE[i,t]/10**6 * qEmmRxE['CO2ubio',i,t]/fqt[t];

        #ETS2
        tCO2_ETS2_RE_pj&_notNatgas[em,es,e,i,t]$(d1tCO2_ETS2_RE[em,es,e,i,t] and not sameas[e,'Natural gas incl. biongas'])..
          tCO2_ETS2_RE_pj[em,es,e,i,t] =E= tCO2_ETS2[t]/10**6 * uEmmRE[em,es,e,i,t];

        tCO2_ETS2_RE_pj&_NatgasBio[em,es,e,i,t]$(d1tCO2_ETS2_RE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio'])..
          tCO2_ETS2_RE_pj[em,es,e,i,t] =E= tCO2_ETS2[t]/10**6 * uEmmRE[em,es,e,i,t] * sBioNatGas[t];

        tCO2_ETS2_RE_pj&_NatgasuBio[em,es,e,i,t]$(d1tCO2_ETS2_RE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2uio'])..
          tCO2_ETS2_RE_pj[em,es,e,i,t] =E= tCO2_ETS2[t]/10**6 * uEmmRE[em,es,e,i,t] * (1-sBioNatGas[t]);




    #HOUSEHOLDS 
      vtCE_duty[etaxes,es,e,t]$(d1tCE_duty[etaxes,es,e,t])..
       vtCE_duty[etaxes,es,e,t] =E= tCE_duty[etaxes,es,e,t] * qCEpj[es,e,t];

    vtCE_vat[es,e,t]$(d1tCE_vat[es,e,t])..
      vtCE_vat[es,e,t] =E= tCE_vat[es,e,t] *  (pCEpj_base[es,e,t] * qCEpj[es,e,t]
                                               + sum(etaxes$(d1tCE_duty[etaxes,es,e,t]), tCE_duty[etaxes,es,e,t] * qCEpj[es,e,t])
                                               + pEAV_CE[es,e,t] * qCEpj[es,e,t]
                                               + pDAV_CE[es,e,t] * qCEpj[es,e,t]
                                               + pCAV_CE[es,e,t] * qCEpj[es,e,t]);

    vtCE[es,e,t]$(d1tCE[es,e,t])..
      vtCE[es,e,t] =E= vtCE_vat[es,e,t] + sum(etaxes$(d1tCE_duty[etaxes,es,e,t]), vtCE_duty[etaxes,es,e,t]);

    tpCE[es,e,t]$(d1tCE[es,e,t])..
      (1+tpCE[es,e,t]) * pCEpj_base[es,e,t] =E= (1+tCE_vat[es,e,t]) * (pCEpj_base[es,e,t] 
                                  + sum(etaxes$(d1tCE_duty[etaxes,es,e,t]), tCE_duty[etaxes,es,e,t])
                                  + pEAV_CE[es,e,t]
                                  + pDAV_CE[es,e,t]
                                  + pCAV_CE[es,e,t]);


  $ENDBLOCK           

  $BLOCK energy_and_emissions_taxes_links energy_and_emissions_taxes_links_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    #Bottom deductions 
      vtBotded[i,t]$(d1Y[i,t])..
        vtBotded[i,t] =E= sum((es,e), vtREmarg[es,e,i,t] - vtRE[es,e,i,t])
                        - tCO2_ETS[t]/10**6 * qCO2_ETS_freeallowances[i,t]; #/fqt[t];

    #Non-energy related taxes
      vtEmmRxE[i,t]$(d1Y[i,t])..
        vtEmmRxE[i,t] =E=  vtCO2_RxE[i,t] + vtCO2_ETS_RxE[i,t];

      vtRE_duty_tot[i,t]$(d1Y[i,t])..
        vtRE_duty_tot[i,t] =E= sum((etaxes,es,e), vtRE_duty[etaxes,es,e,i,t]);

      vtRE_vat_tot[i,t]$(d1Y[i,t])..
        vtRE_vat_tot[i,t] =E= sum((es,e), vtRE_vat[es,e,i,t]);


  $ENDBLOCK

  model main / 
          energy_and_emissions_taxes
          energy_and_emissions_taxes_links
            /;
  $GROUP+ main_endogenous 
    energy_and_emissions_taxes_endogenous
    energy_and_emissions_taxes_links_endogenous
  ;

# ------------------------------------------------------------------------------
# Data
# ------------------------------------------------------------------------------

  @load(G_energy_taxes_data, "../data/data.gdx")
  $GROUP+ data_covered_variables G_energy_taxes_data;


# ------------------------------------------------------------------------------
# Initial values 
# ------------------------------------------------------------------------------

   tCO2_REmarg.l[em,es,'District heat',i,t] = no;

   tCO2_ETS.l[t] = 750;
   tCO2_ETS2.l[t] = 375; 

   tCO2_RxE.l['23001',t] = 125;
   tCO2_RxE.l['23002',t] = 125;
   

# ------------------------------------------------------------------------------
# Dummies 
# ------------------------------------------------------------------------------

    d1tRE_duty[etaxes,es,e,i,t] = yes$(vtRE_duty.l[etaxes,es,e,i,t] and d1pREpj_base[es,e,i,t]);  
    d1tRE_duty_tot[i,t]         = yes$(sum((etaxes,es,e), d1tRE_duty[etaxes,es,e,i,t]));
    d1tRE_vat[es,e,i,t]         = yes$(vtRE_vat.l[es,e,i,t] and d1pREpj_base[es,e,i,t]);
    d1tRE_vat_tot[i,t]          = yes$(sum((es,e), d1tRE_vat[es,e,i,t]));
    d1tRE[es,e,i,t]             = yes$(sum(etaxes,d1tRE_duty[etaxes,es,e,i,t]) or d1tRE_vat[es,e,i,t]);  

    d1tCO2_RE[em,es,e,i,t]      = yes$(tCO2_REmarg.l[em,es,e,i,t] and d1pREpj_base[es,e,i,t]);
    d1tCO2_RxE[i,t]             = yes$(tCO2_RxE.l[i,t] and d1EmmRxE['CO2ubio',i,t]);
    d1tCE_duty[etaxes,es,e,t]   = yes$(vtCE_duty.l[etaxes,es,e,t] and d1pCEpj_base[es,e,t]);
    d1tCE_vat[es,e,t]           = yes$(vtCE_vat.l[es,e,t] and d1pCEpj_base[es,e,t]);
    d1tCE[es,e,t]               = yes$(sum(etaxes,d1tCE_duty[etaxes,es,e,t]) or d1tCE_vat[es,e,t]);

    #ETS1
    d1tCO2_ETS_RE[em,es,e,i,t]   = yes$(d1EmmRE[em,es,e,i,t] and sameas[em,'CO2ubio'] and d1pREpj_base[es,e,i,t] and sameas[es,'in_ETS']);
    d1tCO2_ETS_RE[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t] and sameas[em,'CO2bio'] and d1pREpj_base[es,e,i,t] and sameas[es,'in_ETS'] and sameas[e,'Natural gas incl. biongas']) = yes;

    d1tCO2_ETS[i,t]              = yes$(sum((em,es,e), d1tCO2_ETS_RE[em,es,e,i,t]));
    d1tCO2_ETS_RxE[i,t]          = yes$(d1tCO2_ETS[i,t] and d1EmmRxE['CO2ubio',i,t]);

    #ETS2
    d1tCO2_ETS2_RE[em,es,e,i,t]  = yes$(d1EmmRE[em,es,e,i,t] and sameas[em,'CO2ubio'] and d1pREpj_base[es,e,i,t] and not sameas[es,'in_ETS']);
    d1tCO2_ETS2_RE[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t] and sameas[em,'CO2bio'] and d1pREpj_base[es,e,i,t] and not sameas[es,'in_ETS'] and sameas[e,'Natural gas incl. biongas'])  = yes;

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

# Add equations and calibration equations to calibration model
model calibration /
  energy_and_emissions_taxes
  energy_and_emissions_taxes_links
/;

# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  energy_and_emissions_taxes_endogenous
  -vtRE_duty[etaxes,es,e,i,t1], tREmarg_duty[etaxes,es,e,i,t1]
  # -tREmarg_duty['EAFG_tax',es,e,i,t1], qREpj_duty_deductible['EAFG_tax',es,e,i,t1] 
  -vtRE_vat[es,e,i,t1], tRE_vat[es,e,i,t1]

  -vtCE_duty[etaxes,es,e,t1], tCE_duty[etaxes,es,e,t1]
  -vtCE_vat[es,e,t1], tCE_vat[es,e,t1]

  #For CO2-tax a deductible is endogenized so that vtRE_duty['CO2_tax'] is still hit, when tREmarg_duty is computed BU 
  qREpj_duty_deductible[etaxes,es,e,i,t1]$(d1tRE_duty[etaxes,es,e,i,t] and sameas[etaxes,'CO2_tax'] and sum(em,d1tCO2_RE[em,es,e,i,t]))
  

  energy_and_emissions_taxes_links_endogenous

  calibration_endogenous
;