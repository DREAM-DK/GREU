# ------------------------------------------------------------------------------
# Variable and group creation
# ------------------------------------------------------------------------------

$IF %stage% == "variables":
	$SetGroup+ SG_flat_after_last_data_year
		d1pEpj_marg[es,e,i,t] ""
		d1pEpj_marg_inNest[es,e,d,t] ""
		d1pEpj_marg_NotinNest[es,e,d,t] ""
		d1pEes[es,i,t] ""
		d1pREmachine[i,t] ""
		d1Prod[pf,i,t] ""
	;
	
	$Group+ all_variables 
		pREes[es,i,t]$(d1pEes[es,i,t]) 						"Price of nest of energy-activities, aggregated to energy-services, CES-price index."
		pREmachine[i,t]$(d1pREmachine[i,t]) 			"Price of machine energy, CES-price index."
		pProd[pf,i,t]$(d1Prod[pf,i,t]) 						"Production price of production function pf in sector i at time t" #Should be moved to production.gms when stages are implemented
		qREes[es,i,t]$(d1pEes[es,i,t]) 						"CES-Quantity of energy-services, measured in bio 2019-DKK"
		qREmachine[i,t]$(d1pREmachine[i,t]) 			"CES-Quantity of machine energy, measured in bio 2019-DKK"
		qProd[pf,i,t]$(d1Prod[pf,i,t]) 						"CES-quantity of production function pf in sector i at time t" #Should be moved to production.gms when stages are implemented
		qEpj_BiogasForConvertingData[t] 					"Quantity of biogas for converting to natural gas in gas distribution sector, measured in peta Joule"
		qEpj_ElectricityForDatacentersData[t] 		"Quantity of electricity for data centers, measured in peta Joule"
		vEnergycostsnotinnesting[i,t]  					"Total cost of energy not in in CES-nested production function (but added to production costs), measured in bio kroner"
		eEpj[es,i] 																	"Elasticity of substitution between energy-activities for a given energy-service"
		uEpj[es,e,i,t]$(d1pEpj_marg[es,e,i,t]) 			"CES-share for energy-activity in industry i"

		uREes[es,i,t]$(d1pEes[es,i,t] and not (heating[es] or transport[es])) "CES-share between energy-service and energy-activity"				
		eREes[i] 																		"Elasticity of substitution between energy-services for industri i"


	;
$ENDIF

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------

$IF %stage% == "equations":
	$BLOCK industries_energy_demand industries_energy_demand_endogenous $(t.val>=t1.val and t.val<=tEnd.val)

		#In nests
			qEpj&_inNest[es,e,i,t]$(d1pepj_marg_innest[es,e,i,t]).. 
				qEpj[es,e,i,t] =E= uEpj[es,e,i,t] * (pEpj_marg[es,e,i,t]/pREes[es,i,t])**(-eEpj[es,i]) * qREes[es,i,t];
		
			pREes[es,i,t]$(d1pEes[es,i,t]).. pREes[es,i,t]*qREes[es,i,t] 
																					=E= sum((e)$(d1pEpj_marg_inNest[es,e,i,t]), pEpj_marg[es,e,i,t] * qEpj[es,e,i,t])
																						+ vESK[es,i,t];
		
		
			qREes&_machine_energy[es,i,t]$(d1pEes[es,i,t] and not (heating[es] or transport[es]))..
				qREes[es,i,t] =E= uREes[es,i,t] * (pREes[es,i,t]/pREmachine[i,t])**(-eREes[i]) * qREmachine[i,t];
		
		
			pREmachine[i,t]$(d1pREmachine[i,t])..
				pREmachine[i,t]*qREmachine[i,t] =E= sum(es$(d1pEes[es,i,t] and not (heating[es] or transport[es])), pREes[es,i,t]*qREes[es,i,t]);

		#Not in nests 
			qEpj&_crudeoilrefineries[es,e,i,t]$(d1pEpj_marg_NotinNest[es,e,i,t] and process_special[es] and crudeoil[e] and d_refineries[i]).. 
				qEpj[es,e,i,t] =E= uEpj[es,e,i,t] * qProd['TopPfunction',i,t];

			qEpj&_BiogasForConverting[es,e,i,t]$(d1pEpj_marg_NotinNest[es,e,i,t] and process_special[es] and biogas[e] and d_gasdistribution[i])..
				qEpj[es,e,i,t] =E= uEpj[es,e,i,t] * qEpj_BiogasForConvertingData[t];

			qEpj&_ElectricityForDatacenters[es,e,i,t]$(d1pEpj_marg_NotinNest[es,e,i,t] and process_special[es] and el[e] and d_service_for_industries[i])..	
				qEpj[es,e,i,t] =E= uEpj[es,e,i,t] * qEpj_ElectricityForDatacentersData[t];

			qEpj&_Natural[es,e,i,t]$(d1pEpj_marg_NotinNest[es,e,i,t] and process_special[es] and natgas_ext[e] and d_gasdistribution[i])..	
				qEpj[es,e,i,t] =E= uEpj[es,e,i,t] * (qY_CET['Natural gas incl. biongas','35002',t] - qEpj['process_special','Biogas','35002',t]);
		
			vEnergycostsnotinnesting[i,t].. vEnergycostsnotinnesting[i,t] =E= sum((es,e)$(d1pEpj_marg_NotinNest[es,e,i,t]), pEpj_marg[es,e,i,t] * qEpj[es,e,i,t]);

			# Link energy costs not in nesting to production module (aggregate approximation)
			# J-term stands in for vEnergycostsnotinnesting used in production.gms equation
			jvEnergycostsnotinnesting[i,t]$(d1Y_i[i,t])..
				jvEnergycostsnotinnesting[i,t] =E= vEnergycostsnotinnesting[i,t];

	$ENDBLOCK		

	$BLOCK industries_energy_demand_link industries_energy_demand_link_endogenous $(t.val>=t1.val and t.val<=tEnd.val)
	    qREes&_heating[es,i,t]$(d1pEes[es,i,t] and heating[es])..
	      qREes['heating',i,t] =E= qProd['heating_energy',i,t];
	  
	    qREes&_transport[es,i,t]$(d1pEes[es,i,t] and transport[es])..
	      qREes['transport',i,t] =E= qProd['transport_energy',i,t];

			qREmachine[i,t]$(d1pREmachine[i,t])..
				qREmachine[i,t] =E= qProd['machine_energy',i,t];

		
			jpProd&_machine_energy[pf_bottom_e,i,t]$(sameas[pf_bottom_e,'machine_energy'])..
				pProd[pf_bottom_e,i,t] =E= pREmachine[i,t];

			jpProd&_transport_energy[pf_bottom_e,i,t]$(sameas[pf_bottom_e,'transport_energy'])..
				pProd[pf_bottom_e,i,t] =E= pREes['transport',i,t];

			jpProd&_heating_energy[pf_bottom_e,i,t]$(sameas[pf_bottom_e,'heating_energy'])..
				pProd[pf_bottom_e,i,t] =E= pREes['heating',i,t];

	$ENDBLOCK

	# Add equation and endogenous variables to main model
	model main / industries_energy_demand
								industries_energy_demand_link
								/;
	$Group+ main_endogenous 
			industries_energy_demand_endogenous
			industries_energy_demand_link_endogenous
			
			;

