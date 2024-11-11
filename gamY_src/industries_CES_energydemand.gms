# ------------------------------------------------------------------------------
# Variable and group creation
# ------------------------------------------------------------------------------

	$PGROUP PG_industries_energydemand_dummies 
		d1pREa[es,e_a,i,t]
		d1pREa_inNest[es,e_a,i,t]
		d1pEes[es,i,t]
		d1pREmachine[i,t]
		d1Prod[pf,i,t]
	;
	
	$PGROUP PG_industries_energydemand_flat_dummies 
		PG_industries_energydemand_dummies
	;
	
	$GROUP G_industries_energydemand_prices 
		pREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t]) ""
		pREes[es,i,t]$(d1pEes[es,i,t]) 			""
		pREmachine[i,t]$(d1pREmachine[i,t]) 		""
		pProd[pf,i,t]$(d1Prod[pf,i,t]) ""
	;
	
	$GROUP G_industries_energydemand_quantities 
		qREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t]) ""
		qREes[es,i,t]$(d1pEes[es,i,t]) ""
		qREmachine[i,t]$(d1pREmachine[i,t]) ""
		qProd[pf,i,t]$(d1Prod[pf,i,t]) ""
	;
	
	$GROUP G_industries_energydemand_other 
		eREa[es,i] ""
		uREes[es,i,t] ""
	
		eREes[i] ""
		uREa[es,e_a,i,t]$(d1pREa_inNest[es,e_a,i,t]) ""
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
		qREa&_inNest[es,e_a,i,t]$(d1pREa_inNest[es,e_a,i,t]).. 
			qREa[es,e_a,i,t] =E= uREa[es,e_a,i,t] * (pREes[es,i,t]/pREa[es,e_a,i,t])**(-eREa[es,i]) * qREes[es,i,t];
	
		pREes[es,i,t]$(d1pEes[es,i,t]).. pREes[es,i,t]*qREes[es,i,t] =E= sum((e_a)$(d1pREa_inNest[es,e_a,i,t]), pREa[es,e_a,i,t] * qREa[es,e_a,i,t]);
	
	
		qREes&_machine_energy[es,i,t]$(d1pEes[es,i,t] and not (sameas[es,'heating'] or sameas[es,'transport']))..
			qREes[es,i,t] =E= uREes[es,i,t] * (pREes[es,i,t]/pREmachine[i,t])**(-eREes[i]) * qREmachine[i,t];
	
	
		pREmachine[i,t]$(d1pREmachine[i,t])..
			pREmachine[i,t]*qREmachine[i,t] =E= sum(es$(d1pEes[es,i,t] and not (sameas[es,'heating'] or sameas[es,'transport'])), pREes[es,i,t]*qREes[es,i,t]);
	
	$ENDBLOCK		

	$BLOCK industries_energy_demand_link industries_energy_demand_link_endogenous $(t.val>=t1.val and t.val<=tEnd.val)
	    qREes&_heating[es,i,t]$(d1pEes[es,i,t] and sameas[es,'heating'])..
	      qREes['heating',i,t] =E= qProd['heating_energy',i,t];
	  
	  
	    qREes&_transport[es,i,t]$(d1pEes[es,i,t] and sameas[es,'transport'])..
	      qREes['transport',i,t] =E= qProd['transport_energy',i,t];

	$ENDBLOCK

# Add equation and endogenous variables to main model
model main / industries_energy_demand/;
$GROUP+ main_endogenous 
		industries_energy_demand_endogenous
		;



# ------------------------------------------------------------------------------
# Exogenous values 
# ------------------------------------------------------------------------------

	eREa.l[es,i] = 0.1;
	eREes.l[i] = 0.1;

# ------------------------------------------------------------------------------
# Initial values 
# ------------------------------------------------------------------------------
	
	qREa.l[es,e_a,i,t] = qREpj.l[es,e_a,i,t];
	pREa.l[es,e_a,i,t] = pREpj_base.l[es,e_a,i,t];
	qREes.l[es,i,t]$(tDataEnd[t])     = sum(e_a, qREa.l[es,e_a,i,t]);
	pREes.l[es,i,t]$(tDataEnd[t])     = 1;
	pREmachine.l[i,t]$(tDataEnd[t])     = 1;
	qREmachine.l[i,t]$(tDataEnd[t])     = 1;

	pProd.l[pf,i,t]$(tDataEnd[t]) = 1;

# ------------------------------------------------------------------------------
# Set dummies 
# ------------------------------------------------------------------------------

	d1pREa_inNest[es,e_a,i,t] = yes$(pREpj_base.l[es,e_a,i,t]);
	d1pREa[es,e_a,i,t]        = yes$(pREpj_base.l[es,e_a,i,t]);

	d1pEes[es,i,t] 			 = yes$(sum(e_a, d1pREa_inNest[es,e_a,i,t]));	
	d1pREmachine[i,t]            = yes$(sum(es$(not (sameas[es,'Heating'] or sameas[es,'Transport'])), d1pEes[es,i,t]));
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
  -qREa[es,e_a,i,t1], uREa[es,e_a,i,t1]
  -pREes[es,i,t1], qREes[es,i,t1]
  uREes[es,i,t1]
  -pREmachine[i,t1], qREmachine[i,t1]
    calibration_endogenous
;
