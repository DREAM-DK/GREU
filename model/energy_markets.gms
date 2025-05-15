# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	$IF %stage% == "variables":
		#DEMAND PRICES
			$SetGroup+ SG_flat_after_last_data_year
				d1pEpj_base[es,e,d,t] "Dummy for energy with a base-price"
				d1qEpj[es,e,d,t] "Dummy for all energy in energy-balance, including non-priced energy"
			;
			
			$Group+ all_variables
				pEpj_base[es,e,d,t]$(d1pEpj_base[es,e,d,t]) 								"Base price of energy for demand sector d, measured in bio. kroner per PJ (or equivalently 1000 DKR per GJ)"
				pEpj_marg[es,e,d,t]$(d1pEpj[es,e,d,t]) "Price of energy, including taxes and margins, for demand sector d, defined if either a base price or a quantity-tax exists, measured in bio. kroner per PJ (or equivalently 1000 DKR per GJ)"
				pEpj[es,e,d,t]$(d1pEpj_base[es,e,d,t]) "Average price of energy"
				fpE[es,e,d,t]$(d1pEpj_base[es,e,d,t]) 										 "Sector average margin between average supplier price, and sector base price"

				vEpj_base[es,e,d,t]$(d1pEpj_base[es,e,d,t]) "Value of energy for demand sector d in base prices, measured in bio. kroner"
				vEpj[es,e,d,t]$(d1pEpj[es,e,d,t]) "Value of energy for demand sector d, measured in bio. kroner"
				vEpj_NAS[es,e,d,t]$(d1pEpj[es,e,d,t]) "Value of energy for demand sector d, excluding margins, measured in bio. kroner"
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


				d1OneSX[out,t] ""
				d1OneSX_y[out,t] ""
				d1OneSX_m[out,t] ""
				d1qTL[es,e,t] ""
			;


			$Group+ all_variables
						pE_avg[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t]))     "Average supply price of ergy"
						pM_CET[out,i,t]$(d1pM_CET[out,i,t])                          "M"
						qY_CET[out,i,t]$(d1pY_CET[out,i,t])                          "Domestic production of various products and services - the set 'out' contains all out puts of the economy, for energy the output is measured in PJ and non-energy in bio. DKK base 2019"
						qM_CET[out,i,t]$(d1pM_CET[out,i,t])                          "Import of various products and services - the set 'out' contains all out puts of the economy, for energy the output is measured in PJ and non-energy in bio. DKK base 2019"
						qEtot[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t]))      "Total demand/supply of ergy in the models ergy-market"
						qEpj[es,e,d,t]$(d1qEpj[es,e,d,t] or tl[d]) 					      	 "Sector demand for energy on end purpose (es), measured in PJ"				
						j_abatement_qREa[es,e,i,t]$(d1pEpj_base[es,e,i,t])       		 "J-term to be activated by abatement-module. When abatement is on qREa =/= qEpj, but is guided by abatement module, endogenizing this variable"
						vDistributionProfits[e,t] 																	 "With different margins between average supply price, and sector base price, there is scope for what we call distribution profits. They can be negative. Measured in bio. DKK"
						sY_Dist[e,i,t]$(d1pY_CET[e,i,t]) 														 "For the purpose of clearing energy markets, a fictive agent, the energy-distributor, gathers a bundle of domestically and imported energy, before selling it to the end-sector. This is the energy-distibutors preference parameter for domestic energy"
						sM_Dist[e,i,t]$(d1pM_CET[e,i,t]) 														 "For the purpose of clearing energy markets, a fictive agent, the energy-distributor, gathers a bundle of domestically and imported energy, before selling it to the end-sector. This is the energy-distibutors preference parameter for imported energy"
						eDist[out] 																									 "The energy distributors elasticity of demand between different energy suppliers"    
						pY_CET[out,i,t]$(d1pY_CET[out,i,t]) 												 "Move to production at later point" 
						vY_CET[out,i,t]$(d1pY_CET[out,i,t]) 												 "Move to production at later point"
						vM_CET[out,i,t]$(d1pM_CET[out,i,t]) 												 "Move to production at later point"
				;


			$Group G_energy_markets_clearing_data 
				qY_CET 
				qM_CET
				pY_CET 
				pM_CET 
				qEpj
			;

			#RETAIL AND WHOLESALE MARGINS ON ENERGY 
			$SetGroup+ SG_flat_after_last_data_year 
					d1pWMA[es,e,d,t] ""
					d1pRMA[es,e,d,t] ""
					d1pCMA[es,e,d,t] ""
			;

			$Group+ all_variables
				pWMA[es,e,d,t]$(d1pWMA[es,e,d,t]) "Wholesale margin on energy-goods, measured in bio. DKK per PJ (or equivalently 1000 DKK per GJ)"
				pRMA[es,e,d,t]$(d1pRMA[es,e,d,t]) "Retail margin on energy-goods, measured in bio. DKK per PJ (or equivalently 1000 DKK per GJ)"
				pCMA[es,e,d,t]$(d1pCMA[es,e,d,t]) "Car dealerships margin on energy-goods, measured in bio. DKK per PJ (or equivalently 1000 DKK per GJ)"

				vWMA[es,e,d,t]$(d1pWMA[es,e,d,t]) "Value of wholesale margin on energy-goods, measured in bio. DKK"
				vRMA[es,e,d,t]$(d1pRMA[es,e,d,t]) "Value of retail margin on energy-goods, measured in bio. DKK"
				vCMA[es,e,d,t]$(d1pCMA[es,e,d,t]) "Value of car dealerships margin on energy-goods, measured in bio. DKK"

				vOtherDistributionProfits_WMA[t] "Total value of difference in supply and demand of  wholesale margins on energy-goods, measured in bio. DKK. Currently modelled to produce zero-profit"
				vOtherDistributionProfits_RMA[t] "Total value of difference in supply and demand of  retail margins on energy-goods, measured in bio. DKK. Currently modelled to produce zero-profit"
				vOtherDistributionProfits_CMA[t] "Total value of difference in supply and demand of  car dealerships margins on energy-goods, measured in bio. DKK. Currently modelled to produce zero-profit"

				fpWMA[es,e,d,t]$(d1pWMA[es,e,d,t]) "Sector specific margin between average wholesale price and the sector specific margin"
				fpRMA[es,e,d,t]$(d1pRMA[es,e,d,t]) "Sector specific margin between average retail price and the sector specific margin"
				fpCMA[es,e,d,t]$(d1pCMA[es,e,d,t]) "Sector specific margin between average car dealership price and the sector specific margin"

				pD_WMA[t] ""
				pD_RMA[t] ""
				pD_CMA[t] ""

				qD_WMA[t] ""
				qD_RMA[t] ""
				qD_CMA[t] ""

				vD_WMA[t] ""
				vD_RMA[t] ""
				vD_CMA[t] ""


			;

			$Group G_energy_markets_margins_data 
				vWMA 
				vRMA 
				vCMA
			;


		#Energy-markets-IO-link
			$SetGroup+ SG_flat_after_last_data_year
				d1sSupply_d_e_i_adj[d,e,i,t] "Dummy coupling IO-entry (d x i) with energy-production in industry i (i x e)"
			;

			$Group+ all_variables
				sSupply_d_e_i_adj[d,e,i,t]$(d1Y_i_d[i,d,t] and d_ene[d] and d1pY_CET[e,i,t] and sum(es, sum(d_a, es_d2d(es,d_a,d) and d1pEpj_base[es,e,d_a,t]))) "Bounded share of total supply of energy (e) from domestic industry (i) delivered to (d), adjusted to match energy-IO"
				sSupply_d_e_i_adj_inp[d,e,i,t]$(d1Y_i_d[i,d,t] and d_ene[d] and d1pY_CET[e,i,t] and sum(es, sum(d_a,es_d2d(es,d_a,d) and d1pEpj_base[es,e,d_a,t]))) "Unbounded share of total supply of energy (e) from domestic industry (i) delivered to (d), adjusted to match energy-IO"
				adj_sSupply_d_e_i_adj[e,i,t]$(d1pY_CET[e,i,t]) "Adjustment parameter, allocating domestic supply of energy (e) from domestic industry (i) to demand-comp. (d)"
				j_adj_sSupply_d_e_i_adj[e,i] "Calibrating parameter in data-year, capturing difference in energybalance/energy-IO" 
				sSupply_d_e_i_adj_calib[d,i]  "Calibrating parameter from data-year capturing difference between economy-wide vY[e]/(vY[e]+vM[e]), and delivery to domestic IO-cell (d x e x i)"

				jvY_i_d_base[i,d,t]$(d1Y_i_d[i,d,t]) "Calibrating parameter in data-year, capturing difference in energybalance/energy-IO"
        jvM_i_d_base[i,d,t]$(d1M_i_d[i,d,t]) "Calibrating parameter in data-year, capturing difference in energybalance/energy-IO"

        sSupply_e_i_y[e,i,t]$(d1pY_CET[e,i,t]) "Domestic industry i's share of supplied energy of type (e) "
				jqY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) "Calibrating parameter in data-year, capturing difference in energybalance/energy-IO"
				jqM_i_d[i,d,t]$(d1M_i_d[i,d,t]) "Calibrating parameter in data-year, capturing difference in energybalance/energy-IO"


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

			#The base-price is the average price adjusted for demand-specific margin fpE
			.. pEpj_base[es,e,d,t] =E= (1+fpE[es,e,d,t]) * pE_avg[e,t];

			#Marginal price is base price plus the tax-wedge tpE_marg based on marginal tax-rates. See energy_and_emissions_taxes.gms
			pEpj_marg&_base[es,e,d,t]$(d1pEpj_base[es,e,d,t])..
			 pEpj_marg[es,e,d,t] =E= (1+tpE_marg[es,e,d,t]) * pEpj_base[es,e,d,t];

			pEpj_marg&_nonpriced[es,e,d,t]$(d1tqEpj[es,e,d,t])..
				pEpj_marg[es,e,d,t] =E= tqE_marg[es,e,d,t];

			#Average price is base price plus the tax-wedge tpE based on average tax-rates. See energy_and_emissions_taxes.gms
			.. pEpj[es,e,d,t] =E= (1+tpE[es,e,d,t]) * pEpj_base[es,e,d,t];
			
			#Value of energy-consumption in base prices
			.. vEpj_base[es,e,d,t] =E= pEpj_base[es,e,d,t] * qEpj[es,e,d,t];

			#Value of energy-consumption as per National Account Systems (NAS): Based on average tax-rates and excluding ETS
			.. vEpj_NAS[es,e,d,t] =E=  vEpj_base[es,e,d,t]
															 + vtE_NAS[es,e,d,t] #Total taxes, excluding ETS 
															;

			#Total value of energy-consumption in energy-balances is the value of energy in NAS including the three margin categories (RMA,WMA,CMA)
			.. vEpj[es,e,d,t] =E= vEpj_NAS[es,e,d,t] + vRMA[es,e,d,t] + vWMA[es,e,d,t] + vCMA[es,e,d,t];

			
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


		#When there is one supplier (domestic or imports) supply is set equal to demand
		qY_CET&_OneSupplier[e,i,t]$(d1OneSX_y[e,t] and not d1OneSX_m[e,t]).. qY_CET[e,i,t] =E= qEtot[e,t];
		qM_CET&_OneSupplier[e,i,t]$(d1OneSX_m[e,t] and not d1OneSX_y[e,t]).. qM_CET[e,i,t] =E= qEtot[e,t];

		#For exogenous domestic suppliers imports are residual
		qM_CET&_ExoSuppliers[e,i,t]$(d1OneSX_y[e,t] and d1OneSX_m[e,t]).. qM_CET[e,i,t] =E= qEtot[e,t] - sum(i_a, qY_CET[e,i_a,t]);


		.. qEtot[e,t] =E= sum((es,d)$(d1pEpj_base[es,e,d,t] or tl[d]), qEpj[es,e,d,t]);

		.. vDistributionProfits[e,t] =E= sum((es,d), pEpj_base[es,e,d,t] * qEpj[es,e,d,t])
																	  	- sum(i,   pY_CET[e,i,t] * qY_CET[e,i,t])
																	  	- sum(i,   pM_CET[e,i,t] * qM_CET[e,i,t]);
		#Values
		.. vY_CET[e,i,t] =E= pY_CET[e,i,t] * qY_CET[e,i,t];

		.. vM_CET[e,i,t] =E= pM_CET[e,i,t] * qM_CET[e,i,t];
    $ENDBLOCK 

		$BLOCK energy_markets_clearing_link energy_markets_clearing_link_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
			#Link til industries_CES_energydemand		
			qEpj[es,e,i,t]$(d1pEpj[es,e,i,t])..
			 qEpj[es,e,i,t] =E= qREa[es,e,i,t] + j_abatement_qREa[es,e,i,t];
		
		$ENDBLOCK  


	# ------------------------------------------------------------------------------
	# Retail and wholesale margins on ergy
	# ------------------------------------------------------------------------------

		$BLOCK energy_margins energy_margins_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 

			.. pWMA[es,e,d,t] =E=  fpWMA[es,e,d,t] * pY_CET['out_other','46000',t]/pY_CET['out_other','46000',tBase];

			.. pRMA[es,e,d,t] =E= fpRMA[es,e,d,t] * pY_CET['out_other','47000',t]/pY_CET['out_other','47000',tBase];

			.. pCMA[es,e,d,t] =E= fpCMA[es,e,d,t] * pY_CET['out_other','45000',t]/pY_CET['out_other','45000',tBase];

			.. vWMA[es,e,d,t] =E=  pWMA[es,e,d,t] * qEpj[es,e,d,t];

			.. vRMA[es,e,d,t] =E= pRMA[es,e,d,t]  * qEpj[es,e,d,t];

			.. vCMA[es,e,d,t] =E= pCMA[es,e,d,t]  * qEpj[es,e,d,t];

			.. vD_WMA[t] =E= sum((es,e,d), vWMA[es,e,d,t]); 
			.. vD_RMA[t] =E= sum((es,e,d), vRMA[es,e,d,t]); 
			.. vD_CMA[t] =E= sum((es,e,d), vCMA[es,e,d,t]);

			qD_WMA[t]..
					vD_WMA[t] =E= pD_WMA[t] * qD_WMA[t]; 
			qD_RMA[t]..
					vD_RMA[t] =E= pD_RMA[t] * qD_RMA[t]; 
			qD_CMA[t]..
					vD_CMA[t] =E= pD_CMA[t] * qD_CMA[t];

			.. pD_WMA[t] =E= pY_CET['out_other','46000',t];
			.. pD_RMA[t] =E= pY_CET['out_other','47000',t];
			.. pD_CMA[t] =E= pY_CET['out_other','45000',t];



			..  vOtherDistributionProfits_WMA[t] =E= vD_WMA[t]
																						- pY_CET['out_other','46000',t]*qD_WMA[t]
																						;

			
			..  vOtherDistributionProfits_RMA[t] =E= vD_RMA[t]
																						- pY_CET['out_other','47000',t]*qD_RMA[t]
																						;


			..  vOtherDistributionProfits_CMA[t] =E= vD_CMA[t]
																						- pY_CET['out_other','45000',t]*qD_CMA[t]
																						;
		$ENDBLOCK

		$BLOCK energy_markets_IO_link energy_markets_IO_link_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 
		#THIS BLOCK OF EQUATIONS LINK BOTTOM-UP ENERGY PRODUCTION AND CONSUMPTION WITH IO-CELLS IN INPUT_OUTPUT.GMS

		#Domestic supply of energy (e) from industry (i)'s share of total supply of e, measured in values
		..sSupply_e_i_y[e,i,t] =E= vY_CET[e,i,t]/sum(i_a, vY_CET[e,i_a,t] + vM_CET[e,i_a,t]);


		#Prices of energy have varying margins over (d). When the BU-level energy takes over input_output.gms the IO-margins, jfpY_i and jfpY_m are endogenized with the below equations
			jfpY_i_d&_not_energymargins[i,d,t]$(d1Y_i_d[i,d,t] and not i_energymargins[i] and d_ene[d])..
				vY_i_d_base[i,d,t]
					=E= sum((e,es,d_a)$es_d2d(es,d_a,d),  sSupply_d_e_i_adj[d,e,i,t] * vEpj_base[es,e,d_a,t]) + jvY_i_d_base[i,d,t]; 

			jfpY_i_d&_energymargins[i,d,t]$(d1Y_i_d[i,d,t] and i_energymargins[i] and d_ene[d])..
				vY_i_d_base[i,d,t] 
					=E= sum((e,es,d_a)$es_d2d(es,d_a,d), pRMA[es,e,d_a,t] * qEpj[es,e,d_a,t]$(i_retail[i]) 
																							+ pCMA[es,e,d_a,t] * qEpj[es,e,d_a,t]$(i_cardealers[i]) 
																							+ pWMA[es,e,d_a,t] * qEpj[es,e,d_a,t]$(i_wholesale[i])) + jvY_i_d_base[i,d,t]; 

									# No need to add an equation on imports for margins, as margins are produced domestically in data.
			jfpM_i_d[i,d,t]$(d1M_i_d[i,d,t] and d_ene[d])..
				vM_i_d_base[i,d,t]
					=E= sum((e,es,d_a)$es_d2d(es,d_a,d), (1-sum(i_a,sSupply_d_e_i_adj[d,e,i_a,t])) * vEpj_base[es,e,d_a,t]) + jvM_i_d_base[i,d,t]; 

		#Quantities of energy
			
			#The IO_cell qY_i_d is adjusted based on a chain-index of quantities at the bottom-level of energy qEpj and pEpj_base. Since the bottom-level does not sort demanded energy on origin (domestic or import),
			#the demand is split based on the varaible sSupply_d_e_i_adj. sSupply_d_e_i_adj is based don the economy-wide domestic share (sSupply_e_i_y a couple equations above this one). It is, however, adjusted
			#to reflect the energy-IO. sSupply_d_e_i_adj is also endogenous (see bottom of this block of equations) when running the model, adjusting the input-output coefficient to reflect changes in the Y/M split of energy
			#The IO-share rYM as well as the import-share rM0 are endogenized to reflect bottom-level in the equations below.
			#AKB: We could consider using a simpler quantity-index. The chain-indeces are kept for now though so as to be consistent with the method in NAS.

			rYM[i,d,t]$(d1Y_i_d[i,d,t] and not i_energymargins[i] and d_ene[d])..
				qY_i_d[i,d,t]*pY_i_d_base[i,d,t-1]=E=  sum((e,es,d_a)$es_d2d(es,d_a,d),  sSupply_d_e_i_adj[d,e,i,t] * pEpj_base[es,e,d_a,t-1] * qEpj[es,e,d_a,t])  + jqY_i_d[i,d,t];

	
			rYM&_energymargins[i,d,t]$(d1Y_i_d[i,d,t] and i_energymargins[i] and d_ene[d])..
				qY_i_d[i,d,t]*pY_i_d_base[i,d,t-1]  =E= sum((e,es,d_a)$es_d2d(es,d_a,d),  pRMA[es,e,d_a,t-1] * qEpj[es,e,d_a,t]$(i_retail[i]) 
																																								+ pCMA[es,e,d_a,t-1] * qEpj[es,e,d_a,t]$(i_cardealers[i]) 
																																								+ pWMA[es,e,d_a,t-1] * qEpj[es,e,d_a,t]$(i_wholesale[i])) + jqY_i_d[i,d,t];



			#NOTE THAT THIS IS RM0 (not RM), BECAUSE OF THE "IMPORTS.GMS"-MODULE THAT TAKES OVER RM IN INPUT_OUTPUT
			rM0&_energy_imports[i,d,t]$(d1M_i_d[i,d,t] and d1Y_i_d[i,d,t] and d_ene[d])..
				qM_i_d[i,d,t]*pM_i_d_base[i,d,t-1]  =E= sum((e,es,d_a)$es_d2d(es,d_a,d), (1-sum(i_a, sSupply_d_e_i_adj[d,e,i_a,t])) *  pEpj_base[es,e,d_a,t-1] * qEpj[es,e,d_a,t]) + jqM_i_d[i,d,t];

			rYM&_energy_imports[i,d,t]$(d1M_i_d[i,d,t] and not d1Y_i_d[i,d,t] and d_ene[d])..
				qM_i_d[i,d,t]*pM_i_d_base[i,d,t-1]  =E= sum((e,es,d_a)$es_d2d(es,d_a,d), (1-sum(i_a, sSupply_d_e_i_adj[d,e,i_a,t])) *  pEpj_base[es,e,d_a,t-1] * qEpj[es,e,d_a,t]) + jqM_i_d[i,d,t];

			#VERSION WITHOUT IMPORTS-MODULE TURNED ON - IN THIS CASE rM NEEDS TO BE ENDOGENIZED
			# rM&_energy_imports[i,d,t]$(d1M_i_d[i,d,t] and d1Y_i_d[i,d,t] and d_ene[d])..
				# qM_i_d[i,d,t]*pM_i_d_base[i,d,t-1]  =E= sum((e,es,d_a)$es_d2d(es,d_a,d), (1-sum(i_a, sSupply_d_e_i_adj[d,e,i_a,t])) *  pEpj_base[es,e,d_a,t-1] * qEpj[es,e,d_a,t]) + jqM_i_d[i,d,t];


			# rYM&_energy_imports[i,d,t]$(d1M_i_d[i,d,t] and not d1Y_i_d[i,d,t] and d_ene[d])..
				# qM_i_d[i,d,t]*pM_i_d_base[i,d,t-1]  =E= sum((e,es,d_a)$es_d2d(es,d_a,d), (1-sum(i_a, sSupply_d_e_i_adj[d,e,i_a,t])) *  pEpj_base[es,e,d_a,t-1] * qEpj[es,e,d_a,t]) + jqM_i_d[i,d,t];


			#Endogenizing the domestic share of supply of energy (e) from industry (i) to end-use (d). 
				sSupply_d_e_i_adj[d_ene,e,i,t]$(t.val>tDataEnd.val)..
					sSupply_d_e_i_adj[d_ene,e,i,t] =E= sSupply_d_e_i_adj[d_ene,e,i,tDataEnd] + adj_sSupply_d_e_i_adj[e,i,t];
					# sSupply_d_e_i_adj[d_ene,e,i,t] =E= sSupply_e_i_y[e,i,t] + adj_sSupply_d_e_i_adj[e,i,t];

				#The adjustment parameter is adjusted using the below identity. Note, that this means that distribution "profits" (positive or negative) are allocated to imports.
				adj_sSupply_d_e_i_adj[e,i,t]$(t.val>tDataEnd.val)..					
					sum(d, sum((es,d_a)$es_d2d(es,d_a,d), sSupply_d_e_i_adj[d,e,i,t] * vEpj_base[es,e,d_a,t])) =E= vY_CET[e,i,t] + j_adj_sSupply_d_e_i_adj[e,i]$(tDataEnd[t]);

		$ENDBLOCK 

		# Add equation and endogenous variables to main model
		model main / energy_demand_prices  
								energy_markets_clearing 
								energy_margins
								energy_markets_clearing_link
								energy_markets_IO_link
								/;

		$Group+ main_endogenous 
				energy_demand_prices_endogenous 
				energy_markets_clearing_endogenous 
				energy_margins_endogenous
				energy_markets_clearing_link_endogenous
				energy_markets_IO_link_endogenous
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

		pEpj.l[es,e,d,t]$(pEpj_base.l[es,e,d,t]) = fpt[t];

		# ------------------------------------------------------------------------------
		# Dummies
		# ------------------------------------------------------------------------------

		#Energy demand prices
		pEpj_base.l[es,e,d,'2019'] = pEpj_base.l[es,e,d,'2020']; 
		d1pEpj_base[es,e,d,t]  = yes$(pEpj_base.l[es,e,d,t]); 
		d1qEpj[es,e,d,t]       = yes$(qEpj.l[es,e,d,t]);

		
		d1pY_CET[out,i,t] = yes$(pY_CET.l[out,i,t]);
		d1qY_CET[out,i,t] = yes$(qY_CET.l[out,i,t]);

		d1pM_CET[out,i,t] = yes$(pM_CET.l[out,i,t]);
		d1qM_CET[out,i,t] = yes$(qM_CET.l[out,i,t]);

		#Needs to come after d1pY_CET and d1pM_CET
		d1OneSX[e,t] = yes;

		d1OneSX[e,t]$(straw[e] or el[e] or distheat[e]) = no;

		d1OneSX_y[e,t] = yes$(d1OneSX[e,t] and sum(i, d1pY_CET[e,i,t]));
		d1OneSX_m[e,t] = yes$(d1OneSX[e,t] and sum(i, d1pM_CET[e,i,t]));
		

		#Margins 
		d1pWMA[es,e,d,t]    = yes$(vWMA.l[es,e,d,t]); d1pWMA[es,e,d,'2019'] = d1pWMA[es,e,d,'2020'];
		d1pRMA[es,e,d,t]    = yes$(vRMA.l[es,e,d,t]); d1pRMA[es,e,d,'2019'] = d1pRMA[es,e,d,'2020'];
		d1pCMA[es,e,d,t]    = yes$(vCMA.l[es,e,d,t]); d1pCMA[es,e,d,'2019'] = d1pCMA[es,e,d,'2020'];




	$ENDIF
# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":

	$BLOCK energy_markets_clearing_calibration energy_markets_clearing_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

			qY_CET&_SeveralNonExoSuppliers_calib[e,i,t]$(t.val > t1.val and not d1OneSX_y[e,t])..
					qY_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_Dist[e,i_a,t] * pY_CET[e,i_a,t] ** (-eDist[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_Dist[e,i_a,t] * pM_CET[e,i_a,t]**(-eDist[e]))) 
										=E= sY_Dist[e,i,t] * pY_CET[e,i,t] **(-eDist[e]) * qEtot[e,t];

			qM_CET&_SeveralNonExoSuppliers_calib[e,i,t]$(t.val > t1.val and not d1OneSX_m[e,t])..
					qM_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_Dist[e,i_a,t] * pY_CET[e,i_a,t] ** (-eDist[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_Dist[e,i_a,t] * pM_CET[e,i_a,t]**(-eDist[e]))) 
										=E= sM_Dist[e,i,t] * pM_CET[e,i,t] **(-eDist[e]) * qEtot[e,t];


			sY_Dist[e,i,t]$(t1[t] and not d1OneSX_y[e,t]).. sY_Dist[e,i,t] =E= qY_CET[e,i,t]/qEtot[e,t] * pY_CET[e,i,t]**eDist[e];

			sM_Dist[e,i,t]$(t1[t] and not d1OneSX_m[e,t]).. sM_Dist[e,i,t] =E= qM_CET[e,i,t]/qEtot[e,t] * pM_CET[e,i,t]**eDist[e];



	$ENDBLOCK

	$BLOCK energy_markets_IO_link_calibration energy_markets_IO_link_calibration_endogenous $(t1.val <= t.val and t.val <=tEnd.val)
		#J-terms and are calibrated to capture difference between energy-IO and energybalance. In model-years, differences are set to zero for J-terms 
		jqY_i_d&_energymargins[i,d_ene,t]$(t.val>t1.val and i_energymargins[i])..
			jqY_i_d[i,d_ene,t] =E= 0;

		jqY_i_d&_not_energymargins[i,d_ene,t]$(t.val>t1.val and not i_energymargins[i])..
			jqY_i_d[i,d_ene,t] =E= 0;

		jqM_i_d[i,d_ene,t]$(t.val>t1.val)..
			jqM_i_d[i,d_ene,t] =E= 0;

		jvY_i_d_base[i,d,t]$(t.val>t1.val and d1Y_i_d[i,d,t] and not i_energymargins[i] and d_ene[d])..
			jvY_i_d_base[i,d,t] =E= 0;

		jvY_i_d_base&_energymargins[i,d,t]$(t.val>t1.val and d1Y_i_d[i,d,t] and i_energymargins[i] and d_ene[d])..
			jvY_i_d_base[i,d,t] =E= 0;

		jvM_i_d_base[i,d,t]$(t.val>t1.val and d1M_i_d[i,d,t] and d_ene[d])..
			jvM_i_d_base[i,d,t] =E= 0;

		#The domestic share, sSupply_e_i_y, does not reflect the energy-IO adequately alone. Therefore sSupply_d_e_i_adj_calib is calibrated to match data.
			sSupply_d_e_i_adj_inp&_inp_calib_exists_imports[d_ene,e,i,t]$(t.val=t1.val and d1pY_CET[e,i,t] and d1Y_i_d[i,d_ene,t])..
				sSupply_d_e_i_adj_inp[d_ene,e,i,t] =E= sSupply_e_i_y[e,i,t] + sSupply_d_e_i_adj_calib[d_ene,i]; 


			sSupply_d_e_i_adj&_calib_exists_imports[d_ene,e,i,t]$(t.val=t1.val and d1pY_CET[e,i,t] and d1Y_i_d[i,d_ene,t])..
				sSupply_d_e_i_adj[d_ene,e,i,t] =E= min(sSupply_d_e_i_adj_inp[d_ene,e,i,t],1); 

		#For chain-indices t0 valuese are set
		pWMA&_t0[es,e,d,t]$(t1[t])..
			pWMA[es,e,d,t0] =E= pWMA[es,e,d,t1];

		pRMA&_t0[es,e,d,t]$(t1[t])..
			pRMA[es,e,d,t0] =E= pRMA[es,e,d,t1];

		pCMA&_t0[es,e,d,t]$(t1[t])..
			pCMA[es,e,d,t0] =E= pCMA[es,e,d,t1];

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
		energy_markets_IO_link
		energy_markets_IO_link_calibration

	/;

	# Add endogenous variables to calibration model
	$Group calibration_endogenous
		energy_demand_prices_endogenous 
		fpE[es,e,d,t1],  -pEpj_base[es,e,d,t1]

		energy_markets_clearing_endogenous

		energy_markets_clearing_calibration_endogenous
		sY_Dist$(t1[t] and d1pY_CET[e,i,t] and not d1OneSX_y[e,t]),  -qY_CET$(t1[t] and d1pY_CET[out,i,t] and not d1OneSX_y[out,t] and e[out]) 
		sM_Dist$(t1[t] and d1pM_CET[e,i,t] and not d1OneSX_m[e,t]),  -qM_CET$(t1[t] and d1pM_CET[out,i,t] and not d1OneSX_m[out,t] and e[out]) 

		energy_margins_endogenous
		fpWMA[es,e,d,t1],    -vWMA[es,e,d,t1]	
		fpRMA[es,e,d,t1],    -vRMA[es,e,d,t1]
		fpCMA[es,e,d,t1],    -vCMA[es,e,d,t1]

		energy_markets_clearing_link_endogenous

		energy_markets_IO_link_endogenous

		#IO-prices
		jvY_i_d_base[i,d_ene,t1]$(not i_energymargins[i]), -jfpY_i_d[i,d_ene,t1]$(not i_energymargins[i]) 
		jvY_i_d_base[i,d_ene,t1]$(i_energymargins[i]), -jfpY_i_d[i,d_ene,t1]$(i_energymargins[i]) 
		jvM_i_d_base[i,d_ene,t1], -jfpM_i_d[i,d_ene,t1]

		
		#IO_quantities
		jqM_i_d[i,d_ene,t1]
		jqY_i_d[i,d_ene,t1]$(i_energymargins[i])
		sSupply_d_e_i_adj_calib$(not i_energymargins[i] and sum(t1,sum(e,d1pY_CET[e,i,t1])) and sum(t1, sum(e,sum(i_a, d1pM_CET[e,i_a,t1]))) and d_ene[d]) 
		-adj_sSupply_d_e_i_adj[e,i,t1], j_adj_sSupply_d_e_i_adj
		energy_markets_IO_link_calibration_endogenous
		pWMA[es,e,d,t0]
		pRMA[es,e,d,t0]
		pCMA[es,e,d,t0]

		calibration_endogenous
	;