$ENDIF

# ------------------------------------------------------------------------------
# Exogenous values 
# ------------------------------------------------------------------------------

$IF %stage% == "exogenous_values":

	eEpj.l[es,i] = 0.1;
	eREes.l[i] = 0.1;

# ------------------------------------------------------------------------------
# Initial values 
# ------------------------------------------------------------------------------
	
	pEpj_marg.l[es,e,i,t]$(d1pEpj_marg[es,e,i,t]) = pEpj_base.l[es,e,i,t];
	qREes.l[es,i,t]$(tDataEnd[t])     = sum(e, qEpj.l[es,e,i,t]);
	pREes.l[es,i,t]$(tDataEnd[t])     = 1;
	pREmachine.l[i,t]$(tDataEnd[t])   = 1;
	qREmachine.l[i,t]$(tDataEnd[t])   = 1;

	pProd.l[pf,i,t]$(tDataEnd[t])     = 1;


	qEpj_BiogasForConvertingData.l[t]       = qEpj.l['process_special','Biogas','35002',t];
	qEpj_ElectricityForDatacentersData.l[t] = qEpj.l['process_special','Electricity','71000',t];

# ------------------------------------------------------------------------------
# Set dummies 
# ------------------------------------------------------------------------------
	#Moved to energy_and_emissions_taxes.gms

$ENDIF

# ------------------------------------------------------------------------------
# Starting values
# ------------------------------------------------------------------------------
$IF %stage% == "starting_values":

set_time_periods(%calibration_year%, %calibration_year%);

$Group non_default_starting_values
  # Variables that require custom starting values
;

# Set custom starting values for the variables in non_default_starting_values here

$ENDIF # starting_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":

	# Add equations and calibration equations to calibration model
	model calibration /
		industries_energy_demand
		industries_energy_demand_link
	/;

	# Add endogenous variables to calibration model
	$Group calibration_endogenous
		industries_energy_demand_endogenous
		-qEpj[es,e,i,t1], uEpj[es,e,i,t1]$(qEpj_exists_dummy[es,e,i,t1])
		-pREes[es,i,t1],    qREes[es,i,t1]
		uREes[es,i,t1]
		-pREmachine[i,t1], qREmachine[i,t1]

		industries_energy_demand_link_endogenous
		qProd[pf_bottom_e,i,t1]

			calibration_endogenous
	;

	$Group+ G_flat_after_last_data_year
  	uEpj$(d1pEpj_marg_inNest[es,e,i,t] or d1pEpj_marg_NotinNest[es,e,i,t])
		uREes
	;


$ENDIF