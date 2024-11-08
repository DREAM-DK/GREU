# ------------------------------------------------------------------------------
# Variable and group creation
# ------------------------------------------------------------------------------

	$PGROUP PG_industries_energydemand_dummies 
		d1pREa[pps,ene_a,i,t]
		d1pREa_inNest[pps,ene_a,i,t]
		d1pEPPS[pps,i,t]
		d1pREmachine[i,t]
		d1Prod[pf,i,t]
	;
	
	$PGROUP PG_industries_energydemand_flat_dummies 
		PG_industries_energydemand_dummies
	;
	
	$GROUP G_industries_energydemand_prices 
		pREa[pps,ene_a,i,t]$(d1pREa[pps,ene_a,i,t]) ""
		pREPPS[pps,i,t]$(d1pEPPS[pps,i,t]) 			""
		pREmachine[i,t]$(d1pREmachine[i,t]) 		""
		pProd[pf,i,t]$(d1Prod[pf,i,t]) ""
	;
	
	$GROUP G_industries_energydemand_quantities 
		qREa[pps,ene_a,i,t]$(d1pREa[pps,ene_a,i,t]) ""
		qREPPS[pps,i,t]$(d1pEPPS[pps,i,t]) ""
		qREmachine[i,t]$(d1pREmachine[i,t]) ""
		qProd[pf,i,t]$(d1Prod[pf,i,t]) ""
	;
	
	$GROUP G_industries_energydemand_other 
		eREa[pps,i] ""
		uREPPS[pps,i,t] ""
	
		eREPPS[i] ""
		uREa[pps,ene_a,i,t]$(d1pREa_inNest[pps,ene_a,i,t]) ""
	;
	
	$GROUP G_industries_energydemand_flat_after_last_data_year 
		$LOOP G_industries_energydemand_prices:
			{name}
		$ENDLOOP 

		$LOOP G_industries_energydemand_quantities:
			{name}
		$ENDLOOP

		$LOOP G_industries_energydemand_other:
			{name}
		$ENDLOOP

	;
	
	$GROUP G_industries_energydemand_data 
		
	;

# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

	$GROUP+ price_variables
		G_industries_energydemand_prices
	;

	$GROUP+ quantity_variables
		G_industries_energydemand_quantities

	;

	$GROUP+ other_variables
		G_industries_energydemand_other
	;

	#Add dummies to main flat-group 
	$PGROUP+ PG_flat_after_last_data_year
		# PG_flat_after_last_data_year 
		PG_industries_energydemand_flat_dummies
	;
		# Add dummies to main groups
	$GROUP+ G_flat_after_last_data_year
		# G_flat_after_last_data_year 
		G_industries_energydemand_flat_after_last_data_year
	;


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

	$BLOCK industries_energy_demand industries_energy_demand_endogenous $(t.val>=t1.val and t.val<=tEnd.val)
		qREa&_inNest[pps,ene_a,i,t]$(d1pREa_inNest[pps,ene_a,i,t]).. 
			qREa[pps,ene_a,i,t] =E= uREa[pps,ene_a,i,t] * (pREPPS[pps,i,t]/pREa[pps,ene_a,i,t])**(-eREa[pps,i]) * qREPPS[pps,i,t];
	
		pREPPS[pps,i,t]$(d1pEPPS[pps,i,t]).. pREPPS[pps,i,t]*qREPPS[pps,i,t] =E= sum((ene_a)$(d1pREa_inNest[pps,ene_a,i,t]), pREa[pps,ene_a,i,t] * qREa[pps,ene_a,i,t]);
	
	
		qREPPS&_machine_energy[pps,i,t]$(d1pEPPS[pps,i,t] and not (sameas[pps,'heating'] or sameas[pps,'transport']))..
			qREPPS[pps,i,t] =E= uREPPS[pps,i,t] * (pREPPS[pps,i,t]/pREmachine[i,t])**(-eREPPS[i]) * qREmachine[i,t];
	
	
		pREmachine[i,t]$(d1pREmachine[i,t])..
			pREmachine[i,t]*qREmachine[i,t] =E= sum(pps$(d1pEPPS[pps,i,t] and not (sameas[pps,'heating'] or sameas[pps,'transport'])), pREPPS[pps,i,t]*qREPPS[pps,i,t]);
	
	$ENDBLOCK		

	$BLOCK industries_energy_demand_link industries_energy_demand_link_endogenous $(t.val>=t1.val and t.val<=tEnd.val)
	    qREPPS&_heating[pps,i,t]$(d1pEPPS[pps,i,t] and sameas[pps,'heating'])..
	      qREPPS['heating',i,t] =E= qProd['heating_energy',i,t];
	  
	  
	    qREPPS&_transport[pps,i,t]$(d1pEPPS[pps,i,t] and sameas[pps,'transport'])..
	      qREPPS['transport',i,t] =E= qProd['transport_energy',i,t];

	$ENDBLOCK

# Add equation and endogenous variables to main model
model main / industries_energy_demand/;
$GROUP+ main_endogenous 
		industries_energy_demand_endogenous
		;



# ------------------------------------------------------------------------------
# Exogenous values 
# ------------------------------------------------------------------------------

	eREa.l[pps,i] = 0.1;
	eREPPS.l[i] = 0.1;

# ------------------------------------------------------------------------------
# Initial values 
# ------------------------------------------------------------------------------
	
	qREa.l[pps,ene_a,i,t] = qREpj.l[pps,ene_a,i,t];
	pREa.l[pps,ene_a,i,t] = pREpj_base.l[pps,ene_a,i,t];
	qREPPS.l[pps,i,t]$(tDataEnd[t])     = sum(ene_a, qREa.l[pps,ene_a,i,t]);
	pREPPS.l[pps,i,t]$(tDataEnd[t])     = 1;
	pREmachine.l[i,t]$(tDataEnd[t])     = 1;
	qREmachine.l[i,t]$(tDataEnd[t])     = 1;

	pProd.l[pf,i,t]$(tDataEnd[t]) = 1;

# ------------------------------------------------------------------------------
# Set dummies 
# ------------------------------------------------------------------------------

	d1pREa_inNest[pps,ene_a,i,t] = yes$(pREpj_base.l[pps,ene_a,i,t]);
	d1pREa[pps,ene_a,i,t]        = yes$(pREpj_base.l[pps,ene_a,i,t]);

	d1pEPPS[pps,i,t] 			 = yes$(sum(ene_a, d1pREa_inNest[pps,ene_a,i,t]));	
	d1pREmachine[i,t]            = yes$(sum(pps$(not (sameas[pps,'Heating'] or sameas[pps,'Transport'])), d1pEPPS[pps,i,t]));
	d1Prod[pf,i,t]               = yes$(pProd.l[pf,i,t]);


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

# Add equations and calibration equations to calibration model
model calibration /
	industries_energy_demand
/;

# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  industries_energy_demand_endogenous
  -qREa[pps,ene_a,i,t1], uREa[pps,ene_a,i,t1]
  -pREPPS[pps,i,t1], qREPPS[pps,i,t1]
  uREPPS[pps,i,t1]
  -pREmachine[i,t1], qREmachine[i,t1]
    calibration_endogenous
;