$ENDIF

$IF %stage%=='tests':
	
	#Testing energy-use in industries
	PARAMETER jvE_re_i[re,i,t] "Difference in top-down and BU-energy";
	jvE_re_i[re,i,t] = vE_re_i.l[re,i,t] - sum((es,e)$es2re(es,re), vEpj.l[es,e,i,t]); 

	#  ABORT$(abs(sum((re,i,tDataEnd), jvE_re_i[re,i,tDataEnd]))>1) 'Testing value of energy-use in data-year. Should ideally be zero';
	ABORT$(abs(sum((re,i,t)$(t.val>t1.val and t.val<=tEnd.val), jvE_re_i[re,i,t]))>1e-6) 'Test in endogenous years, i.e test of model';

	#Testing adjustment share 
	LOOP((d_ene,e,i,t)$(t.val>=t1.val and t.val<=tEnd.val),
		# ABORT$(sSupply_d_e_i_adj.l[d_ene,e,i,t]<0 or sSupply_d_e_i_adj.l[d_ene,e,i,t]>1) 'Y/M split on energy-coefficient needs to be between 1 and 0'; AKB:
		);

	#Testing that method to split energy on IO-cells does not produce negative prices of value (except for inventories, where quantities may be negative),
	LOOP((d_ene,i,t)$(t.val>=t1.val and t.val<=tEnd.val),
		ABORT$(pY_i_d_base.l[i,d_ene,t]<0) 'Splitting energy on IO-cells has produced a negative price in pY_i_d_base';
		ABORT$(pM_i_d_base.l[i,d_ene,t]<0) 'Splitting energy on IO-cells has produced a negative price in pM_i_d_base';
	);

	LOOP((d_ene,i,t)$(t.val>=t1.val and t.val<=tEnd.val and not sameas[d_ene,'invt_ene']),
		ABORT$(qY_i_d.l[i,d_ene,t]<0) 'Splitting energy on IO-cells has produced a negative quantity in qY_i_d';
		ABORT$(qM_i_d.l[i,d_ene,t]<0) 'Splitting energy on IO-cells has produced a negative quantity in qM_i_d';
	);


	#Testing that supply and demand matches for energy, when comparing with input_output.gms
	$PGROUP PG_test_energy_markets 
		vD_ene_IO[d,t] "Value of energy, base prices, in input_output.gms, excluding margins"
		vD_ene_BU[d,t] "Value of energy, base prices, in energy_markets.gms, excluding margins"

		vS_ene_IO_y[i,t] "Value of domestic energy production in input_output.gms"
		vS_ene_IO_m[i,t] "Value of imported energy  in input_output.gms"

		vS_ene_BU_y[i,t] "Value of domestic energy production in energy_markets.gms"
		vS_ene_BU_m[i,t] "Value of imported energy in energy_markets.gms, note that distribution profits are allocated to this one"
	;

	#Total demand in IO
	vD_ene_IO[d,t]$(d_ene[d] and t.val>=t1.val and t.val<=tEnd.val) = sum(i$(not i_energymargins[i]), vY_i_d_base.l[i,d,t]) 
																	+ sum(i$(not i_energymargins[i]), vM_i_d_base.l[i,d,t]);

	#Total supply in IO
	vS_ene_IO_y[i,t]$(t.val>=t1.val and t.val<=tEnd.val and not i_energymargins[i]) = sum(d_ene, vY_i_d_base.l[i,d_ene,t]); 
	vS_ene_IO_m[i,t]$(t.val>=t1.val and t.val<=tEnd.val and not i_energymargins[i]) = sum(d_ene, vM_i_d_base.l[i,d_ene,t]); 

	#Total demand in energy-markets
	vD_ene_BU[d,t] = sum((es,e,d_a)$es_d2d(es,d_a,d), vEpj_base.l[es,e,d_a,t]);

	#Total supply in energy-markets
	vS_ene_BU_y[i,t]$(t.val>=t1.val and t.val<=tEnd.val) = sum(e,vY_CET.l[e,i,t]);
	vS_ene_BU_m[i,t]$(t.val>=t1.val and t.val<=tEnd.val) = sum(e,vM_CET.l[e,i,t]) + sum(e,vDistributionProfits.l[e,t])$(i_refineries[i]);

	#Testing demand and supply (tests should include data-years in longer run):
	LOOP((d,t)$(d_ene[d] and t.val>=t1.val and t.val<=tEnd.val and t.val>tDataEnd.val),
		ABORT$(abs(vD_ene_IO[d,t] -vD_ene_BU[d,t])>1e-6) 'Value of energy demand in IO does not value of energy demand in bottom-level energy';
	);

	LOOP((i,t)$(not i_energymargins[i] and t.val>=t1.val and t.val<=tEnd.val and t.val>tDataEnd.val),
		ABORT$(abs(vS_ene_IO_y[i,t] - vS_ene_BU_y[i,t])>1e-6) 'Value of domestic energy supply does not match between IO and bottom-level energy';
	);

	LOOP((i,t)$(not i_energymargins[i] and t.val>=t1.val and t.val<=tEnd.val and t.val>tDataEnd.val),
		ABORT$(abs(vS_ene_IO_m[i,t] - vS_ene_BU_m[i,t])>1e-6) 'Value of domestic energy supply does not match between IO and bottom-level energy';
	);
$ENDIF