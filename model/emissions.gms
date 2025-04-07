# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":
  $SetGroup+ SG_flat_after_last_data_year
        d1EmmE_BU[em,es,e,d,t] ""
        d1Sbionatgas[t] ""
  ;

  $GROUP+ all_variables
    qEmmE_BU[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t]) "Emissions, lowest model level (BU=Bottom up) related to combustion of energy, measured in kilotonnes emitted gas"
    uEmmE_BU[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t]) "Emission coefficient related to energy use. Measured in kilotonnes emitted gas per peta Joule of energy"
    sBioNatGas[t]$(d1Sbionatgas[t])                "Share of bio-natural gas in total natural gas consumption, should perhaps be modelled through emission coefficient in future"

  ;

  #AKB: It would be nice to have an "add from group, but excluding dummies feature"
  $Group G_emissions_BU_data 
    qEmmE_BU$(not CO2e[em])
    sBioNatGas
  ;


    #AGGREGATE EMISSIONS
    $SetGroup+ SG_flat_after_last_data_year 
	      d1EmmLULUCF5[land5,t] ""
        d1EmmLULUCF[t] ""
        d1EmmE[em,d,t] ""
        d1EmmxE[em,d,t] ""
        d1EmmTot[em,em_accounts,t] ""
        d1EmmBorderTrade[em,t] ""
        d1EmmInternationlAviation[em,t] ""
    ;

    $SetGroup Doweevenneedthis
          d1GWP[em] ""
    ;
    
    $Group+ all_variables
        qEmmE[em,d,t]$(d1EmmE[em,d,t]) "Aggregate energy-related emissions. Measured in kilotonnes CO2e"
        qEmmxE[em,d,t]$(d1EmmxE[em,d,t]) "Aggregate non-energy related emissions. Measured in kilotonnes CO2e"

        qEmmTot[em,em_accounts,t]$(d1EmmTot[em,em_accounts,t]) "Total emissions in the economy. Measured in kilotonnes CO2e"
        qEmmLULUCF5[land5,t]$(d1EmmLULUCF5[land5,t]) "Emissions from land-use, land-use change and forestry. Measured in kilotonnes CO2e"
        qEmmLULUCF[t]$(d1EmmLULUCF[t]) "Total emissions from land-use, land-use change and forestry. Measured in kilotonnes CO2e"

        qEmmBorderTrade[em,t]$(d1EmmBorderTrade[em,t])    "Exogenous emissions from border trade. Measured in kilotonnes CO2e"
        qEmmInternationalAviation[em,t]$(d1EmmInternationlAviation[em,t]) "Emissions from international aviation. Measured in kilotonnes CO2e"

        uEmmE[em,d,t]$(d1EmmE[em,d,t]) "Emission coefficient on energy"
        uEmmxE[em,d,t]$(d1EmmxE[em,d,t]) "Emission coefficient on non-energy"
        GWP[em]$(d1GWP[em]) "Global warming potential of emitted gas"
        uEmmLULUCF5[land5,t]$(d1EmmLULUCF5[land5,t]) "Emission coefficient on land-use, land-use change and forestry"
    ;

    $Group G_emissions_aggregates_data 
      qEmmLULUCF5
      # qEmmTot #Husk at lav eordentligt
      qEmmBorderTrade
    ;

    $Group G_emissions_data 
    G_emissions_BU_data
    G_emissions_aggregates_data
    ;

