# ------------------------------------------------------------------------------
# Variable and group creation
# ------------------------------------------------------------------------------

$IF %stage% == "variables":
	$SetGroup+ SG_flat_after_last_data_year
		d1pREa[es,e_a,i,t] ""
		d1pREa_inNest[es,e_a,i,t] ""
		d1pREa_NotinNest[es,e_a,i,t] ""
		d1pEes[es,i,t] ""
		d1pREmachine[i,t] ""
		d1Prod[pf,i,t] ""
	;
	
	$Group+ all_variables 
		pREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t])   	"Price of energy-activity (e_a), split on services (es) measured in DKK per peta Joule (when abatement is turned off)"
		pREes[es,i,t]$(d1pEes[es,i,t]) 						"Price of nest of energy-activities, aggregated to energy-services, CES-price index."
		pREmachine[i,t]$(d1pREmachine[i,t]) 			"Price of machine energy, CES-price index."
		pProd[pf,i,t]$(d1Prod[pf,i,t]) 						"Production price of production function pf in sector i at time t" #Should be moved to production.gms when stages are implemented
		qREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t]) 		"Industries demand for energy activity (e_a). When abatement is turned off, the energy-activity is measured in PJ, and corresponds 1:1 to qEpj"		#Skal flyttes til industries_CES_energydemand.gms, når vi får stages
		qREes[es,i,t]$(d1pEes[es,i,t]) 						"CES-Quantity of energy-services, measured in bio 2019-DKK"
		qREmachine[i,t]$(d1pREmachine[i,t]) 			"CES-Quantity of machine energy, measured in bio 2019-DKK"
		qProd[pf,i,t]$(d1Prod[pf,i,t]) 						"CES-quantity of production function pf in sector i at time t" #Should be moved to production.gms when stages are implemented
		qREa_BiogasForConvertingData[t] 					"Quantity of biogas for converting to natural gas in gas distribution sector, measured in peta Joule"
		qREa_ElectricityForDatacentersData[t] 		"Quantity of electricity for data centers, measured in peta Joule"
		vEnergycostsnotinnesting[i,t]  					"Total cost of energy not in in CES-nested production function (but added to production costs), measured in bio kroner"
		eREa[es,i] 																	"Elasticity of substitution between energy-activities for a given energy-service"
		uREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t]) 			"CES-share for energy-activity in industry i"
	
		vREa[es,e_a,i,t]$(d1pREa[es,e_a,i,t]) 			"Value of energy-activity (e_a) in industry i, measured in bio 2019-DKK"

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
			qREa&_inNest[es,e_a,i,t]$(d1pREa_inNest[es,e_a,i,t]).. 
				qREa[es,e_a,i,t] =E= uREa[es,e_a,i,t] * (pREa[es,e_a,i,t]/pREes[es,i,t])**(-eREa[es,i]) * qREes[es,i,t];
		
			# pREes[es,i,t]$(d1pEes[es,i,t]).. pREes[es,i,t]*(qREes[es,i,t] + Delta_qESK[es,i,t]$(d1qES[es,i,t])) 
			pREes[es,i,t]$(d1pEes[es,i,t]).. pREes[es,i,t]*qREes[es,i,t] 
																					=E= sum((e_a)$(d1pREa_inNest[es,e_a,i,t]), pREa[es,e_a,i,t] * qREa[es,e_a,i,t]);
																						# + (Delta_vESK[es,i,t])$(d1qES[es,i,t]);
		
		
			qREes&_machine_energy[es,i,t]$(d1pEes[es,i,t] and not (heating[es] or transport[es]))..
				qREes[es,i,t] =E= uREes[es,i,t] * (pREes[es,i,t]/pREmachine[i,t])**(-eREes[i]) * qREmachine[i,t];
		
		
			pREmachine[i,t]$(d1pREmachine[i,t])..
				pREmachine[i,t]*qREmachine[i,t] =E= sum(es$(d1pEes[es,i,t] and not (heating[es] or transport[es])), pREes[es,i,t]*qREes[es,i,t]);

		#Not in nests 
			qREa&_crudeoilrefineries[es,e_a,i,t]$(d1pREa_NotinNest[es,e_a,i,t] and process_special[es] and crudeoil[e_a] and i_refineries[i]).. 
				qREa[es,e_a,i,t] =E= uREa[es,e_a,i,t] * qProd['TopPfunction',i,t];

			qREa&_BiogasForConverting[es,e_a,i,t]$(d1pREa_NotinNest[es,e_a,i,t] and process_special[es] and biogas[e_a] and i_gasdistribution[i])..
				qREa[es,e_a,i,t] =E= uREa[es,e_a,i,t] * qREa_BiogasForConvertingData[t];

			qREa&_ElectricityForDatacenters[es,e_a,i,t]$(d1pREa_NotinNest[es,e_a,i,t] and process_special[es] and el[e_a] and i_service_for_industries[i])..	
				qREa[es,e_a,i,t] =E= uREa[es,e_a,i,t] * qREa_ElectricityForDatacentersData[t];

			qREa&_Natural[es,e_a,i,t]$(d1pREa_NotinNest[es,e_a,i,t] and process_special[es] and natgas_ext[e_a] and i_gasdistribution[i])..	
				qREa[es,e_a,i,t] =E= uREa[es,e_a,i,t] * (qY_CET['Natural gas incl. biongas','35002',t] - qREa['process_special','Biogas','35002',t]);
		
			vEnergycostsnotinnesting[i,t].. vEnergycostsnotinnesting[i,t] =E= sum((es,e_a)$(d1pREa_NotinNest[es,e_a,i,t]), pREa[es,e_a,i,t] * qREa[es,e_a,i,t]);

			.. vREa[es,e_a,i,t] =E= pREa[es,e_a,i,t] * qREa[es,e_a,i,t]; #Value of energy-activity (e_a) in industry i, measured in bio 2019-DKK

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

			#Should be linked in abatement-module when turned on
			.. pREa[es,e,i,t] =E= pEpj_marg[es,e,i,t];

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

	eREa.l[es,i] = 0.1;
	eREes.l[i] = 0.1;

