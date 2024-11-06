# ------------------------------------------------------------------------------
# Variable and group creation
# ------------------------------------------------------------------------------
	
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


	#DEMAND PRICES
	$GROUP G_energy_markets_prices 
		pXEpj[pps,ene,t]$(d1pXEpj_base[pps,ene,t]) ""
		pLEpj[pps,ene,t]$(d1pLEpj_base[pps,ene,t]) ""
		pCEpj[pps,ene,t]$(d1pCEpj_base[pps,ene,t]) ""
		pREpj[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t] or d1tqre[pps,ene,i,t]) ""
	 
		pXEpj_base[pps,ene,t]$(d1pXEpj_base[pps,ene,t]) ""
		pLEpj_base[pps,ene,t]$(d1pLEpj_base[pps,ene,t]) ""
		pCEpj_base[pps,ene,t]$(d1pCEpj_base[pps,ene,t]) ""
		pREpj_base[pps,ene,i,t]$(d1pREpj_base[pps,ene,i,t]) ""

		pE_avg[ene,t]$(sum(i, d1pY_CET[ene,i,t] or d1pM_CET[ene,i,t])) ""
	;

	$GROUP G_energy_markets_other_variables 
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


	#MARKET-CLEARING
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

     $GROUP G_energy_markets 
     	G_energy_markets_prices
     	G_energy_markets_other_variables
     	G_energy_markets_clearing_prices
     	G_energy_markets_clearing_values
     	G_energy_markets_clearing_quantities
     	G_energy_markets_clearing_other
    ;

    $GROUP G_flat
    	pY_CET 
    	pM_CET
    	qY_CET 
		sY_AGG 
    	qM_CET
		sM_AGG
    	pE_avg 
    	qEtot
    	qREpj
		qCEpj
		qLEpj
		qXEpj

		tpRE[pps,ene,i,t]
		tqRE[pps,ene,i,t]
		tpLE[pps,ene,t]
		tpCE[pps,ene,t]
		tpXE[pps,ene,t]

		fpRE[pps,ene,i,t]
		fpxE[pps,ene,t]
		fpLE[pps,ene,t]
		fpCE[pps,ene,t]
    ;
# ------------------------------------------------------------------------------
# Create and add dummies
# ------------------------------------------------------------------------------
	#  sets 
	#  	$LOOP G_energy_markets:
	#  		d1{name}{sets}
	#  	$ENDLOOP

	#  	;

	#  set d1OneSX[out,t];


	#  #Add dummies to groups 
	#  $FUNCTION add_dummies_to_group({group}):
	#  	$GROUP {group}
	#  		$LOOP {group}:
	#  			{name}{sets}$(d1{name}{sets})
	#  		$ENDLOOP
	#  	;
	#  $ENDFUNCTION

	#  @add_dummies_to_group(G_energy_markets_prices);
	#  @add_dummies_to_group(G_energy_markets_other_variables);
	#  @add_dummies_to_group(G_energy_markets_clearing_prices);
	#  @add_dummies_to_group(G_energy_markets_clearing_quantities);
	#  @add_dummies_to_group(G_energy_markets_clearing_other);


# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------
	$GROUP+ price_variables
		G_energy_markets_prices
		G_energy_markets_clearing_prices
	;


	$GROUP+ quantity_variables
		G_energy_markets_clearing_quantities

	;

	$GROUP+ value_variables
		G_energy_markets_clearing_values
	;
	$GROUP+ other_variables
		G_energy_markets_other_variables
		G_energy_markets_clearing_other

	;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

	# ------------------------------------------------------------------------------
	# Demand prices
	# ------------------------------------------------------------------------------

	$BLOCK energy_demand_prices$(t1.val <= t.val and t.val <= tEnd.val) 

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

	$BLOCK energy_markets_clearing$(t1.val <= t.val and t.val <= tEnd.val)
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

        #
        #  qEtot[ene,t]$(sum(i, d1pY_CET[ene,i,t] or d1pM_CET[ene,i,t]) and not d1OneSX[ene,t]).. qEtot[ene,t] =E= sum(i$d1pY_CET[ene,i,t], qY_CET[ene,i,t]) + sum(i$(d1pM_CET[ene,i,t]), qM_CET[ene,i,t]);

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

    $ENDBLOCK 