$ENDIF

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

  #BLOCK 1/3, BOTTOM-UP EMISSIONS
  $BLOCK emissions_BU emissions_BU_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    #Energy-related emissions
      qEmmE_BU&_notNatgas[em,es,e,d,t]$(not CO2e[em] and not (natgas[e] and (CO2ubio[em] or CO2bio[em])))..
        qEmmE_BU[em,es,e,d,t] =E= uEmmE_BU[em,es,e,d,t] * qEpj[es,e,d,t];

      qEmmE_BU&_BioNatgas[em,es,e,d,t]$(not CO2e[em] and natgas[e] and CO2bio[em])..
        qEmmE_BU[em,es,e,d,t] =E= sBioNatGas[t] * uEmmE_BU[em,es,e,d,t] * qEpj[es,e,d,t];

      qEmmE_BU&_FossileNatgas[em,es,e,d,t]$(not CO2e[em] and natgas[e] and CO2ubio[em])..
        qEmmE_BU[em,es,e,d,t] =E= (1-sBioNatGas[t]) * uEmmE_BU[em,es,e,d,t] * qEpj[es,e,d,t];

      #CO2e
      qEmmE_BU&_CO2e[em,es,e,d,t]$(CO2e[em])..
        qEmmE_BU['CO2e',es,e,d,t] =E= sum(em_a$(not CO2e[em_a]), GWP[em_a] * qEmmE_BU[em_a,es,e,d,t]);


  $ENDBLOCK 

  #BLOCK 2/3 EMISSIONS AGGREGATES - CAN RUN SEPARATELY OF BOTTOM-UP EMISSIONS. WHEN LINKING 1 AND 2 (THROUGH 3) CALIBRATION VARAIBLES IN 2 ARE ENDOGENIZED TO MATCH BOTTOM-UP EMISSIONS
  $BLOCK emissions_aggregates emissions_aggregates_endogenous $(t1.val <= t.val and t1.val <=tEnd.val)
      #Energy-related emissions
      qEmmE&_production[em,i,t]$(not CO2e[em])..
        qEmmE[em,i,t] =E= uEmmE[em,i,t] * (qProd['Machine_energy',i,t] + qProd['Transport_energy',i,t] + qProd['Heating_energy',i,t]);

      qEmmE&not_production[em,d,t]$(not i[d] and not CO2e[em])..
        qEmmE[em,d,t] =E= uEmmE[em,d,t];

      qEmmE&_CO2e[em,d,t]$(CO2e[em])..
        qEmmE['CO2e',d,t] =E= sum(em_a$(not CO2e[em_a]), GWP[em_a] * qEmmE[em_a,d,t]); 

      Non-energy related emissions
      qEmmxE&_production[em,i,t]$(not CO2e[em])..
        qEmmxE[em,i,t] =E= uEmmxE[em,i,t] * sum(pf_top, qProd[pf_top,i,t]);

      qEmmxE&not_production[em,d,t]$(not i[d] and not CO2e[em])..
        qEmmxE[em,d,t] =E= uEmmxE[em,d,t];

      qEmmxE&_CO2e[em,d,t]$(CO2e[em])..
        qEmmxE['CO2e',d,t] =E= sum(em_a$(not CO2e[em_a]), GWP[em_a] * qEmmxE[em_a,d,t]);


      # LULUCF (is measured in CO2e from the get-go, and we didn't need LULUCF5, if this is only a matter of hitting total emissions in official inventories)
      ..  qEmmLULUCF5[land5,t] =E= uEmmLULUCF5[land5,t];

      ..  qEmmLULUCF[t] =E= sum(land5, qEmmLULUCF5[land5,t]);

      Total emissions
      ..  qEmmTot[em,em_accounts,t] =E= sum(d, qEmmE[em,d,t]) 
                                    + sum(d, qEmmxE[em,d,t]) 
                                    + qEmmLULUCF[t]
                                    + qEmmBorderTrade[em,t]$(gna[em_accounts])
                                    - qEmmInternationalAviation[em,t]$(unfccc[em_accounts])
      ;

  $ENDBLOCK 

  #BLOCK 3/3, LINKING EMISSIONS AGGREGATES AND BOTTOM-UP EMISSIONS
  $BLOCK emissions_aggregates_link emissions_aggregates_link_endogenous $(t1.val <= t.val and t1.val <=tEnd.val)

      #Energy-related emissions
      uEmmE[em,d,t]$(not CO2e[em]).. qEmmE[em,d,t] =E= sum((e,es), qEmmE_BU[em,es,e,d,t]);

      .. qEmmInternationalAviation[em,t] =E= sum(i_international_aviation,qEmmE_BU[em,'transport','jet petroleum',i_international_aviation,t]);

  $ENDBLOCK 

  model main / 
              emissions_BU
              emissions_aggregates 
              emissions_aggregates_link
              /;
              
  $Group+ main_endogenous 
    emissions_BU_endogenous
    emissions_aggregates_endogenous
    emissions_aggregates_link_endogenous
  ;
