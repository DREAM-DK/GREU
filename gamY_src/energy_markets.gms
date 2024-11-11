# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
	#DEMAND PRICES
		$PGROUP PG_energy_markets_prices_dummies
			d1pXEpj_base[pps,ene,t] ""
			d1pLEpj_base[pps,ene,t] ""
			d1pCEpj_base[pps,ene,t] ""
			d1pREpj_base[pps,ene,i,t] ""	

			d1tpRE[pps,ene,i,t] ""
			d1tqRE[pps,ene,i,t] ""
			d1tpLE[pps,ene,t] ""
			d1tpCE[pps,ene,t] ""
			d1tpXE[pps,ene,t] ""
		;	

		$PGROUP PG_energy_markets_prices_flat_dummies 
			PG_energy_markets_prices_dummies 
		;


		$GROUP G_energy_markets_prices 
			pXEpj[pps,ene,t]$(d1pXEpj_base[pps,ene,t]) ""
			pLEpj[pps,ene,t]$(d1pLEpj_base[pps,ene,t]) ""
			pCEpj[pps,ene,t]$(d1pCEpj_base[pps,ene,t]) ""
			pREpj[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t] or d1tqre[pps,ene,i,t]) ""
		 
			pXEpj_base[pps,ene,t]$(d1pXEpj_base[pps,ene,t]) ""
			pLEpj_base[pps,ene,t]$(d1pLEpj_base[pps,ene,t]) ""
			pCEpj_base[pps,ene,t]$(d1pCEpj_base[pps,ene,t]) ""
			pREpj_base[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t]) ""

		;

		$GROUP G_energy_markets_prices_other
			tpRE[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t]) ""
			tqRE[pps,ene,i,t]$(d1tqRE[pps,ene,i,t]) ""
			tpLE[pps,ene,t]$(d1pLEpj_base[pps,ene,t]) ""
			tpCE[pps,ene,t]$(d1pCEpj_base[pps,ene,t]) ""
			tpXE[pps,ene,t]$(d1pXEpj_base[pps,ene,t]) ""

			fpRE[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t]) ""
			fpxE[pps,ene,t]$(d1pXEpj_base[pps,ene,t]) ""
			fpLE[pps,ene,t]$(d1pLEpj_base[pps,ene,t]) ""
			fpCE[pps,ene,t]$(d1pCEpj_base[pps,ene,t]) ""
		;

		$GROUP G_energy_markets_prices_flat_after_last_data_year 
			G_energy_markets_prices
			G_energy_markets_prices_other

			# tpRE
			# tqRE
			# tpLE
			# tpCE
			# tpXE

			# fpRE
			# fpxE
			# fpLE
			# fpCE
		;

		$GROUP G_energy_markets_prices_data 
			pXEpj_base[pps,ene,t]
			pLEpj_base[pps,ene,t]
			pCEpj_base[pps,ene,t]
			pREpj_base[pps,ene,i,t]

			tpRE[pps,ene,i,t]
			tqRE[pps,ene,i,t]
			tpLE[pps,ene,t]
			tpCE[pps,ene,t]
			tpXE[pps,ene,t]
		;

	#MARKET-CLEARING
		$PGROUP PG_energy_markets_clearing_dummies 
			d1pY_CET[out,i,t] ""
			d1pM_CET[out,i,t] ""
			d1qY_CET[out,i,t] ""
			d1qM_CET[out,i,t] ""

			d1pE_avg[ene,t] ""
			d1qEtot[ene,t] ""
			d1OneSX[out,t] ""
			d1OneSX_y[out,t] ""
			d1OneSX_m[out,t] ""
			d1qTL[pps,ene,t] ""
		;

		$PGROUP PG_energy_markets_clearing_flat_dummies 
			PG_energy_markets_clearing_dummies
		;


		$GROUP G_energy_markets_clearing_prices 
	        pE_avg[ene,t]$(sum(i, d1pY_CET[ene,i,t] or d1pM_CET[ene,i,t]))    "Average supply price of energy"
	        pM_CET[out,i,t]$(d1pM_CET[out,i,t])  "M"

		;

		$GROUP G_energy_markets_clearing_quantities 
	        qY_CET[out,i,t]$(d1pY_CET[out,i,t])  "Domestic production of various products and services - the set 'out' contains all out puts of the economy"
	        qM_CET[out,i,t]$(d1pM_CET[out,i,t])  "Import of various producets (out)"
	        qEtot[ene,t]$(sum(i, d1pY_CET[ene,i,t] or d1pM_CET[ene,i,t]))     "Total demand/supply of energy in the models energy-market"

	        qREpj[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t]) ""
	        qCEpj[pps,ene,t]$(d1pCEpj_base[pps,ene,t]) ""
	        qLEpj[pps,ene,t]$(d1pLEpj_base[pps,ene,t]) ""
	        qXEpj[pps,ene,t]$(d1pXEpj_base[pps,ene,t]) ""
	        qTLpj[pps,ene,t]$(d1qTL[pps,ene,t]) ""
		;

		 $GROUP G_energy_markets_clearing_values 
		 	vDistributionProfits[ene,t] ""
		 ;

		$GROUP G_energy_markets_clearing_other
	        sY_AGG[ene,i,t]$(d1pY_CET[ene,i,t]) ""
	        sM_AGG[ene,i,t]$(d1pM_CET[ene,i,t]) ""
	        eAGG[out] ""    

	        pY_CET[out,i,t]$(d1pY_CET[out,i,t]) "Move to production at later point" 
	    ;

	  $GROUP G_energy_markets_clearing_flat_after_last_data_year 
			G_energy_markets_clearing_prices
			G_energy_markets_clearing_quantities
			G_energy_markets_clearing_values
			G_energy_markets_clearing_other
		;

	   	# qREpj
			# qCEpj
			# qLEpj
			# qXEpj
			# qTLpj
			# sY_AGG
			# sM_AGG
			# pY_CET 
			# pM_CET 
		;

		$GROUP G_energy_markets_clearing_data 
			qREpj
			qCEpj
			qLEpj
			qXEpj
			qTLpj
			qY_CET 
			qM_CET
			pY_CET 
			pM_CET 
			pE_avg 
			qEtot 
		;

    #RETAIL AND WHOLESALE MARGINS ON ENERGY 
		$PGROUP PG_energy_margins_dummies 
				d1pEAV_RE[pps,ene,i,t]
	    	d1pDAV_RE[pps,ene,i,t]
	    	d1pCAV_RE[pps,ene,i,t]

	    	d1pEAV_CE[pps,ene,t]
	    	d1pDAV_CE[pps,ene,t]
	    	d1pCAV_CE[pps,ene,t]
		;

		$PGROUP PG_energy_markets_margins_flat_dummies 
			PG_energy_margins_dummies
		;

	    $GROUP G_energy_markets_margins_prices 
	    	pEAV_RE[pps,ene,i,t]$(d1pEAV_RE[pps,ene,i,t]) ""
	    	pDAV_RE[pps,ene,i,t]$(d1pDAV_RE[pps,ene,i,t]) ""
	    	pCAV_RE[pps,ene,i,t]$(d1pCAV_RE[pps,ene,i,t]) ""

	    	pEAV_CE[pps,ene,t]$(d1pEAV_CE[pps,ene,t]) ""
	    	pDAV_CE[pps,ene,t]$(d1pDAV_CE[pps,ene,t]) ""
	    	pCAV_CE[pps,ene,t]$(d1pCAV_CE[pps,ene,t]) ""
	    ;

	    $GROUP G_energy_markets_margins_values 
	    	vEAV_RE[pps,ene,i,t]$(d1pEAV_RE[pps,ene,i,t]) ""
	    	vDAV_RE[pps,ene,i,t]$(d1pDAV_RE[pps,ene,i,t]) ""
	    	vCAV_RE[pps,ene,i,t]$(d1pCAV_RE[pps,ene,i,t]) ""

	    	vEAV_CE[pps,ene,t]$(d1pEAV_CE[pps,ene,t]) ""
	    	vDAV_CE[pps,ene,t]$(d1pDAV_CE[pps,ene,t]) ""
	    	vCAV_CE[pps,ene,t]$(d1pCAV_CE[pps,ene,t]) ""

	    	vOtherDistributionProfits_EAV[t] ""
	    	vOtherDistributionProfits_DAV[t] ""
	    	vOtherDistributionProfits_CAV[t] ""
	    ;

	    $GROUP G_energy_markets_margins_other
	    	fpEAV_RE[pps,ene,i,t]$(d1pEAV_RE[pps,ene,i,t]) ""
	    	fpDAV_RE[pps,ene,i,t]$(d1pDAV_RE[pps,ene,i,t]) ""
	    	fpCAV_RE[pps,ene,i,t]$(d1pCAV_RE[pps,ene,i,t]) ""

	    	fpEAV_CE[pps,ene,t]$(d1pEAV_CE[pps,ene,t]) ""
	    	fpDAV_CE[pps,ene,t]$(d1pDAV_CE[pps,ene,t]) ""
	    	fpCAV_CE[pps,ene,t]$(d1pCAV_CE[pps,ene,t]) ""
	    ;

	    $GROUP G_energy_markets_margins_flat_after_last_data_year
				G_energy_markets_margins_prices
				G_energy_markets_margins_values
				G_energy_markets_margins_other
	    	# fpEAV_RE
				# fpDAV_RE
				# fpCAV_RE

				# fpEAV_CE
				# fpDAV_CE
				# fpCAV_CE
		;

		$GROUP G_energy_markets_margins_data 
			vEAV_RE
			vDAV_RE
			vCAV_RE
			vEAV_CE
			vDAV_CE
			vCAV_CE
		;

	#AGGREGATE GROUPS 

		$PGROUP PG_energy_markets_flat_dummies 
			PG_energy_markets_prices_flat_dummies
			PG_energy_markets_clearing_flat_dummies
			PG_energy_markets_margins_flat_dummies 
		;

		$GROUP G_energy_markets_flat_after_last_data_year
			G_energy_markets_prices_flat_after_last_data_year
			G_energy_markets_clearing_flat_after_last_data_year
			G_energy_markets_margins_flat_after_last_data_year
		;


    	$GROUP G_energy_markets_data
    		G_energy_markets_prices_data
    		G_energy_markets_clearing_data 
    		G_energy_markets_margins_data 
    	;

# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

	$GROUP+ price_variables
		G_energy_markets_prices
		G_energy_markets_clearing_prices
		G_energy_markets_margins_prices
	;

	$GROUP+ quantity_variables
		G_energy_markets_clearing_quantities

	;

	$GROUP+ value_variables
		G_energy_markets_clearing_values
		G_energy_markets_margins_values
	;
	$GROUP+ other_variables
		G_energy_markets_prices_other
		G_energy_markets_clearing_other
		G_energy_markets_margins_other
	;

	#Add dummies to main flat-group 
	$PGROUP+ PG_flat_after_last_data_year
		PG_energy_markets_flat_dummies
	;
		# Add dummies to main groups
	$GROUP+ G_flat_after_last_data_year
		G_energy_markets_flat_after_last_data_year
	;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

	# ------------------------------------------------------------------------------
	# Demand prices
	# ------------------------------------------------------------------------------

	$BLOCK energy_demand_prices energy_demand_prices_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 

	  pREpj_base[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t]).. pREpj_base[pps,ene,i,t] =E= (1+fpRE[pps,ene,i,t]) * pE_avg[ene,t];

	  pREpj&_market[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t]).. pREpj[pps,ene,i,t] =E= (1+tpRE[pps,ene,i,t]) * pREpj_base[pps,ene,i,t];

	  pREpj&_nonmarket[pps,ene,i,t]$(d1tqRE[pps,ene,i,t]).. pREpj[pps,ene,i,t] =E= tqRE[pps,ene,i,t];

	  pCEpj_base[pps,ene,t]$(d1pCEpj_base[pps,ene,t]).. pCEpj_base[pps,ene,t] =E= (1+fpCE[pps,ene,t])  * pE_avg[ene,t];

	  pCEpj[pps,ene,t]$(d1pCEpj_base[pps,ene,t]).. pCEpj[pps,ene,t] =E= (1+tpCE[pps,ene,t]) * pCEpj_base[pps,ene,t];

	  pLEpj_base[pps,ene,t]$(d1pLEpj_base[pps,ene,t]).. pLEpj_base[pps,ene,t] =E= (1+fpLE[pps,ene,t])  * pE_avg[ene,t];

	  pLEpj[pps,ene,t]$(d1pLEpj_base[pps,ene,t]).. pLEpj[pps,ene,t] =E= (1+tpLE[pps,ene,t]) * pLEpj_base[pps,ene,t];

	  pXEpj_base[pps,ene,t]$(d1pXEpj_base[pps,ene,t]).. pXEpj_base[pps,ene,t] =E= (1+fpXE[pps,ene,t])  * pE_avg[ene,t];

	  pXEpj[pps,ene,t]$(d1pXEpj_base[pps,ene,t]).. pXEpj[pps,ene,t] =E= (1+tpXE[pps,ene,t]) * pXEpj_base[pps,ene,t];

	$ENDBLOCK

	# ------------------------------------------------------------------------------
	# Market clearing
	# ------------------------------------------------------------------------------

	$BLOCK energy_markets_clearing energy_markets_clearing_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
		qY_CET&_SeveralNonExoSuppliers[ene,i,t]$(d1pY_CET[ene,i,t] and not d1OneSX[ene,t])..
		     qY_CET[ene,i,t] * (sum(i_a$d1pY_CET[ene,i_a,t], sY_AGG[ene,i_a,t] * pY_CET[ene,i_a,t] ** (-eAgg[ene])) + sum(i_a$d1pM_CET[ene,i_a,t], sM_AGG[ene,i_a,t] * pM_CET[ene,i_a,t]**(-eAgg[ene]))) 
          				=E= sY_AGG[ene,i,t] * pY_CET[ene,i,t] **(-eAgg[ene]) * qEtot[ene,t];

		qM_CET&_SeveralNonExoSuppliers[ene,i,t]$(d1pM_CET[ene,i,t] and not d1OneSX[ene,t])..
		     qM_CET[ene,i,t] * (sum(i_a$d1pY_CET[ene,i_a,t], sY_AGG[ene,i_a,t] * pY_CET[ene,i_a,t] ** (-eAgg[ene])) + sum(i_a$d1pM_CET[ene,i_a,t], sM_AGG[ene,i_a,t] * pM_CET[ene,i_a,t]**(-eAgg[ene]))) 
          				=E= sM_AGG[ene,i,t] * pM_CET[ene,i,t] **(-eAgg[ene]) * qEtot[ene,t];




        pE_avg[ene,t]$(sum(i, d1pY_CET[ene,i,t] or d1pM_CET[ene,i,t])).. pE_avg[ene,t] * qEtot[ene,t] =E=  sum(i$(d1pY_CET[ene,i,t]), pY_CET[ene,i,t]*qY_CET[ene,i,t]) 
        											    + sum(i$(d1pM_CET[ene,i,t]), pM_CET[ene,i,t]*qM_CET[ene,i,t]);


        #Supply by one side
        qY_CET&_OneSupplierOrExoSuppliers[ene,i,t]$(d1OneSX_y[ene,t]).. qY_CET[ene,i,t] =E= qEtot[ene,t] - sum(i_a, qM_CET[ene,i_a,t]);
        qM_CET&_OneSupplierOrExoSuppliers[ene,i,t]$(d1OneSX_m[ene,t]).. qM_CET[ene,i,t] =E= qEtot[ene,t] - sum(i_a, qY_CET[ene,i_a,t]);


	  # Total demand
        qEtot[ene,t]..  qEtot[ene,t] =E= sum(pps, 	
										   sum(i,  qREpj[pps,ene,i,t]) 
                             				   +   qCEpj[pps,ene,t] 
                             				   +   qLEpj[pps,ene,t]
                             				   +   qXEpj[pps,ene,t] 
                             				   +   qTLpj[pps,ene,t]
                                                );      

         vDistributionProfits[ene,t].. vDistributionProfits[ene,t] =E= sum(pps, sum(i,pREpj_base[pps,ene,i,t] * qREpj[pps,ene,i,t])
				 			                                           	 + pCEpj_base[pps,ene,t]  * qCEpj[pps,ene,t]
				 			                                           	 + pLEpj_base[pps,ene,t]  * qLEpj[pps,ene,t]
				 			                                           	 + pXEpj_base[pps,ene,t]  * qXEpj[pps,ene,t])
				 			                                           - sum(i,   pY_CET[ene,i,t] * qY_CET[ene,i,t])
				 			                                           - sum(i,   pM_CET[ene,i,t] * qM_CET[ene,i,t]);

	    #Clearing demand for energy margins
			qY_CET&WholeAndRetailSaleMarginE[out,i,t]$(d1pY_CET[out,i,t] and sameas[out,'WholeAndRetailSaleMarginE']).. 
				qY_CET['WholeAndRetailSaleMarginE',i,t]	
							=E=  
							+ sum((pps,ene,i_a)$(d1pEAV_RE[pps,ene,i_a,t]), qREpj[pps,ene,i_a,t])$(sameas[i,'46000'])
							+ sum((pps,ene)$(d1pEAV_CE[pps,ene,t]), qCEpj[pps,ene,t])$(sameas[i,'46000'])
							+ sum((pps,ene,i_a)$(d1pDAV_RE[pps,ene,i_a,t]), qREpj[pps,ene,i_a,t])$(sameas[i,'47000'])
							+ sum((pps,ene)$(d1pDAV_CE[pps,ene,t]), qCEpj[pps,ene,t])$(sameas[i,'47000'])
							+ sum((pps,ene,i_a)$(d1pCAV_RE[pps,ene,i_a,t]), qREpj[pps,ene,i_a,t])$(sameas[i,'45000'])
							+ sum((pps,ene)$(d1pCAV_CE[pps,ene,t]), qCEpj[pps,ene,t])$(sameas[i,'45000'])
							;

    $ENDBLOCK 


	# ------------------------------------------------------------------------------
	# Retail and wholesale margins on energy
	# ------------------------------------------------------------------------------

      $BLOCK energy_margins energy_margins_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 
      	vEAV_RE[pps,ene,i,t]..
            vEAV_RE[pps,ene,i,t] =E= pEAV_RE[pps,ene,i,t] * qREpj[pps,ene,i,t];

        vDAV_RE[pps,ene,i,t]..
            vDAV_RE[pps,ene,i,t] =E= pDAV_RE[pps,ene,i,t] * qREpj[pps,ene,i,t];

        vCAV_RE[pps,ene,i,t]..
            vCAV_RE[pps,ene,i,t] =E= pCAV_RE[pps,ene,i,t] * qREpj[pps,ene,i,t];

        vEAV_CE[pps,ene,t]..
            vEAV_CE[pps,ene,t] =E= pEAV_CE[pps,ene,t] * qCEpj[pps,ene,t];

		vDAV_CE[pps,ene,t]..
            vDAV_CE[pps,ene,t] =E= pDAV_CE[pps,ene,t] * qCEpj[pps,ene,t];

        vCAV_CE[pps,ene,t]..
            vCAV_CE[pps,ene,t] =E= pCAV_CE[pps,ene,t] * qCEpj[pps,ene,t];


        pEAV_RE[pps,ene,i,t]..
          pEAV_RE[pps,ene,i,t] =E=  (1+fpEAV_RE[pps,ene,i,t]) * pY_CET['WholeAndRetailSaleMarginE','46000',t];


        pDAV_RE[pps,ene,i,t]..
          pDAV_RE[pps,ene,i,t] =E=  (1+fpDAV_RE[pps,ene,i,t]) * pY_CET['WholeAndRetailSaleMarginE','47000',t];

        pCAV_RE[pps,ene,i,t]..
          pCAV_RE[pps,ene,i,t] =E=  (1+fpCAV_RE[pps,ene,i,t]) * pY_CET['WholeAndRetailSaleMarginE','45000',t];


        pEAV_CE[pps,ene,t]..
          pEAV_CE[pps,ene,t]  =E=  (1+fpEAV_CE[pps,ene,t]) * pY_CET['WholeAndRetailSaleMarginE','46000',t];

        pDAV_CE[pps,ene,t]..
          pDAV_CE[pps,ene,t]  =E=  (1+fpDAV_CE[pps,ene,t]) * pY_CET['WholeAndRetailSaleMarginE','47000',t];

        pCAV_CE[pps,ene,t]..
          pCAV_CE[pps,ene,t]  =E=  (1+fpCAV_CE[pps,ene,t]) * pY_CET['WholeAndRetailSaleMarginE','45000',t];


        vOtherDistributionProfits_EAV[t]..
          vOtherDistributionProfits_EAV[t] =E= sum((pps,ene,i), vEAV_RE[pps,ene,i,t])
                                              +sum((pps,ene),   vEAV_CE[pps,ene,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','46000',t]*qY_CET['WholeAndRetailSaleMarginE','46000',t]
                                              ;

        vOtherDistributionProfits_DAV[t]..
          vOtherDistributionProfits_DAV[t] =E= sum((pps,ene,i), vDAV_RE[pps,ene,i,t])
                                              +sum((pps,ene),     vDAV_CE[pps,ene,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','47000',t]*qY_CET['WholeAndRetailSaleMarginE','47000',t]
                                              ;

        vOtherDistributionProfits_CAV[t]..
          vOtherDistributionProfits_CAV[t] =E= sum((pps,ene,i), vCAV_RE[pps,ene,i,t])
                                              +sum((pps,ene)
                                              	, vCAV_CE[pps,ene,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','45000',t]*qY_CET['WholeAndRetailSaleMarginE','45000',t]
                                              ;

      $ENDBLOCK

# Add equation and endogenous variables to main model
model main / energy_demand_prices  energy_markets_clearing energy_margins/;
$GROUP+ main_endogenous 
		energy_demand_prices_endogenous 
		energy_markets_clearing_endogenous 
		energy_margins_endogenous;

# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------

	@load(G_energy_markets_data, "../data/data.gdx")

	$GROUP+ data_covered_variables
	  G_energy_markets_data
	;

	pREpj_base.l[pps,ene,i,t]$(not qREpj.l[pps,ene,i,t]) = no;

# ------------------------------------------------------------------------------
# Exogenous variables
# ------------------------------------------------------------------------------

	eAGG.l[ene] = 5;

# ------------------------------------------------------------------------------
# Dummies
# ------------------------------------------------------------------------------
	
	#Energy demand prices
	d1pXEpj_base[pps,ene,t]   = yes$(pXEpj_base.l[pps,ene,t]);
	d1pLEpj_base[pps,ene,t]   = yes$(pLEpj_base.l[pps,ene,t]); 
	d1pCEpj_base[pps,ene,t]   = yes$(pCEpj_base.l[pps,ene,t]);
	d1pREpj_base[pps,ene,i,t] = yes$(pREpj_base.l[pps,ene,i,t]);

	d1qTL[pps,ene,t] = yes$(qTLpj.l[pps,ene,t]);

	d1tpRE[pps,ene,i,t]  = tpRE.l[pps,ene,i,t];
	d1tqRE[pps,ene,i,t]  = tqRE.l[pps,ene,i,t];
	d1tpLE[pps,ene,t]    = tpLE.l[pps,ene,t];
	d1tpCE[pps,ene,t]    = tpCE.l[pps,ene,t];
	d1tpXE[pps,ene,t]    = tpXE.l[pps,ene,t];


	#Market clearing
	d1OneSX[ene,t] = yes;
	d1OneSX[ene,t] = no$(sameas[ene,'Straw for energy purposes'] or sameas[ene,'Electricity'] or sameas[ene,'District heat']);

	d1OneSX_y[ene,t] = yes$(d1OneSX[ene,t] and sum(i, d1pY_CET[ene,i,t]));
	d1OneSX_m[ene,t] = yes$(d1OneSX[ene,t] and sum(i, d1pM_CET[ene,i,t]));


	d1pE_avg[ene,t] = yes$(pE_avg.l[ene,t]);
	d1qEtot[ene,t] = yes$(qEtot.l[ene,t]);

	d1pY_CET[out,i,t] = yes$(pY_CET.l[out,i,t]);
	d1qY_CET[out,i,t] = yes$(qY_CET.l[out,i,t]);

	d1pM_CET[out,i,t] = yes$(pM_CET.l[out,i,t]);
	d1qM_CET[out,i,t] = yes$(qM_CET.l[out,i,t]);


	#Margins 
	d1pEAV_RE[pps,ene,i,t] = yes$(vEAV_RE.l[pps,ene,i,t]);
	d1pDAV_RE[pps,ene,i,t] = yes$(vDAV_RE.l[pps,ene,i,t]);
	d1pCAV_RE[pps,ene,i,t] = yes$(vCAV_RE.l[pps,ene,i,t]);

	d1pEAV_CE[pps,ene,t]   = yes$(vEAV_CE.l[pps,ene,t]);
	d1pDAV_CE[pps,ene,t]   = yes$(vDAV_CE.l[pps,ene,t]);
	d1pCAV_CE[pps,ene,t]   = yes$(vCAV_CE.l[pps,ene,t]);


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$BLOCK energy_markets_clearing_calibration energy_markets_clearing_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

		qY_CET&_SeveralNonExoSuppliers_calib[ene,i,t]$(t.val > t1.val and d1pY_CET[ene,i,t] and not d1OneSX[ene,t])..
		     qY_CET[ene,i,t] * (sum(i_a$d1pY_CET[ene,i_a,t], sY_AGG[ene,i_a,t] * pY_CET[ene,i_a,t] ** (-eAgg[ene])) + sum(i_a$d1pM_CET[ene,i_a,t], sM_AGG[ene,i_a,t] * pM_CET[ene,i_a,t]**(-eAgg[ene]))) 
          				=E= sY_AGG[ene,i,t] * pY_CET[ene,i,t] **(-eAgg[ene]) * qEtot[ene,t];

		qM_CET&_SeveralNonExoSuppliers_calib[ene,i,t]$(t.val > t1.val and d1pM_CET[ene,i,t] and not d1OneSX[ene,t])..
		     qM_CET[ene,i,t] * (sum(i_a$d1pY_CET[ene,i_a,t], sY_AGG[ene,i_a,t] * pY_CET[ene,i_a,t] ** (-eAgg[ene])) + sum(i_a$d1pM_CET[ene,i_a,t], sM_AGG[ene,i_a,t] * pM_CET[ene,i_a,t]**(-eAgg[ene]))) 
          				=E= sM_AGG[ene,i,t] * pM_CET[ene,i,t] **(-eAgg[ene]) * qEtot[ene,t];


		sY_AGG[ene,i,t]$(t1[t] and d1pY_CET[ene,i,t] and not d1OneSX[ene,t]).. sY_AGG[ene,i,t] =E= qY_CET[ene,i,t]/qEtot[ene,t] * pY_CET[ene,i,t]**eAgg[ene];

		sM_AGG[ene,i,t]$(t1[t] and d1pM_CET[ene,i,t] and not d1OneSX[ene,t]).. sM_AGG[ene,i,t] =E= qM_CET[ene,i,t]/qEtot[ene,t] * pM_CET[ene,i,t]**eAgg[ene];

$ENDBLOCK


# Add equations and calibration equations to calibration model
model calibration /
  energy_demand_prices

  energy_markets_clearing
  -E_qY_CET_SeveralNonExoSuppliers
  -E_qM_CET_SeveralNonExoSuppliers
  energy_markets_clearing_calibration

  energy_margins
/;
# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  energy_demand_prices_endogenous
  fpRE[pps,ene,i,t1], -pREpj_base[pps,ene,i,t1]
  fpCE[pps,ene,t1],   -pCEpj_base[pps,ene,t1]
  fpLE[pps,ene,t1],   -pLEpj_base[pps,ene,t1]
  fpXE[pps,ene,t1],   -pXEpj_base[pps,ene,t1]
  #  pE_avg$()

  energy_markets_clearing_endogenous
  energy_markets_clearing_calibration_endogenous
  sY_AGG$(t1[t] and d1pY_CET[ene,i,t] and not d1OneSX[ene,t]),  -qY_CET$(t1[t] and d1pY_CET[out,i,t] and not d1OneSX[out,t] and ene[out]) 
  sM_AGG$(t1[t] and d1pM_CET[ene,i,t] and not d1OneSX[ene,t]),  -qM_CET$(t1[t] and d1pM_CET[out,i,t] and not d1OneSX[out,t] and ene[out]) 

  energy_margins_endogenous
  fpEAV_RE[pps,ene,i,t1], -vEAV_RE[pps,ene,i,t1]
  fpEAV_CE[pps,ene,t1],   -vEAV_CE[pps,ene,t1]
  fpDAV_RE[pps,ene,i,t1], -vDAV_RE[pps,ene,i,t1]
  fpDAV_CE[pps,ene,t1],   -vDAV_CE[pps,ene,t1]
  fpCAV_RE[pps,ene,i,t1], -vCAV_RE[pps,ene,i,t1]
  fpCAV_CE[pps,ene,t1],   -vCAV_CE[pps,ene,t1]

  calibration_endogenous
;
