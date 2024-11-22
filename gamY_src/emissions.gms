# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
	#BOTTOM-UP EMISSIONS
		$PGROUP PG_emissions_BU_dummies
        d1EmmE_BU[em,es,e,d,t]
        d1Sbionatgas[t]
		;	

		$PGROUP PG_emissions_BU_flat_dummies 
			PG_emissions_BU_dummies  
		;

    $PGROUP+ PG_flat_after_last_data_year
      PG_emissions_BU_flat_dummies
    ;


		$GROUP G_emissions_BU_quantities 
      qEmmE_BU[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t]) "Emissions, lowest model level (BU=Bottom up) related to combustion of energy, measured in kilotonnes emitted gas"
    ;

		$GROUP G_emissions_BU_other
      uEmmE_BU[em,es,e,d,t]$(d1EmmE_BU[em,es,e,d,t]) "Emission coefficient related to energy use. Measured in kilotonnes emitted gas per peta Joule of energy"
			sBioNatGas[t]$(d1Sbionatgas[t])                "Share of bio-natural gas in total natural gas consumption, should perhaps be modelled through emission coefficient in future"
		;

		$GROUP+ G_flat_after_last_data_year 
			G_emissions_BU_quantities
			G_emissions_BU_other
		;

    #AKB: It would be nice to have an "add from group, but excluding dummies feature"
		$GROUP G_emissions_BU_data 
      qEmmE_BU
      sBioNatGas
  	;


    #AGGREGATE EMISSIONS
    $PGROUP PG_emissions_aggregates_dummies 
	      d1EmmLULUCF5[land5,t]
        d1EmmLULUCF[t]
        d1EmmE[em,d,t]
        d1EmmxE[em,d,t]
        d1EmmTot[em,em_accounts,t]
        d1GWP[em]
    ;

    $PGROUP PG_emissions_aggregates_flat_dummies 
      PG_emissions_aggregates_dummies
    ;

    $PGROUP+ PG_flat_after_last_data_year
      PG_emissions_aggregates_flat_dummies
    ;


    $GROUP G_emissions_aggregates_quantities
        qEmmE[em,d,t]$(d1EmmE[em,d,t]) "Aggregate energy-related emissions. Measured in kilotonnes CO2e"
        qEmmxE[em,d,t]$(d1EmmxE[em,d,t]) "Aggregate non-energy related emissions. Measured in kilotonnes CO2e"

        qEmmTot[em,em_accounts,t]$(d1EmmTot[em,em_accounts,t]) "Total emissions in the economy. Measured in kilotonnes CO2e"
        qEmmLULUCF5[land5,t]$(d1EmmLULUCF5[land5,t]) "Emissions from land-use, land-use change and forestry. Measured in kilotonnes CO2e"
        qEmmLULUCF[t]$(d1EmmLULUCF[t]) "Total emissions from land-use, land-use change and forestry. Measured in kilotonnes CO2e"
    ;

    $GROUP G_emissions_aggregates_other
      uEmmE[em,d,t]$(d1EmmE[em,d,t]) "Emission coefficient on energy"
      uEmmxE[em,d,t]$(d1EmmxE[em,d,t]) "Emission coefficient on non-energy"
      GWP[em]$(d1GWP[em]) "Global warming potential of emitted gas"
      uEmmLULUCF5[land5,t]$(d1EmmLULUCF5[land5,t]) "Emission coefficient on land-use, land-use change and forestry"
    ;

    $GROUP+ G_flat_after_last_data_year
      G_emissions_aggregates_quantities
      G_emissions_aggregates_other
    ;

    $GROUP G_emissions_aggregates_data 
      qEmmTot
      qEmmLULUCF5
      qEmmLULUCF
      GWP
    ;

# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

  $GROUP G_emissions_data 
    G_emissions_BU_data
    G_emissions_aggregates_data
  ;

	$GROUP+ quantity_variables
		G_emissions_BU_quantities #AKB: Should be removed but remains for existence groups
    G_emissions_aggregates_quantities
	;

	$GROUP+ other_variables
    G_emissions_BU_other
    G_emissions_aggregates_other
	;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

  #BLOCK 1/3, BOTTOM-UP EMISSIONS
  $BLOCK emissions_BU emissions_BU_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    #Energy-related emissions
      qEmmE_BU&_notNatgas[em,es,e,d,t]$(not sameas[em,'CO2e'] and not (sameas[e,'Natural gas incl. biongas'] and (sameas[em,'CO2ubio'] or sameas[em,'CO2bio'])))..
        qEmmE_BU[em,es,e,d,t] =E= uEmmE_BU[em,es,e,d,t] * qEpj[es,e,d,t];

      qEmmE_BU&_BioNatgas[em,es,e,d,t]$(not sameas[em,'CO2e'] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio'])..
        qEmmE_BU[em,es,e,d,t] =E= sBioNatGas[t] * uEmmE_BU[em,es,e,d,t] * qEpj[es,e,d,t];

      qEmmE_BU&_FossileNatgas[em,es,e,d,t]$(not sameas[em,'CO2e'] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2ubio'])..
        qEmmE_BU[em,es,e,d,t] =E= (1-sBioNatGas[t]) * uEmmE_BU[em,es,e,d,t] * qEpj[es,e,d,t];

      #CO2e
      qEmmE_BU&_CO2e[em,es,e,d,t]$(sameas[em,'CO2e'])..
        qEmmE_BU['CO2e',es,e,d,t] =E= sum(em_a$(not sameas[em_a,'CO2e']), GWP[em_a] * qEmmE_BU[em_a,es,e,d,t]);


  $ENDBLOCK 

  #BLOCK 2/3 EMISSIONS AGGREGATES - CAN RUN SEPARATELY OF BOTTOM-UP EMISSIONS. WHEN LINKING 1 AND 2 (THROUGH 3) CALIBRATION VARAIBLES IN 2 ARE ENDOGENIZED TO MATCH BOTTOM-UP EMISSIONS
  $BLOCK emissions_aggregates emissions_aggregates_endogenous $(t1.val <= t.val and t1.val <=tEnd.val)
      #Energy-related emissions
      qEmmE&_production[em,i,t]$(d1EmmE[em,i,t] and not sameas[em,'CO2e'])..
        qEmmE[em,i,t] =E= uEmmE[em,i,t] * (qProd['Machine_energy',i,t] + qProd['Transport_energy',i,t] + qProd['Heating_energy',i,t]);

      qEmmE&not_production[em,d,t]$(d1EmmE[em,d,t] and not i[d] and not sameas[em,'CO2e'])..
        qEmmE[em,d,t] =E= uEmmE[em,d,t];

      qEmmE&_CO2e[em,d,t]$(d1EmmE[em,d,t] and sameas[em,'CO2e'])..
        qEmmE['CO2e',d,t] =E= sum(em_a$(not sameas[em_a,'CO2e']), GWP[em_a] * qEmmE[em_a,d,t]); 

      # Non-energy related emissions
      qEmmxE&_production[em,i,t]$(d1EmmxE[em,i,t] and not sameas[em,'CO2e'])..
        qEmmxE[em,i,t] =E= uEmmxE[em,i,t] * sum(pf_top, qProd[pf_top,i,t]);

      qEmmxE&not_production[em,d,t]$(d1EmmxE[em,d,t] and not i[d] and not sameas[em,'CO2e'])..
        qEmmxE[em,d,t] =E= uEmmxE[em,d,t];

      qEmmxE&_CO2e[em,d,t]$(d1EmmxE[em,d,t] and sameas[em,'CO2e'])..
        qEmmxE['CO2e',d,t] =E= sum(em_a$(not sameas[em_a,'CO2e']), GWP[em_a] * qEmmxE[em_a,d,t]);


      # LULUCF (is measured in CO2e from the get-go, and we didn't need LULUCF5, if this is only a matter of hitting total emissions in official inventories)
      qEmmLULUCF5[land5,t]$(d1EmmLULUCF5[land5,t])..
        qEmmLULUCF5[land5,t] =E= uEmmLULUCF5[land5,t];

      qEmmLULUCF[t]$(d1EmmLULUCF[t])..
        qEmmLULUCF[t] =E= sum(land5, qEmmLULUCF5[land5,t]);

      #Total emissions
      qEmmTot[em,em_accounts,t]$(d1EmmTot[em,em_accounts,t])..
        qEmmTot[em,em_accounts,t] =E= sum(d, qEmmE[em,d,t]) 
                                    + sum(d, qEmmxE[em,d,t]) 
                                    + qEmmLULUCF[t];

  $ENDBLOCK 

  #BLOCK 3/3, LINKING EMISSIONS AGGREGATES AND BOTTOM-UP EMISSIONS
  $BLOCK emissions_aggregates_link emissions_aggregates_link_endogenous $(t1.val <= t.val and t1.val <=tEnd.val)

      #Energy-related emissions
      uEmmE[em,d,t]$(not sameas[em,'CO2e']).. qEmmE[em,d,t] =E= sum((e,es), qEmmE_BU[em,es,e,d,t]);

  $ENDBLOCK 

model main / 
            emissions_BU
            emissions_aggregates 
            emissions_aggregates_link
            /;
            
$GROUP+ main_endogenous 
  emissions_BU_endogenous
  emissions_aggregates_endogenous
  emissions_aggregates_link_endogenous
;

# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------

@load(G_emissions_data, "../data/data.gdx")
$GROUP+ data_covered_variables G_emissions_data;

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

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

# Add equations and calibration equations to calibration model
model calibration /
  emissions_BU
  emissions_aggregates
  emissions_aggregates_link
/;

# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  emissions_BU_endogenous
  uEmmE_BU[em,es,e,d,t1]$(not sameas[em,'CO2e']), -qEmmE_BU[em,es,e,d,t1]$(not sameas[em,'CO2e'])

  emissions_aggregates_endogenous
  uEmmE[em,i,t1]$(not sameas[em,'CO2e']),               -qEmmE[em,i,t1]$(not sameas[em,'CO2e'])
  uEmmE[em,d,t1]$(not i[d] and not sameas[em,'CO2e']),  -qEmmE[em,d,t1]$(not i[d] and not sameas[em,'CO2e'])

  emissions_aggregates_link_endogenous
  qEmmE[em,i,t1]$(not sameas[em,'CO2e'])
  qEmmE[em,c,t1]$(not sameas[em,'CO2e'])

  calibration_endogenous
;