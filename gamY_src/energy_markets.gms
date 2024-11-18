# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
	#DEMAND PRICES
		$PGROUP PG_energy_markets_prices_dummies
			d1pXEpj_base[es,e,t] ""
			d1pLEpj_base[es,e,t] ""
			d1pCEpj_base[es,e,t] ""
			d1pREpj_base[es,e,i,t] ""	

			d1tpRE[es,e,i,t] ""
			d1tqRE[es,e,i,t] ""
			d1tpLE[es,e,t] ""
			d1tpCE[es,e,t] ""
			d1tpXE[es,e,t] ""
		;	

		$PGROUP PG_energy_markets_prices_flat_dummies 
			PG_energy_markets_prices_dummies 
		;


		$GROUP G_energy_markets_prices 
			pXEpj[es,e,t]$(d1pXEpj_base[es,e,t]) ""
			pLEpj[es,e,t]$(d1pLEpj_base[es,e,t]) ""
			pCEpj[es,e,t]$(d1pCEpj_base[es,e,t]) ""
			pREpj[es,e,i,t]$(d1pREpj_base[es,e,i,t] or d1tqre[es,e,i,t]) ""
		 
			pXEpj_base[es,e,t]$(d1pXEpj_base[es,e,t]) ""
			pLEpj_base[es,e,t]$(d1pLEpj_base[es,e,t]) ""
			pCEpj_base[es,e,t]$(d1pCEpj_base[es,e,t]) ""
			pREpj_base[es,e,i,t]$(d1pREpj_base[es,e,i,t]) ""
		;

		$GROUP G_energy_markets_prices_other
			tpRE[es,e,i,t]$(d1pREpj_base[es,e,i,t]) ""
			tqRE[es,e,i,t]$(d1tqRE[es,e,i,t]) ""
			tpLE[es,e,t]$(d1pLEpj_base[es,e,t]) ""
			tpCE[es,e,t]$(d1pCEpj_base[es,e,t]) ""
			tpXE[es,e,t]$(d1pXEpj_base[es,e,t]) ""

			fpRE[es,e,i,t]$(d1pREpj_base[es,e,i,t]) ""
			fpxE[es,e,t]$(d1pXEpj_base[es,e,t]) ""
			fpLE[es,e,t]$(d1pLEpj_base[es,e,t]) ""
			fpCE[es,e,t]$(d1pCEpj_base[es,e,t]) ""
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
			pXEpj_base[es,e,t]
			pLEpj_base[es,e,t]
			pCEpj_base[es,e,t]
			pREpj_base[es,e,i,t]

			# tpRE[es,e,i,t]
			# tqRE[es,e,i,t]
			tpLE[es,e,t]
			tpCE[es,e,t]
			tpXE[es,e,t]
		;

	#MARKET-CLEARING
		$PGROUP PG_energy_markets_clearing_dummies 
			d1pY_CET[out,i,t] ""
			d1pM_CET[out,i,t] ""
			d1qY_CET[out,i,t] ""
			d1qM_CET[out,i,t] ""

			d1pE_avg[e,t] ""
			d1qEtot[e,t] ""
			d1OneSX[out,t] ""
			d1OneSX_y[out,t] ""
			d1OneSX_m[out,t] ""
			d1qTL[es,e,t] ""
		;

		$PGROUP PG_energy_markets_clearing_flat_dummies 
			PG_energy_markets_clearing_dummies
		;


		$GROUP G_energy_markets_clearing_prices 
	        pE_avg[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t]))    "Average supply price of ergy"
	        pM_CET[out,i,t]$(d1pM_CET[out,i,t])  "M"

		;

		$GROUP G_energy_markets_clearing_quantities 
	        qY_CET[out,i,t]$(d1pY_CET[out,i,t])  "Domestic production of various products and services - the set 'out' contains all out puts of the economy"
	        qM_CET[out,i,t]$(d1pM_CET[out,i,t])  "Import of various producets (out)"
	        qEtot[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t]))     "Total demand/supply of ergy in the models ergy-market"

	        qREpj[es,e,i,t]$(d1pREpj_base[es,e,i,t]) ""
	        qCEpj[es,e,t]$(d1pCEpj_base[es,e,t]) ""
	        qLEpj[es,e,t]$(d1pLEpj_base[es,e,t]) ""
	        qXEpj[es,e,t]$(d1pXEpj_base[es,e,t]) ""
	        qTLpj[es,e,t]$(d1qTL[es,e,t]) ""
		;

		 $GROUP G_energy_markets_clearing_values 
		 	vDistributionProfits[e,t] ""
		 ;

		$GROUP G_energy_markets_clearing_other
	        sY_AGG[e,i,t]$(d1pY_CET[e,i,t]) ""
	        sM_AGG[e,i,t]$(d1pM_CET[e,i,t]) ""
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

    #RETAIL AND WHOLESALE MARGINS ON eRGY 
		$PGROUP PG_energy_margins_dummies 
			d1pEAV_RE[es,e,i,t]
	    	d1pDAV_RE[es,e,i,t]
	    	d1pCAV_RE[es,e,i,t]

	    	d1pEAV_CE[es,e,t]
	    	d1pDAV_CE[es,e,t]
	    	d1pCAV_CE[es,e,t]
		;

		$PGROUP PG_energy_markets_margins_flat_dummies 
			PG_energy_margins_dummies
		;

	    $GROUP G_energy_markets_margins_prices 
	    	pEAV_RE[es,e,i,t]$(d1pEAV_RE[es,e,i,t]) ""
	    	pDAV_RE[es,e,i,t]$(d1pDAV_RE[es,e,i,t]) ""
	    	pCAV_RE[es,e,i,t]$(d1pCAV_RE[es,e,i,t]) ""

	    	pEAV_CE[es,e,t]$(d1pEAV_CE[es,e,t]) ""
	    	pDAV_CE[es,e,t]$(d1pDAV_CE[es,e,t]) ""
	    	pCAV_CE[es,e,t]$(d1pCAV_CE[es,e,t]) ""
	    ;

	    $GROUP G_energy_markets_margins_values 
	    	vEAV_RE[es,e,i,t]$(d1pEAV_RE[es,e,i,t]) ""
	    	vDAV_RE[es,e,i,t]$(d1pDAV_RE[es,e,i,t]) ""
	    	vCAV_RE[es,e,i,t]$(d1pCAV_RE[es,e,i,t]) ""

	    	vEAV_CE[es,e,t]$(d1pEAV_CE[es,e,t]) ""
	    	vDAV_CE[es,e,t]$(d1pDAV_CE[es,e,t]) ""
	    	vCAV_CE[es,e,t]$(d1pCAV_CE[es,e,t]) ""

	    	vOtherDistributionProfits_EAV[t] ""
	    	vOtherDistributionProfits_DAV[t] ""
	    	vOtherDistributionProfits_CAV[t] ""
	    ;

	    $GROUP G_energy_markets_margins_other
	    	fpEAV_RE[es,e,i,t]$(d1pEAV_RE[es,e,i,t]) ""
	    	fpDAV_RE[es,e,i,t]$(d1pDAV_RE[es,e,i,t]) ""
	    	fpCAV_RE[es,e,i,t]$(d1pCAV_RE[es,e,i,t]) ""

	    	fpEAV_CE[es,e,t]$(d1pEAV_CE[es,e,t]) ""
	    	fpDAV_CE[es,e,t]$(d1pDAV_CE[es,e,t]) ""
	    	fpCAV_CE[es,e,t]$(d1pCAV_CE[es,e,t]) ""
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

	  pREpj_base[es,e,i,t]$(d1pREpj_base[es,e,i,t]).. pREpj_base[es,e,i,t] =E= (1+fpRE[es,e,i,t]) * pE_avg[e,t];

	  pREpj&_market[es,e,i,t]$(d1pREpj_base[es,e,i,t]).. pREpj[es,e,i,t] =E= (1+tpRE[es,e,i,t]) * pREpj_base[es,e,i,t];

	  pREpj&_nonmarket[es,e,i,t]$(d1tqRE[es,e,i,t]).. pREpj[es,e,i,t] =E= tqRE[es,e,i,t];

	  pCEpj_base[es,e,t]$(d1pCEpj_base[es,e,t]).. pCEpj_base[es,e,t] =E= (1+fpCE[es,e,t])  * pE_avg[e,t];

	  pCEpj[es,e,t]$(d1pCEpj_base[es,e,t]).. pCEpj[es,e,t] =E= (1+tpCE[es,e,t]) * pCEpj_base[es,e,t];

	  pLEpj_base[es,e,t]$(d1pLEpj_base[es,e,t]).. pLEpj_base[es,e,t] =E= (1+fpLE[es,e,t])  * pE_avg[e,t];

	  pLEpj[es,e,t]$(d1pLEpj_base[es,e,t]).. pLEpj[es,e,t] =E= (1+tpLE[es,e,t]) * pLEpj_base[es,e,t];

	  pXEpj_base[es,e,t]$(d1pXEpj_base[es,e,t]).. pXEpj_base[es,e,t] =E= (1+fpXE[es,e,t])  * pE_avg[e,t];

	  pXEpj[es,e,t]$(d1pXEpj_base[es,e,t]).. pXEpj[es,e,t] =E= (1+tpXE[es,e,t]) * pXEpj_base[es,e,t];

	$ENDBLOCK

	# ------------------------------------------------------------------------------
	# Market clearing
	# ------------------------------------------------------------------------------

	$BLOCK energy_markets_clearing energy_markets_clearing_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
		qY_CET&_SeveralNonExoSuppliers[e,i,t]$(d1pY_CET[e,i,t] and not d1OneSX[e,t])..
		     qY_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_AGG[e,i_a,t] * pY_CET[e,i_a,t] ** (-eAgg[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_AGG[e,i_a,t] * pM_CET[e,i_a,t]**(-eAgg[e]))) 
          				=E= sY_AGG[e,i,t] * pY_CET[e,i,t] **(-eAgg[e]) * qEtot[e,t];

		qM_CET&_SeveralNonExoSuppliers[e,i,t]$(d1pM_CET[e,i,t] and not d1OneSX[e,t])..
		     qM_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_AGG[e,i_a,t] * pY_CET[e,i_a,t] ** (-eAgg[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_AGG[e,i_a,t] * pM_CET[e,i_a,t]**(-eAgg[e]))) 
          				=E= sM_AGG[e,i,t] * pM_CET[e,i,t] **(-eAgg[e]) * qEtot[e,t];




        pE_avg[e,t]$(sum(i, d1pY_CET[e,i,t] or d1pM_CET[e,i,t])).. pE_avg[e,t] * qEtot[e,t] =E=  sum(i$(d1pY_CET[e,i,t]), pY_CET[e,i,t]*qY_CET[e,i,t]) 
        											    + sum(i$(d1pM_CET[e,i,t]), pM_CET[e,i,t]*qM_CET[e,i,t]);


        #Supply by one side
        qY_CET&_OneSupplierOrExoSuppliers[e,i,t]$(d1OneSX_y[e,t]).. qY_CET[e,i,t] =E= qEtot[e,t] - sum(i_a, qM_CET[e,i_a,t]);
        qM_CET&_OneSupplierOrExoSuppliers[e,i,t]$(d1OneSX_m[e,t]).. qM_CET[e,i,t] =E= qEtot[e,t] - sum(i_a, qY_CET[e,i_a,t]);


	  # Total demand
        qEtot[e,t]..  qEtot[e,t] =E= sum(es, 	
										   sum(i,  qREpj[es,e,i,t]) 
                             				   +   qCEpj[es,e,t] 
                             				   +   qLEpj[es,e,t]
                             				   +   qXEpj[es,e,t] 
                             				   +   qTLpj[es,e,t]
                                                );      

         vDistributionProfits[e,t].. vDistributionProfits[e,t] =E= sum(es, sum(i,pREpj_base[es,e,i,t] * qREpj[es,e,i,t])
				 			                                           	 + pCEpj_base[es,e,t]  * qCEpj[es,e,t]
				 			                                           	 + pLEpj_base[es,e,t]  * qLEpj[es,e,t]
				 			                                           	 + pXEpj_base[es,e,t]  * qXEpj[es,e,t])
				 			                                           - sum(i,   pY_CET[e,i,t] * qY_CET[e,i,t])
				 			                                           - sum(i,   pM_CET[e,i,t] * qM_CET[e,i,t]);

	    #Clearing demand for ergy margins
			qY_CET&WholeAndRetailSaleMarginE[out,i,t]$(d1pY_CET[out,i,t] and sameas[out,'WholeAndRetailSaleMarginE']).. 
				qY_CET['WholeAndRetailSaleMarginE',i,t]	
							=E=  
							+ sum((es,e,i_a)$(d1pEAV_RE[es,e,i_a,t]), qREpj[es,e,i_a,t])$(sameas[i,'46000'])
							+ sum((es,e)$(d1pEAV_CE[es,e,t]), qCEpj[es,e,t])$(sameas[i,'46000'])
							+ sum((es,e,i_a)$(d1pDAV_RE[es,e,i_a,t]), qREpj[es,e,i_a,t])$(sameas[i,'47000'])
							+ sum((es,e)$(d1pDAV_CE[es,e,t]), qCEpj[es,e,t])$(sameas[i,'47000'])
							+ sum((es,e,i_a)$(d1pCAV_RE[es,e,i_a,t]), qREpj[es,e,i_a,t])$(sameas[i,'45000'])
							+ sum((es,e)$(d1pCAV_CE[es,e,t]), qCEpj[es,e,t])$(sameas[i,'45000'])
							;

    $ENDBLOCK 


	# ------------------------------------------------------------------------------
	# Retail and wholesale margins on ergy
	# ------------------------------------------------------------------------------

      $BLOCK energy_margins energy_margins_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 
      	vEAV_RE[es,e,i,t]..
            vEAV_RE[es,e,i,t] =E= pEAV_RE[es,e,i,t] * qREpj[es,e,i,t];

        vDAV_RE[es,e,i,t]..
            vDAV_RE[es,e,i,t] =E= pDAV_RE[es,e,i,t] * qREpj[es,e,i,t];

        vCAV_RE[es,e,i,t]..
            vCAV_RE[es,e,i,t] =E= pCAV_RE[es,e,i,t] * qREpj[es,e,i,t];

        vEAV_CE[es,e,t]..
            vEAV_CE[es,e,t] =E= pEAV_CE[es,e,t] * qCEpj[es,e,t];

		vDAV_CE[es,e,t]..
            vDAV_CE[es,e,t] =E= pDAV_CE[es,e,t] * qCEpj[es,e,t];

        vCAV_CE[es,e,t]..
            vCAV_CE[es,e,t] =E= pCAV_CE[es,e,t] * qCEpj[es,e,t];


        pEAV_RE[es,e,i,t]..
          pEAV_RE[es,e,i,t] =E=  (1+fpEAV_RE[es,e,i,t]) * pY_CET['WholeAndRetailSaleMarginE','46000',t];


        pDAV_RE[es,e,i,t]..
          pDAV_RE[es,e,i,t] =E=  (1+fpDAV_RE[es,e,i,t]) * pY_CET['WholeAndRetailSaleMarginE','47000',t];

        pCAV_RE[es,e,i,t]..
          pCAV_RE[es,e,i,t] =E=  (1+fpCAV_RE[es,e,i,t]) * pY_CET['WholeAndRetailSaleMarginE','45000',t];


        pEAV_CE[es,e,t]..
          pEAV_CE[es,e,t]  =E=  (1+fpEAV_CE[es,e,t]) * pY_CET['WholeAndRetailSaleMarginE','46000',t];

        pDAV_CE[es,e,t]..
          pDAV_CE[es,e,t]  =E=  (1+fpDAV_CE[es,e,t]) * pY_CET['WholeAndRetailSaleMarginE','47000',t];

        pCAV_CE[es,e,t]..
          pCAV_CE[es,e,t]  =E=  (1+fpCAV_CE[es,e,t]) * pY_CET['WholeAndRetailSaleMarginE','45000',t];


        vOtherDistributionProfits_EAV[t]..
          vOtherDistributionProfits_EAV[t] =E= sum((es,e,i), vEAV_RE[es,e,i,t])
                                              +sum((es,e),   vEAV_CE[es,e,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','46000',t]*qY_CET['WholeAndRetailSaleMarginE','46000',t]
                                              ;

        vOtherDistributionProfits_DAV[t]..
          vOtherDistributionProfits_DAV[t] =E= sum((es,e,i), vDAV_RE[es,e,i,t])
                                              +sum((es,e),     vDAV_CE[es,e,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','47000',t]*qY_CET['WholeAndRetailSaleMarginE','47000',t]
                                              ;

        vOtherDistributionProfits_CAV[t]..
          vOtherDistributionProfits_CAV[t] =E= sum((es,e,i), vCAV_RE[es,e,i,t])
                                              +sum((es,e)
                                              	, vCAV_CE[es,e,t])
                                              - pY_CET['WholeAndRetailSaleMarginE','45000',t]*qY_CET['WholeAndRetailSaleMarginE','45000',t]
                                              ;

      $ENDBLOCK

# Add equation and endogenous variables to main model
model main / energy_demand_prices  energy_markets_clearing energy_margins/;
$GROUP+ main_endogenous 
		energy_demand_prices_endogenous 
		energy_markets_clearing_endogenous 
		energy_margins_endogenous
		;

# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------

	@load(G_energy_markets_data, "../data/data.gdx")

	$GROUP+ data_covered_variables
	  G_energy_markets_data
	;

	pREpj_base.l[es,e,i,t]$(not qREpj.l[es,e,i,t]) = no;

# ------------------------------------------------------------------------------
# Exogenous variables
# ------------------------------------------------------------------------------

	eAGG.l[e] = 5;

# ------------------------------------------------------------------------------
# Dummies
# ------------------------------------------------------------------------------
	
	#Energy demand prices
	d1pXEpj_base[es,e,t]   = yes$(pXEpj_base.l[es,e,t]);
	d1pLEpj_base[es,e,t]   = yes$(pLEpj_base.l[es,e,t]); 
	d1pCEpj_base[es,e,t]   = yes$(pCEpj_base.l[es,e,t]);
	d1pREpj_base[es,e,i,t] = yes$(pREpj_base.l[es,e,i,t]);

	d1qTL[es,e,t] = yes$(qTLpj.l[es,e,t]);

	d1tpRE[es,e,i,t]  = tpRE.l[es,e,i,t];
	d1tqRE[es,e,i,t]  = tqRE.l[es,e,i,t];
	d1tpLE[es,e,t]    = tpLE.l[es,e,t];
	d1tpCE[es,e,t]    = tpCE.l[es,e,t];
	d1tpXE[es,e,t]    = tpXE.l[es,e,t];


	#Market clearing
	d1OneSX[e,t] = yes;
	d1OneSX[e,t] = no$(sameas[e,'Straw for energy purposes'] or sameas[e,'Electricity'] or sameas[e,'District heat']);

	d1OneSX_y[e,t] = yes$(d1OneSX[e,t] and sum(i, d1pY_CET[e,i,t]));
	d1OneSX_m[e,t] = yes$(d1OneSX[e,t] and sum(i, d1pM_CET[e,i,t]));


	d1pE_avg[e,t] = yes$(pE_avg.l[e,t]);
	d1qEtot[e,t] = yes$(qEtot.l[e,t]);

	d1pY_CET[out,i,t] = yes$(pY_CET.l[out,i,t]);
	d1qY_CET[out,i,t] = yes$(qY_CET.l[out,i,t]);

	d1pM_CET[out,i,t] = yes$(pM_CET.l[out,i,t]);
	d1qM_CET[out,i,t] = yes$(qM_CET.l[out,i,t]);


	#Margins 
	d1pEAV_RE[es,e,i,t] = yes$(vEAV_RE.l[es,e,i,t]);
	d1pDAV_RE[es,e,i,t] = yes$(vDAV_RE.l[es,e,i,t]);
	d1pCAV_RE[es,e,i,t] = yes$(vCAV_RE.l[es,e,i,t]);

	d1pEAV_CE[es,e,t]   = yes$(vEAV_CE.l[es,e,t]);
	d1pDAV_CE[es,e,t]   = yes$(vDAV_CE.l[es,e,t]);
	d1pCAV_CE[es,e,t]   = yes$(vCAV_CE.l[es,e,t]);

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$BLOCK energy_markets_clearing_calibration energy_markets_clearing_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

		qY_CET&_SeveralNonExoSuppliers_calib[e,i,t]$(t.val > t1.val and d1pY_CET[e,i,t] and not d1OneSX[e,t])..
		     qY_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_AGG[e,i_a,t] * pY_CET[e,i_a,t] ** (-eAgg[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_AGG[e,i_a,t] * pM_CET[e,i_a,t]**(-eAgg[e]))) 
          				=E= sY_AGG[e,i,t] * pY_CET[e,i,t] **(-eAgg[e]) * qEtot[e,t];

		qM_CET&_SeveralNonExoSuppliers_calib[e,i,t]$(t.val > t1.val and d1pM_CET[e,i,t] and not d1OneSX[e,t])..
		     qM_CET[e,i,t] * (sum(i_a$d1pY_CET[e,i_a,t], sY_AGG[e,i_a,t] * pY_CET[e,i_a,t] ** (-eAgg[e])) + sum(i_a$d1pM_CET[e,i_a,t], sM_AGG[e,i_a,t] * pM_CET[e,i_a,t]**(-eAgg[e]))) 
          				=E= sM_AGG[e,i,t] * pM_CET[e,i,t] **(-eAgg[e]) * qEtot[e,t];


		sY_AGG[e,i,t]$(t1[t] and d1pY_CET[e,i,t] and not d1OneSX[e,t]).. sY_AGG[e,i,t] =E= qY_CET[e,i,t]/qEtot[e,t] * pY_CET[e,i,t]**eAgg[e];

		sM_AGG[e,i,t]$(t1[t] and d1pM_CET[e,i,t] and not d1OneSX[e,t]).. sM_AGG[e,i,t] =E= qM_CET[e,i,t]/qEtot[e,t] * pM_CET[e,i,t]**eAgg[e];

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
  fpRE[es,e,i,t1], -pREpj_base[es,e,i,t1]
  fpCE[es,e,t1],   -pCEpj_base[es,e,t1]
  fpLE[es,e,t1],   -pLEpj_base[es,e,t1]
  fpXE[es,e,t1],   -pXEpj_base[es,e,t1]
  #  pE_avg$()

  energy_markets_clearing_endogenous
  energy_markets_clearing_calibration_endogenous
  sY_AGG$(t1[t] and d1pY_CET[e,i,t] and not d1OneSX[e,t]),  -qY_CET$(t1[t] and d1pY_CET[out,i,t] and not d1OneSX[out,t] and e[out]) 
  sM_AGG$(t1[t] and d1pM_CET[e,i,t] and not d1OneSX[e,t]),  -qM_CET$(t1[t] and d1pM_CET[out,i,t] and not d1OneSX[out,t] and e[out]) 

  energy_margins_endogenous
  fpEAV_RE[es,e,i,t1], -vEAV_RE[es,e,i,t1]
  fpEAV_CE[es,e,t1],   -vEAV_CE[es,e,t1]
  fpDAV_RE[es,e,i,t1], -vDAV_RE[es,e,i,t1]
  fpDAV_CE[es,e,t1],   -vDAV_CE[es,e,t1]
  fpCAV_RE[es,e,i,t1], -vCAV_RE[es,e,i,t1]
  fpCAV_CE[es,e,t1],   -vCAV_CE[es,e,t1]

  calibration_endogenous
;
