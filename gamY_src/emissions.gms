# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
	#Emissions
		$PGROUP PG_emissions_dummies
	      d1EmmCE[em,es,e,t]
	      d1EmmCxE[em,t]
	      d1EmmRE[em,es,e,i,t]
	      d1EmmRxE[em,i,t]

	      d1EmmLULUCF5[land5,t]

        d1Sbionatgas[t]
        d1GWP[em]
		;	

		$PGROUP PG_emissions_flat_dummies 
			PG_emissions_dummies 
		;


		$GROUP G_emissions_quantities 
			qEmmRE[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t]) "Industries emissions related to combustion of energy e for energy-service es, measured in kilotonnes emitted gas"
			qEmmRxE[em,i,t]$(d1EmmRxE[em,i,t]) "Industries emissions not related to combustion of energy. Measured in kilotonnes emitted gas"
			qEmmCE[em,e,t]$(d1EmmCE[em,e,t]) "Consumers emissions related to combustion of energy. Measured in kilotonnes emitted gas"
      qEmmCxE[em,t]$(d1EmmCxE[em,t]) "Consumers emissions not related to combustion of energy. Measured in kilotonnes emitted gas" 
      qEmmLULUCF5[land5,t]$(d1EmmLULUCF5[land5,t]) "Emissions from land-use, land-use change and forestry. Measured in kilotonnes CO2e"
      qEmmTot[em_accounts,t] "Total emissions in the economy. Measured in kilotonnes CO2e"
    ;

		$GROUP G_emissions_other
			uEmmRE[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t]) "Unit emissions related to combustion of energy e for energy-service es, measured in kilotonnes emitted gas per unit of energy"
			uEmmRxE[em,i,t]$(d1EmmRxE[em,i,t]) "Unit emissions not related to combustion of energy. Measured in kilotonnes emitted gas per unit of energy"

			uEmmCE[em,es,e,t]$(d1EmmCE[em,e,t]) "Unit emissions related to combustion of energy. Measured in kilotonnes emitted gas per unit of energy"
			uEmmCxE[em,t]$(d1EmmCxE[em,t]) "Unit emissions not related to combustion of energy. Measured in kilotonnes emitted gas per unit of energy"

			sBioNatGas[t]$(d1Sbionatgas[t])

      GWP[em]$(d1GWP[em]) "Global warming potential of emitted gas"
		;

		$GROUP G_emissions_flat_after_last_data_year 
			G_emissions_quantities
			G_emissions_other
		;

		$GROUP G_emissions_data 
      G_emissions_quantities
      G_emissions_other
		;


# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

	$GROUP+ quantity_variables
		G_emissions_quantities #AKB: Should be removed but remains for existence groups
	;

	$GROUP+ other_variables
    G_emissions_other
	;

	#Add dummies to main flat-group 
	$PGROUP+ PG_flat_after_last_data_year
		PG_emissions_flat_dummies
	;
		# Add dummies to main groups
	$GROUP+ G_flat_after_last_data_year
		G_emissions_flat_after_last_data_year
	;


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

$BLOCK B_emissions emissions_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

  #Energy-related emissions
    #Firms
    qEmmRE&_notNatgas[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t])..
      qEmmRE[em,es,e,i,t] =E= uEmmRE[em,es,e,i,t] * qREpj[es,e,i,t]/fqt[t];

    qEmmRE&_BioNatgas[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio'])..
      qEmmRE[em,es,e,i,t] =E= sBioNatGas[t] * uEmmRE[em,es,e,i,t] * qREpj[es,e,i,t]/fqt[t];

    qEmmRE&_FossileNatgas[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2ubio'])..
      qEmmRE[em,es,e,i,t] =E= (1-sBioNatGas[t]) * uEmmRE[em,es,e,i,t] * qREpj[es,e,i,t]/fqt[t];


    #Consumers
    qEmmCE&_notNatgas[em,es,e,t]$(d1EmmCE[em,es,e,t])..
      qEmmCE[em,es,e,t] =E= uEmmCE[em,es,e,t] * qCEpj[es,e,t]/fqt[t];

    qEmmCE&_BioNatgas[em,es,e,t]$(d1EmmCE[em,es,e,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio'])..
      qEmmCE[em,es,e,t] =E= sBioNatGas[t] * uEmmCE[em,es,e,t] * qCEpj[es,e,t]/fqt[t];

    qEmmCE&_FossileNatgas[em,es,e,t]$(d1EmmCE[em,es,e,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2ubio'])..
      qEmmCE[em,es,e,t] =E= (1-sBioNatGas[t]) * uEmmCE[em,es,e,t] * qCEpj[es,e,t]/fqt[t];

  #Non-energy related emissions 
    #Firms
    qEmmRxE[em,i,t]$(d1EmmRxE[em,i,t])..
      qEmmRxE[em,i,t] =E= uEmmRxE[em,i,t] * qProd['RxE',i,t]/fqt[t];

    #Consumers
    qEmmCxE[em,t]$(d1EmmCxE[em,t])..
      qEmmCxE[em,t] =E= uEmmCxE[em,t]; # * qProd['RxE',i,t]/fqt[t]; #AKB: Need to be coupled with consumption module

    
$ENDBLOCK 