$ENDIF


# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

  @inf_growth_adjust()
  @load(G_emissions_data, "../data/data.gdx")
  @remove_inf_growth_adjustment()

  GWP.l['CO2ubio'] = 1;
  GWP.l['CH4']     = 28;
  GWP.l['N2O']     = 265;
  # GWP.l['HFC']     = 1; #HFC-gasses are already in CO2e in Danish data
  # GWP.l['PFC']     = 1; #PFC-gasses are already in CO2e in Danish data
  # GWP.l['SF6']     = 1; #SF6 is already measured in CO2e in Danish data

  $Group+ data_covered_variables G_emissions_data$(t.val <= %calibration_year%);

  # ------------------------------------------------------------------------------
  # Initial values 
  # ------------------------------------------------------------------------------
    
    qEmmE.l[em,d,t] = sum((es,e), qEmmE_BU.l[em,es,e,d,t]);

  # ------------------------------------------------------------------------------
  # Dummies
  # ------------------------------------------------------------------------------
  d1EmmE_BU[em,es,e,d,t]     = yes$(qEmmE_BU.l[em,es,e,d,t] and d1pEpj_base[es,e,d,t]);
  d1EmmE[em,d,t]             = yes$(sum((es,e), d1EmmE_BU[em,es,e,d,t]));
  d1EmmxE[em,d,t]            = yes$(qEmmxE.l[em,d,t]);
  d1EmmLULUCF5[land5,t]      = yes$(qEmmLULUCF5.l[land5,t]);
  d1EmmLULUCF[t]             = yes$(qEmmLULUCF.l[t]);
  d1EmmTot[em,em_accounts,t] = yes$(qEmmTot.l[em,em_accounts,t]);
  d1GWP[em]                  = yes$(GWP.l[em]);
  d1Sbionatgas[t]            = yes$(sBioNatGas.l[t]);
  d1EmmBorderTrade[em,t]     = yes$(qEmmBorderTrade.l[em,t]);
  d1EmmInternationlAviation[em,t] = yes$(sum(i_international_aviation, qEmmE_BU.l[em,'transport','jet petroleum',i_international_aviation,t])) ;

$ENDIF
# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":
  # Add equations and calibration equations to calibration model
  model calibration /
    emissions_BU
    emissions_aggregates
    emissions_aggregates_link
  /;

  # Add endogenous variables to calibration model
  $Group calibration_endogenous
    emissions_BU_endogenous
    uEmmE_BU[em,es,e,d,t1]$(not CO2e[em]), -qEmmE_BU[em,es,e,d,t1]$(not CO2e[em])

    emissions_aggregates_endogenous
    uEmmE[em,i,t1]$(not CO2e[em]),               -qEmmE[em,i,t1]$(not CO2e[em])
    uEmmE[em,d,t1]$(not i[d] and not CO2e[em]),  -qEmmE[em,d,t1]$(not i[d] and not CO2e[em])
    uEmmLULUCF5[land5,t1],                       -qEmmLULUCF5[land5,t1]

    emissions_aggregates_link_endogenous
    qEmmE[em,i,t1]$(not CO2e[em])
    qEmmE[em,c,t1]$(not CO2e[em])

    calibration_endogenous
  ;
$ENDIF