# ------------------------------------------------------------------------------
# Initial values 
# ------------------------------------------------------------------------------
	
	qREa.l[es,e_a,i,t]                = qEpj.l[es,e_a,i,t];
	pREa.l[es,e_a,i,t]                = pEpj_base.l[es,e_a,i,t];
	pEpj_marg.l[es,e,i,t]             = pREa.l[es,e,i,t];
	qREes.l[es,i,t]$(tDataEnd[t])     = sum(e_a, qREa.l[es,e_a,i,t]);
	pREes.l[es,i,t]$(tDataEnd[t])     = 1;
	pREmachine.l[i,t]$(tDataEnd[t])   = 1;
	qREmachine.l[i,t]$(tDataEnd[t])   = 1;

	pProd.l[pf,i,t]$(tDataEnd[t])     = 1;


	qREa_BiogasForConvertingData.l[t]       = qEpj.l['process_special','Biogas','35002',t];
	qREa_ElectricityForDatacentersData.l[t] = qEpj.l['process_special','Electricity','71000',t];

# ------------------------------------------------------------------------------
# Set dummies 
# ------------------------------------------------------------------------------
	#Moved to energy_and_emissions_taxes.gms

$ENDIF

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
		-qREa[es,e_a,i,t1], uREa[es,e_a,i,t1]
		-pREes[es,i,t1],    qREes[es,i,t1]
		uREes[es,i,t1]
		-pREmachine[i,t1], qREmachine[i,t1]

		industries_energy_demand_link_endogenous
		qProd[pf_bottom_e,i,t1]

			calibration_endogenous
	;

	$Group+ G_flat_after_last_data_year
  	uREa$(d1pREa_inNest[es,e_a,i,t] or d1pREa_NotinNest[es,e_a,i,t])
		uREes
	;

$ENDIF