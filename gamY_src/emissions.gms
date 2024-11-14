# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
	#BOTTOM-UP EMISSIONS
		$PGROUP PG_emissions_BU_dummies
	      d1EmmCE[em,es,e,t]
	      d1EmmCxE[em,t]
	      d1EmmRE[em,es,e,i,t]
	      d1EmmRxE[em,i,t]

        d1Sbionatgas[t]
		;	

		$PGROUP PG_emissions_BU_flat_dummies 
			PG_emissions_BU_dummies  
		;


		$GROUP G_emissions_BU_quantities 
			qEmmRE[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t]) "Industries emissions related to combustion of energy e for energy-service es, measured in kilotonnes emitted gas"
			qEmmRxE[em,i,t]$(d1EmmRxE[em,i,t]) "Industries emissions not related to combustion of energy. Measured in kilotonnes emitted gas"
			qEmmCE[em,es,e,t]$(d1EmmCE[em,es,e,t]) "Consumers emissions related to combustion of energy. Measured in kilotonnes emitted gas"
      qEmmCxE[em,t]$(d1EmmCxE[em,t]) "Consumers emissions not related to combustion of energy. Measured in kilotonnes emitted gas" 

    ;

		$GROUP G_emissions_BU_other
			uEmmRE[em,es,e,i,t]$(d1EmmRE[em,es,e,i,t]) "Unit emissions related to combustion of energy e for energy-service es, measured in kilotonnes emitted gas per unit of energy"
			uEmmRxE[em,i,t]$(d1EmmRxE[em,i,t]) "Unit emissions not related to combustion of energy. Measured in kilotonnes emitted gas per unit of energy"

			uEmmCE[em,es,e,t]$(d1EmmCE[em,es,e,t]) "Unit emissions related to combustion of energy. Measured in kilotonnes emitted gas per unit of energy"
			uEmmCxE[em,t]$(d1EmmCxE[em,t]) "Unit emissions not related to combustion of energy. Measured in kilotonnes emitted gas per unit of energy"

			sBioNatGas[t]$(d1Sbionatgas[t]) "Share of bio-natural gas in total natural gas consumption"


		;

		$GROUP G_emissions_BU_flat_after_last_data_year 
			G_emissions_BU_quantities
			G_emissions_BU_other
		;

    #AKB: It would be nice to have an "add from group, but excluding dummies feature"
		$GROUP G_emissions_BU_data 
      qEmmRE
      qEmmRxE
      qEmmCE
      qEmmCxE
      sBioNatGas
      # G_emissions_other
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

    $GROUP G_emissions_aggregates_flat_after_last_data_year
      G_emissions_aggregates_quantities
      G_emissions_aggregates_other
    ;

    $GROUP G_emissions_aggregates_data 
      qEmmTot
      qEmmLULUCF5
      qEmmLULUCF
      GWP
      # G_emissions_aggregates_quantities
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

	#Add dummies to main flat-group 
	$PGROUP+ PG_flat_after_last_data_year
		PG_emissions_BU_flat_dummies
    PG_emissions_aggregates_flat_dummies
	;
		# Add dummies to main groups
	$GROUP+ G_flat_after_last_data_year
		G_emissions_BU_flat_after_last_data_year
    G_emissions_aggregates_flat_after_last_data_year
	;


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

  #BLOCK 1/3, BOTTOM-UP EMISSIONS
  $BLOCK emissions_BU emissions_BU_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    #Energy-related emissions
      #Firms
      qEmmRE&_notNatgas[em,es,e,i,t]$(d1pREpj_base[es,e,i,t] and d1EmmRE[em,es,e,i,t] and not sameas[em,'CO2e'] and not (sameas[e,'Natural gas incl. biongas'] and (sameas[em,'CO2ubio'] or sameas[em,'CO2bio'])))..
        qEmmRE[em,es,e,i,t] =E= uEmmRE[em,es,e,i,t] * qREpj[es,e,i,t]*fqt[t];

      qEmmRE&_BioNatgas[em,es,e,i,t]$(d1pREpj_base[es,e,i,t] and d1EmmRE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio'])..
        qEmmRE[em,es,e,i,t] =E= sBioNatGas[t] * uEmmRE[em,es,e,i,t] * qREpj[es,e,i,t]*fqt[t];

      qEmmRE&_FossileNatgas[em,es,e,i,t]$(d1pREpj_base[es,e,i,t] and d1EmmRE[em,es,e,i,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2ubio'])..
        qEmmRE[em,es,e,i,t] =E= (1-sBioNatGas[t]) * uEmmRE[em,es,e,i,t] * qREpj[es,e,i,t]*fqt[t];

      qEmmRE&_CO2e[em,es,e,i,t]$(d1pREpj_base[es,e,i,t] and d1EmmRE[em,es,e,i,t] and sameas[em,'CO2e'])..
        qEmmRE['CO2e',es,e,i,t] =E= sum(em_a$(not sameas[em_a,'CO2e']), GWP[em_a] * qEmmRE[em_a,es,e,i,t]);

      #Consumers
      qEmmCE&_notNatgas[em,es,e,t]$(d1pCEpj_base[es,e,t] and d1EmmCE[em,es,e,t] and not sameas[em,'CO2e'] and not (sameas[e,'Natural gas incl. biongas'] and (sameas[em,'CO2ubio'] or sameas[em,'CO2bio'])))..
        qEmmCE[em,es,e,t] =E= uEmmCE[em,es,e,t] * qCEpj[es,e,t]*fqt[t];

      qEmmCE&_BioNatgas[em,es,e,t]$(d1pCEpj_base[es,e,t] and d1EmmCE[em,es,e,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2bio'])..
        qEmmCE[em,es,e,t] =E= sBioNatGas[t] * uEmmCE[em,es,e,t] * qCEpj[es,e,t]*fqt[t];

      qEmmCE&_FossileNatgas[em,es,e,t]$(d1pCEpj_base[es,e,t] and d1EmmCE[em,es,e,t] and sameas[e,'Natural gas incl. biongas'] and sameas[em,'CO2ubio'])..
        qEmmCE[em,es,e,t] =E= (1-sBioNatGas[t]) * uEmmCE[em,es,e,t] * qCEpj[es,e,t]*fqt[t];

      qEmmCE&_CO2e[em,es,e,t]$(d1pCEpj_base[es,e,t] and d1EmmCE[em,es,e,t] and sameas[em,'CO2e'])..
        qEmmCE['CO2e',es,e,t] =E= sum(em_a$(not sameas[em_a,'CO2e']), GWP[em_a] * qEmmCE[em_a,es,e,t]);

    #Non-energy related emissions 
      #Firms
      qEmmRxE[em,i,t]$(d1EmmRxE[em,i,t] and not sameas[em,'CO2e'])..
        qEmmRxE[em,i,t] =E= uEmmRxE[em,i,t] * qProd['RxE',i,t]*fqt[t];

      qEmmRxE&_CO2e[em,i,t]$(d1EmmRxE[em,i,t] and sameas[em,'CO2e'])..
        qEmmRxE['CO2e',i,t] =E= sum(em_a$(not sameas[em_a,'CO2e'] and d1EmmRxE[em_a,i,t]), GWP[em_a] * qEmmRxE[em_a,i,t]); 
                                                              #AKB: Hmm, troede ikke dummies i ovenstående sum skulle være nødvendige med nye setup. Undersøg, hvorfor
      #Consumers
      qEmmCxE[em,t]$(d1EmmCxE[em,t] and not sameas[em,'CO2e'])..
        qEmmCxE[em,t] =E= uEmmCxE[em,t]; # * qProd['RxE',i,t]*fqt[t]; #AKB: Need to be coupled with consumption module

      qEmmCxE&_CO2e[em,t]$(d1EmmCxE[em,t] and sameas[em,'CO2e'])..    
        qEmmCxE['CO2e',t] =E= sum(em_a$(not sameas[em_a,'CO2e'] and d1EmmCxE[em,t]), GWP[em_a] * qEmmCxE[em_a,t]);

  $ENDBLOCK 

  #BLOCK 2/3 EMISSIONS AGGREGATES - CAN RUN SEPARATELY OF BOTTOM-UP EMISSIONS. WHEN LINKING 1 AND 2 (THROUGH 3) CALIBRATION VARAIBLES IN 2 ARE ENDOGENIZED TO MATCH BOTTOM-UP EMISSIONS
  $BLOCK emissions_aggregates emissions_aggregates_endogenous $(t1.val <= t.val and t1.val <=tEnd.val)
      #Energy-related emissions
      qEmmE&_production[em,i,t]$(d1EmmE[em,i,t] and not sameas[em,'CO2e'])..
        qEmmE[em,i,t] =E= uEmmE[em,i,t] * (qProd['Machine_energy',i,t] + qProd['Transport_energy',i,t] + qProd['Heating_energy',i,t])*fqt[t];

      qEmmE&not_production[em,d,t]$(d1EmmE[em,d,t] and not i[d] and not sameas[em,'CO2e'])..
        qEmmE[em,d,t] =E= uEmmE[em,d,t];

      qEmmE&_CO2e[em,d,t]$(d1EmmE[em,d,t] and sameas[em,'CO2e'])..
        qEmmE['CO2e',d,t] =E= sum(em_a$(not sameas[em_a,'CO2e']), GWP[em_a] * qEmmE[em_a,d,t]); 

      Non-energy related emissions
      qEmmxE&_production[em,i,t]$(d1EmmxE[em,i,t] and not sameas[em,'CO2e'])..
        qEmmxE[em,i,t] =E= uEmmxE[em,i,t] * sum(pf_top, (qProd[pf_top,i,t]*fqt[t]));

      qEmmxE&not_production[em,d,t]$(d1EmmxE[em,d,t] and not i[d] and not sameas[em,'CO2e'])..
        qEmmxE[em,d,t] =E= uEmmxE[em,d,t];

      qEmmxE&_CO2e[em,d,t]$(d1EmmxE[em,d,t] and sameas[em,'CO2e'])..
        qEmmxE['CO2e',d,t] =E= sum(em_a$(not sameas[em_a,'CO2e']), GWP[em_a] * qEmmxE[em_a,d,t]);


      # LULUCF (is measured in CO2e from the get-go)
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
      uEmmE&_production_link[em,i,t]$(d1EmmE[em,i,t] and not sameas[em,'CO2e'])..
          qEmmE[em,i,t] =E= sum((e,es)$(d1pREpj_base[es,e,i,t] and d1EmmRE[em,es,e,i,t]), qEmmRE[em,es,e,i,t]);
                              #AKB: @Martin: Hvorfor er mine dummies i ovenstående nødvendige?

      uEmmE&_cHouEne_link[em,d,t]$(d1EmmE[em,d,t] and sameas[d,'cHouEne'] and not sameas[em,'CO2e'])..
          qEmmE[em,d,t] =E= sum((e,es)$(not sameas[es,'Transport']), qEmmCE[em,es,e,t]);

      uEmmE&_cCarEne_link[em,d,t]$(d1EmmE[em,d,t] and sameas[d,'cCarEne'] and not sameas[em,'CO2e'])..
          qEmmE[em,d,t] =E= sum((e,es)$(sameas[es,'Transport']), qEmmCE[em,es,e,t]);


      #Non-energy related emissions
      uEmmxE&_production_link[em,i,t]$(d1EmmxE[em,i,t] and not sameas[em,'CO2e'])..
          qEmmxE[em,i,t] =E= qEmmRxE[em,i,t];

      uEmmxE&_cNonFood_link[em,d,t]$(d1EmmxE[em,d,t] and sameas[d,'cNonFood'] and not sameas[em,'CO2e'])..
          qEmmxE[em,d,t] =E= qEmmCxE[em,t];

  $ENDBLOCK 

model main / 
            emissions_aggregates 
            emissions_BU
            emissions_aggregates_link
            /;
            
$GROUP+ main_endogenous 
  emissions_aggregates_endogenous
  emissions_BU_endogenous
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

  qEmmE.l[em,i,t]         = sum((es,e)$(d1pREpj_base[es,e,i,t]), qEmmRE.l[em,es,e,i,t]);
  qEmmE.l[em,'cHouEne',t] = sum((es,e)$(not sameas[es,'Transport'] and d1pCEpj_base[es,e,t]), qEmmCE.l[em,es,e,t]); 
  qEmmE.l[em,'cCarEne',t] = sum((es,e)$(sameas[es,'Transport'] and d1pCEpj_base[es,e,t]),     qEmmCE.l[em,es,e,t]); 

  qEmmxE.l[em,i,t]          = qEmmRxE.l[em,i,t];
  qEmmxE.l[em,'cNonFood',t] = qEmmCxE.l[em,t]; 

# ------------------------------------------------------------------------------
# Dummies
# ------------------------------------------------------------------------------

  d1EmmCE[em,es,e,t]         = yes$(qEmmCE.l[em,es,e,t]);
  d1EmmCxE[em,t]             = yes$(qEmmCxE.l[em,t]);
  d1EmmRE[em,es,e,i,t]       = yes$(qEmmRE.l[em,es,e,i,t]);
  d1EmmRxE[em,i,t]           = yes$(qEmmRxE.l[em,i,t]);
  d1EmmE[em,d,t]             = yes$(qEmmE.l[em,d,t]);
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
  emissions_aggregates
  emissions_BU
  emissions_aggregates_link
/;

# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  emissions_aggregates_endogenous
  uEmmE[em,i,t1]$(not sameas[em,'CO2e']),               -qEmmE[em,i,t1]$(not sameas[em,'CO2e'])
  uEmmE[em,d,t1]$(not i[d] and not sameas[em,'CO2e']),  -qEmmE[em,d,t1]$(not i[d] and not sameas[em,'CO2e'])
  uEmmxE[em,i,t1]$(not sameas[em,'CO2e']),              -qEmmxE[em,i,t1]$(not sameas[em,'CO2e'])
  uEmmxE[em,d,t1]$(not i[d] and not sameas[em,'CO2e']), -qEmmxE[em,d,t1]$(not i[d] and not sameas[em,'CO2e'])
  uEmmLULUCF5[land5,t1],                                -qEmmLULUCF5[land5,t1]

  emissions_BU_endogenous
  uEmmRE[em,es,e,i,t1]$(not sameas[em,'CO2e']), -qEmmRE[em,es,e,i,t1]$(not sameas[em,'CO2e'])
  uEmmCE[em,es,e,t1]$(not sameas[em,'CO2e']),   -qEmmCE[em,es,e,t1]$(not sameas[em,'CO2e'])
  uEmmRxE[em,i,t1]$(not sameas[em,'CO2e']),     -qEmmRxE[em,i,t1]$(not sameas[em,'CO2e'])
  uEmmCxE[em,t1]$(not sameas[em,'CO2e']),       -qEmmCxE[em,t1]$(not sameas[em,'CO2e'])

  emissions_aggregates_link_endogenous
  qEmmE[em,i,t1]$(not sameas[em,'CO2e'])
  qEmmE[em,'cHouEne',t1]$(not sameas[em,'CO2e'])
  qEmmE[em,'cCarEne',t1]$(not sameas[em,'CO2e']) 
  qEmmxE[em,i,t1]$(not sameas[em,'CO2e'])
  qEmmxE[em,'cNonFood',t1]$(not sameas[em,'CO2e'])

  calibration_endogenous
;