# Add equation and endogenous variables to main model
model main / energy_demand_prices_equations  energy_markets_clearing_equations /;
$GROUP+ main_endogenous energy_demand_prices_endogenous energy_markets_clearing_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP energy_demand_prices_data_variables
	pXEpj_base[pps,ene,t] 
	pLEpj_base[pps,ene,t] 
	pCEpj_base[pps,ene,t] 
	pREpj_base[pps,ene,i,t] 

	pE_avg[ene,t] 

	tpRE[pps,ene,i,t] 
	tqRE[pps,ene,i,t] 
	tpLE[pps,ene,t] 
	tpCE[pps,ene,t] 
	tpXE[pps,ene,t] 

	pY_CET[ene,i,t]
	pM_CET[ene,i,t]
	qY_CET[ene,i,t]
	qM_CET[ene,i,t]

	qEtot[ene,t] 

    qREpj[pps,ene,i,t]
    qCEpj[pps,ene,t]
    qLEpj[pps,ene,t]
    qXEpj[pps,ene,t]
    qTLpj[pps,ene,t]
;

@load(energy_demand_prices_data_variables, "../data/data.gdx")

$GROUP+ data_covered_variables
  energy_demand_prices_data_variables
;


# ------------------------------------------------------------------------------
# Exogenous variables
# ------------------------------------------------------------------------------

	eAGG.l[ene] = 5;

# ------------------------------------------------------------------------------
# Dummies
# ------------------------------------------------------------------------------

#  d1pXEpj[pps,ene,t]        = yes$(pXEpj_base.l[pps,ene,t]);
#  d1pLEpj[pps,ene,t]        = yes$(pLEpj_base.l[pps,ene,t]);
#  d1pCEpj[pps,ene,t]        = yes$(pCEpj_base.l[pps,ene,t]);
#  d1pREpj[pps,ene,i,t] 	  = yes$(pREpj_base.l[pps,ene,i,t]);

d1pXEpj_base[pps,ene,t]   = yes$(pXEpj_base.l[pps,ene,t]);
d1pLEpj_base[pps,ene,t]   = yes$(pLEpj_base.l[pps,ene,t]); 
d1pCEpj_base[pps,ene,t]   = yes$(pCEpj_base.l[pps,ene,t]);
d1pREpj_base[pps,ene,i,t] = yes$(pREpj_base.l[pps,ene,i,t]);

d1pE_avg[ene,t] = yes$(pE_avg.l[ene,t]);
d1qEtot[ene,t] = yes$(qEtot.l[ene,t]);

d1tpRE[pps,ene,i,t]  = tpRE.l[pps,ene,i,t];
d1tqRE[pps,ene,i,t]  = tqRE.l[pps,ene,i,t];
d1tpLE[pps,ene,t]    = tpLE.l[pps,ene,t];
d1tpCE[pps,ene,t]    = tpCE.l[pps,ene,t];
d1tpXE[pps,ene,t]    = tpXE.l[pps,ene,t];

#  d1fpxE[pps,ene,t]    = yes$(pXEpj_base.l[pps,ene,t]);
#  d1fpLE[pps,ene,t]    = yes$(pLEpj_base.l[pps,ene,t]);
#  d1fpCE[pps,ene,t]    = yes$(pCEpj_base.l[pps,ene,t]);
#  d1fpRE[pps,ene,i,t]  = yes$(pREpj_base.l[pps,ene,i,t]);

d1OneSX[ene,t] = yes;
d1OneSX[ene,t] = no$(sameas[ene,'Straw for energy purposes'] or sameas[ene,'Electricity'] or sameas[ene,'District heat']);

d1OneSX_y[ene,t] = yes$(d1OneSX[ene,t] and sum(i, d1pY_CET[ene,i,t]));
d1OneSX_m[ene,t] = yes$(d1OneSX[ene,t] and sum(i, d1pM_CET[ene,i,t]));


d1pY_CET[out,i,t] = yes$(pY_CET.l[out,i,t]);
d1qY_CET[out,i,t] = yes$(qY_CET.l[out,i,t]);

d1pM_CET[out,i,t] = yes$(pM_CET.l[out,i,t]);
d1qM_CET[out,i,t] = yes$(qM_CET.l[out,i,t]);

#  d1sY_AGG[ene,i,t] = yes$(pY_CET.l[ene,i,t] and not d1OneSX[ene,t]);
#  d1sM_AGG[ene,i,t] = yes$(pM_CET.l[ene,i,t] and not d1OneSX[ene,t]);

#  d1eAgg[ene] = yes$(eAgg.l[ene]);


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$BLOCK energy_markets_clearing_calibration $(t1.val <= t.val and t.val <= tEnd.val)

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
  energy_demand_prices_equations

  energy_markets_clearing_equations
  -E_qY_CET_SeveralNonExoSuppliers
  -E_qM_CET_SeveralNonExoSuppliers
  energy_markets_clearing_calibration_equations
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

  calibration_endogenous
;
