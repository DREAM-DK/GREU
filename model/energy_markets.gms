# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	$IF %stage% == "variables":
		#DEMAND PRICES
			$SetGroup+ SG_flat_after_last_data_year
				d1pEpj_base[es,e,d,t] ""
				d1tqEpj[es,e,d,t] ""
			;
			
			$Group+ all_variables
				pEpj_base[es,e,d,t]$(d1pEpj_base[es,e,d,t]) 								"Base price of energy for demand sector d, measured in bio. kroner per PJ (or equivalently 1000 DKR per GJ)"
				pEpj[es,e,d,t]$(d1pEpj_base[es,e,d,t] or d1tqEpj[es,e,d,t]) "Price of energy, including taxes and margins, for demand sector d, defined if either a base price or a quantity-tax exists, measured in bio. kroner per PJ (or equivalently 1000 DKR per GJ)"
				tpE[es,e,d,t]$(d1pEpj_base[es,e,d,t]) 										 "Aggregate marginal tax-rate on priced energy, measured as a mark-up over base price"
				tqE[es,e,d,t]$(d1tqEpj[es,e,d,t]) 												 "Aggregate marginal tax-rate on non-priced energy, measured as bio. kroner per PJ (or equivalently 1000 DKR per GJ)" 
				fpE[es,e,d,t]$(d1pEpj_base[es,e,d,t]) 										 "Sector average margin between average supplier price, and sector base price"
			;


			$Group G_energy_markets_prices_data 
				pEpj_base[es,e,d,t]
			;

		#MARKET-CLEARING
			$SetGroup+ SG_flat_after_last_data_year 
				d1pY_CET[out,i,t] ""
				d1pM_CET[out,i,t] ""
				d1qY_CET[out,i,t] ""
				d1qM_CET[out,i,t] ""

				d1pE_avg[e,t] ""
				d1OneSX[out,t] ""
				d1OneSX_y[out,i,t] ""
				d1OneSX_m[out,i,t] ""
				d1qTL[es,e,t] ""

				d1pREa[es,e_a,i,t] "" #Skal flyttes til industries_CES_energydemand.gms, når vi får stages
			;

			$Group+ all_variables
						pE_avg[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t]))    "Average supply price of ergy"
						pM_CET[out,i,t]$(d1pM_CET[out,i,t])                          "M"
						qY_CET[out,i,t]$(d1pY_CET[out,i,t])                          "Domestic production of various products and services - the set 'out' contains all out puts of the economy, for energy the output is measured in PJ and non-energy in bio. DKK base 2019"
						qM_CET[out,i,t]$(d1pM_CET[out,i,t])                          "Import of various products and services - the set 'out' contains all out puts of the economy, for energy the output is measured in PJ and non-energy in bio. DKK base 2019"
						qEtot[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t]))     "Total demand/supply of ergy in the models ergy-market"
						qREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t]) 									 "Industries demand for energy activity (e_a). When abatement is turned off, the energy-activity is measured in PJ, and corresponds 1:1 to qEpj"		#Skal flyttes til industries_CES_energydemand.gms, når vi får stages
						qEpj[es,e,d,t]$(d1pEpj_base[es,e,d,t] or tl[d]) "Sector demand for energy on end purpose (es), measured in PJ"				
						j_abatement_qREa[es,e,i,t]$(d1pEpj_base[es,e,i,t])       "J-term to be activated by abatement-module. When abatement is on qREa =/= qEpj, but is guided by abatement module, endogenizing this variable"
						vDistributionProfits[e,t] 																"With different margins between average supply price, and sector base price, there is scope for what we call distribution profits. They can be negative. Measured in bio. DKK"
						sY_Dist[e,i,t]$(d1pY_CET[e,i,t]) 												"For the purpose of clearing energy markets, a fictive agent, the energy-distributor, gathers a bundle of domestically and imported energy, before selling it to the end-sector. This is the energy-distibutors preference parameter for domestic energy"
						sM_Dist[e,i,t]$(d1pM_CET[e,i,t]) 												"For the purpose of clearing energy markets, a fictive agent, the energy-distributor, gathers a bundle of domestically and imported energy, before selling it to the end-sector. This is the energy-distibutors preference parameter for imported energy"
						eDist[out] 																							"The energy distributors elasticity of demand between different energy suppliers"    
						pY_CET[out,i,t]$(d1pY_CET[out,i,t]) 										"Move to production at later point" 
			;


			$Group G_energy_markets_clearing_data 
				qY_CET 
				qM_CET
				pY_CET 
				pM_CET 
				pE_avg 
				qEtot
				qEpj
			;

			#RETAIL AND WHOLESALE MARGINS ON eRGY 
			$SetGroup+ SG_flat_after_last_data_year 
					d1pEAV[es,e,d,t] ""
					d1pDAV[es,e,d,t] ""
					d1pCAV[es,e,d,t] ""
			;

			$Group+ all_variables
				pEAV[es,e,d,t]$(d1pEAV[es,e,d,t]) "Wholesale margin on energy-goods, measured in bio. DKK per PJ (or equivalently 1000 DKK per GJ)"
				pDAV[es,e,d,t]$(d1pDAV[es,e,d,t]) "Retail margin on energy-goods, measured in bio. DKK per PJ (or equivalently 1000 DKK per GJ)"
				pCAV[es,e,d,t]$(d1pCAV[es,e,d,t]) "Car dealerships margin on energy-goods, measured in bio. DKK per PJ (or equivalently 1000 DKK per GJ)"

				vEAV[es,e,d,t]$(d1pEAV[es,e,d,t]) "Value of wholesale margin on energy-goods, measured in bio. DKK"
				vDAV[es,e,d,t]$(d1pDAV[es,e,d,t]) "Value of retail margin on energy-goods, measured in bio. DKK"
				vCAV[es,e,d,t]$(d1pCAV[es,e,d,t]) "Value of car dealerships margin on energy-goods, measured in bio. DKK"

				vOtherDistributionProfits_EAV[t] "Total value of wholesale margin on energy-goods, measured in bio. DKK"
				vOtherDistributionProfits_DAV[t] "Total value of retail on energy-goods, measured in bio. DKK"
				vOtherDistributionProfits_CAV[t] "Total value of car dealerships on energy-goods, measured in bio. DKK"

				fpEAV[es,e,d,t]$(d1pEAV[es,e,d,t]) "Sector specific margin between average wholesale price and the sector specific margin"
				fpDAV[es,e,d,t]$(d1pDAV[es,e,d,t]) "Sector specific margin between average retail price and the sector specific margin"
				fpCAV[es,e,d,t]$(d1pCAV[es,e,d,t]) "Sector specific margin between average car dealership price and the sector specific margin"
			;

			$Group G_energy_markets_margins_data 
				vEAV 
				vDAV 
				vCAV
			;

		#AGGREGATE DATA-GROUP 

				$Group G_energy_markets_data
					G_energy_markets_prices_data
					G_energy_markets_clearing_data 
					G_energy_markets_margins_data 
				;
	$ENDIF 

	# ------------------------------------------------------------------------------
	# Equations
	# ------------------------------------------------------------------------------

	$IF %stage% == "equations":
		# ------------------------------------------------------------------------------
		# Demand prices
		# ------------------------------------------------------------------------------

		$BLOCK energy_demand_prices energy_demand_prices_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 

			.. pEpj_base[es,e,d,t] =E= (1+fpE[es,e,d,t]) * pE_avg[e,t];

			.. pEpj[es,e,d,t] =E= (1+tpE[es,e,d,t]) * pEpj_base[es,e,d,t];

		$ENDBLOCK

	# ------------------------------------------------------------------------------
	# Market clearing
	# ------------------------------------------------------------------------------

	$BLOCK energy_markets_clearing energy_markets_clearing_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

		qY_CET&_SeveralNonExoSuppliers[e,i,t]$(not d1OneSX[e,t])..
				qY_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_Dist[e,i_a,t] * pY_CET[e,i_a,t] ** (-eDist[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_Dist[e,i_a,t] * pM_CET[e,i_a,t]**(-eDist[e]))) 
									=E= sY_Dist[e,i,t] * pY_CET[e,i,t] **(-eDist[e]) * qEtot[e,t];

		qM_CET&_SeveralNonExoSuppliers[e,i,t]$(not d1OneSX[e,t])..
				qM_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_Dist[e,i_a,t] * pY_CET[e,i_a,t] ** (-eDist[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_Dist[e,i_a,t] * pM_CET[e,i_a,t]**(-eDist[e]))) 
									=E= sM_Dist[e,i,t] * pM_CET[e,i,t] **(-eDist[e]) * qEtot[e,t];




		pE_avg[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t])).. pE_avg[e,t] * qEtot[e,t] =E=  sum(i$(d1pY_CET[e,i,t]), pY_CET[e,i,t]*qY_CET[e,i,t]) 
															+ sum(i$(d1pM_CET[e,i,t]), pM_CET[e,i,t]*qM_CET[e,i,t]);


		#Supply by one side
		qY_CET&_OneSupplierOrExoSuppliers[e,i,t]$(d1OneSX_y[e,i,t]).. qY_CET[e,i,t] =E= qEtot[e,t] - sum(i_a, qM_CET[e,i_a,t]);
		qM_CET&_OneSupplierOrExoSuppliers[e,i,t]$(d1OneSX_m[e,i,t]).. qM_CET[e,i,t] =E= qEtot[e,t] - sum(i_a, qY_CET[e,i_a,t]);


		.. qEtot[e,t] =E= sum((es,d)$(d1pEpj_base[es,e,d,t] or tl[d]), qEpj[es,e,d,t]);

		.. vDistributionProfits[e,t] =E= sum((es,d), pEpj_base[es,e,d,t] * qEpj[es,e,d,t])
																															- sum(i,   pY_CET[e,i,t] * qY_CET[e,i,t])
																															- sum(i,   pM_CET[e,i,t] * qM_CET[e,i,t]);

	#Clearing demand for ergy margins
	qY_CET&WholeAndRetailSaleMarginE_Wholesale46000[out,i,t]$(energyDistmargin[out] and i_wholesale[i]).. 
		qY_CET['WholeAndRetailSaleMarginE','46000',t]	
					=E=  
					sum((es,e,d)$(d1pEAV[es,e,d,t]), qEpj[es,e,d,t])	
					;

	qY_CET&WholeAndRetailSaleMarginE_Cardealerships45000[out,i,t]$(energyDistmargin[out] and i_cardealers[i]).. 
		qY_CET['WholeAndRetailSaleMarginE','45000',t]	
					=E=  
					sum((es,e,d)$(d1pCAV[es,e,d,t]), qEpj[es,e,d,t])			
					;

	qY_CET&WholeAndRetailSaleMarginE_Retail[out,i,t]$(energyDistmargin[out] and i_retail[i]).. 
		qY_CET['WholeAndRetailSaleMarginE','47000',t]	
					=E=  
					sum((es,e,d)$(d1pDAV[es,e,d,t]), qEpj[es,e,d,t])				
					;


    $ENDBLOCK 

		$BLOCK energy_markets_clearing_link energy_markets_clearing_link_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
			#Link til industries_CES_energydemand		
			qEpj[es,e,i,t]$(d1pEpj_base[es,e,i,t])..
			 qEpj[es,e,i,t] =E= qREa[es,e,i,t] + j_abatement_qREa[es,e,i,t];
		
		$ENDBLOCK  


	# ------------------------------------------------------------------------------
	# Retail and wholesale margins on ergy
	# ------------------------------------------------------------------------------

      $BLOCK energy_margins energy_margins_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 

				.. pEAV[es,e,d,t] =E=  (1+fpEAV[es,e,d,t]) * pY_CET['WholeAndRetailSaleMarginE','46000',t];

				.. pDAV[es,e,d,t] =E= (1+fpDAV[es,e,d,t]) * pY_CET['WholeAndRetailSaleMarginE','47000',t];

				.. pCAV[es,e,d,t] =E= (1+fpCAV[es,e,d,t]) * pY_CET['WholeAndRetailSaleMarginE','45000',t];

				.. vEAV[es,e,d,t] =E=  pEAV[es,e,d,t] * qEpj[es,e,d,t];

				.. vDAV[es,e,d,t] =E= pDAV[es,e,d,t]  * qEpj[es,e,d,t];

				.. vCAV[es,e,d,t] =E= pCAV[es,e,d,t]  * qEpj[es,e,d,t];

				..  vOtherDistributionProfits_EAV[t] =E= sum((es,e,d), vEAV[es,e,d,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','46000',t]*qY_CET['WholeAndRetailSaleMarginE','46000',t]
                                              ;

       
        ..  vOtherDistributionProfits_DAV[t] =E= sum((es,e,d), vCAV[es,e,d,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','47000',t]*qY_CET['WholeAndRetailSaleMarginE','47000',t]
                                              ;


	      ..  vOtherDistributionProfits_CAV[t] =E= sum((es,e,d), vDAV[es,e,d,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','45000',t]*qY_CET['WholeAndRetailSaleMarginE','45000',t]
                                              ;
      $ENDBLOCK

		# Add equation and endogenous variables to main model
		model main / energy_demand_prices  
								energy_markets_clearing 
								energy_margins
								energy_markets_clearing_link
								/;

		$Group+ main_endogenous 
				energy_demand_prices_endogenous 
				energy_markets_clearing_endogenous 
				energy_margins_endogenous
				energy_markets_clearing_link_endogenous
				;
	$ENDIF 

# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------

	$IF %stage% == "exogenous_values":
	  	@inf_growth_adjust()
			@load(G_energy_markets_data, "../data/data.gdx")
			@remove_inf_growth_adjustment()

			$Group+ data_covered_variables
				G_energy_markets_data$(t.val <= %calibration_year%)
			;


		# ------------------------------------------------------------------------------
		# Exogenous variables
		# ------------------------------------------------------------------------------

		eDist.l[e] = 5;

		# ------------------------------------------------------------------------------
		# Dummies
		# ------------------------------------------------------------------------------
			
		#Energy demand prices
		d1pEpj_base[es,e,d,t]  = yes$(pEpj_base.l[es,e,d,t]);

		#Market clearing
		d1OneSX[e,t] = yes;
		d1OneSX[e,t] = no$(straw[e] or el[e] or distheat[e]); #For straw, electricity and district heat, supply and demand is linked by the equations qY_CET&_SeveralNonExoSuppliers and qM_CET&_SeveralNonExoSuppliers

		#d1OneSX is one for all cases, except straw electricity and district heat before the two lines below. The lines ensure that there is also energy in the data.
		d1OneSX_y[e,i,t] = yes$(d1OneSX[e,t] and sum(i_a, d1pY_CET[e,i_a,t])); 
		d1OneSX_m[e,i,t] = yes$(d1OneSX[e,t] and sum(i_a, d1pM_CET[e,i_a,t]));

		d1pE_avg[e,t] = yes$(pE_avg.l[e,t]);

		d1pY_CET[out,i,t] = yes$(pY_CET.l[out,i,t]);
		d1qY_CET[out,i,t] = yes$(qY_CET.l[out,i,t]);

		d1pM_CET[out,i,t] = yes$(pM_CET.l[out,i,t]);
		d1qM_CET[out,i,t] = yes$(qM_CET.l[out,i,t]);


		#Margins 
		d1pEAV[es,e,d,t]    = yes$(vEAV.l[es,e,d,t]);
		d1pDAV[es,e,d,t]    = yes$(vDAV.l[es,e,d,t]);
		d1pCAV[es,e,d,t]    = yes$(vCAV.l[es,e,d,t]);

	$ENDIF
# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":
	$BLOCK energy_markets_clearing_calibration energy_markets_clearing_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

			qY_CET&_SeveralNonExoSuppliers_calib[e,i,t]$(t.val > t1.val and not d1OneSX[e,t])..
					qY_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_Dist[e,i_a,t] * pY_CET[e,i_a,t] ** (-eDist[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_Dist[e,i_a,t] * pM_CET[e,i_a,t]**(-eDist[e]))) 
										=E= sY_Dist[e,i,t] * pY_CET[e,i,t] **(-eDist[e]) * qEtot[e,t];

			qM_CET&_SeveralNonExoSuppliers_calib[e,i,t]$(t.val > t1.val and not d1OneSX[e,t])..
					qM_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_Dist[e,i_a,t] * pY_CET[e,i_a,t] ** (-eDist[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_Dist[e,i_a,t] * pM_CET[e,i_a,t]**(-eDist[e]))) 
										=E= sM_Dist[e,i,t] * pM_CET[e,i,t] **(-eDist[e]) * qEtot[e,t];


			sY_Dist[e,i,t]$(t1[t] and not d1OneSX[e,t]).. sY_Dist[e,i,t] =E= qY_CET[e,i,t]/qEtot[e,t] * pY_CET[e,i,t]**eDist[e];

			sM_Dist[e,i,t]$(t1[t] and not d1OneSX[e,t]).. sM_Dist[e,i,t] =E= qM_CET[e,i,t]/qEtot[e,t] * pM_CET[e,i,t]**eDist[e];

	$ENDBLOCK


	# Add equations and calibration equations to calibration model
	model calibration /
		energy_demand_prices

		energy_markets_clearing
		-E_qY_CET_SeveralNonExoSuppliers
		-E_qM_CET_SeveralNonExoSuppliers
		energy_markets_clearing_calibration

		energy_margins
		energy_markets_clearing_link
	/;
	# Add endogenous variables to calibration model
	$Group calibration_endogenous
		energy_demand_prices_endogenous 
		fpE[es,e,d,t1],  -pEpj_base[es,e,d,t1]

		energy_markets_clearing_endogenous
		energy_markets_clearing_calibration_endogenous
		sY_Dist$(t1[t] and d1pY_CET[e,i,t] and not d1OneSX[e,t]),  -qY_CET$(t1[t] and d1pY_CET[out,i,t] and not d1OneSX[out,t] and e[out]) 
		sM_Dist$(t1[t] and d1pM_CET[e,i,t] and not d1OneSX[e,t]),  -qM_CET$(t1[t] and d1pM_CET[out,i,t] and not d1OneSX[out,t] and e[out]) 

		energy_margins_endogenous
		fpEAV[es,e,d,t1],    -vEAV[es,e,d,t1]	
		fpDAV[es,e,d,t1],    -vDAV[es,e,d,t1]
		fpCAV[es,e,d,t1],    -vCAV[es,e,d,t1]

		energy_markets_clearing_link_endogenous

		calibration_endogenous
	;
$ENDIF