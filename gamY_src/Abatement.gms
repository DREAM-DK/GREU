# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
	#DEMAND PRICES
		$PGROUP PG_abatement_dummies
      d1theta[l,es,d,t] "Dummy determining the existence of technology potentials"
      d1pK_abatement[d,t] ""
      d1uTE[l,es,e,d,t] ""
      d1qE_tech[es,e,d,t] ""
    ;

		$GROUP G_abatement_prices 
      pEpj[es,e,d,t]$(d1pEpj_base[es,e,d,t] or d1tqEpj[es,e,d,t]) "Energy price."
      pES[es,d,t]$(sum(l, d1theta[l,es,d,t])) "Price index for energy purposes"
      pT[l,es,d,t]$(d1theta[l,es,d,t]) "Price index, technology."
      pT_bar[es,d,t]$(sum(l, d1theta[l,es,d,t])) "Average technology price"
		;

		$GROUP G_abatement_prices_k 
      pK_abatement[d,t]$(d1pK_abatement[d,t]) "User cost on capital. Should probably distinguish between investment types."
		;

		$GROUP G_abatement_quantities
      qE_tech[es,e,d,t]$(d1qE_tech[es,e,d,t]) "Energy input, technology"
      qES[es,d,t]$(sum(e, d1pEpj_base[es,e,d,t]) or $(sum(e, d1tqEpj[es,e,d,t]))) "Energy service"
      qTutil[l,es,d,t]$(d1theta[l,es,d,t]) "Rate of utilization of technologies"
      qT[l,es,d,t]$(d1theta[l,es,d,t]) "Production costs (total costs of energy?)"
		;

		$GROUP G_abatement_quantities_k
      qK_tech[d,t]$(d1pK_abatement[d,t]) "Use of machine capital for technologies"
		;

		$GROUP G_abatement_values
      vES[es,d,t]$(sum(l, d1theta[l,es,d,t])) "Value of energy service"
		;

		$GROUP G_abatement_other
      theta[l,es,d,t]$(d1theta[l,es,d,t]) "Potential, technology."
      uTE[l,es,e,d,t]$(d1uTE[l,es,e,d,t]) "Energy use, technology."
      uTK[l,es,d,t]$(d1theta[l,es,d,t]) "Capital use, technology."
      svP[es,d,t]$(sum(l, d1theta[l,es,d,t])) "Average technology price"
      InputLog_Tutil[l,es,d,t]$(d1theta[l,es,d,t]) ""
      eP[l,es,d,t]$(d1theta[l,es,d,t]) "Smoothing parameter for technology adoption"
      InputErrorf_qTutil[l,es,d,t]$(d1theta[l,es,d,t]) ""
      InputErrorf_cTutil[l,es,d,t]$(d1theta[l,es,d,t]) ""
      cTutil[l,es,d,t]$(d1theta[l,es,d,t]) "Nonlinear technology costs"
    ;


## Limiting the model to only one industry and one energy service

set included_industries[d] /
  '10030'
  /;

set included_service[es] /
  'heating'
  /;

$GROUP G_abatement_prices
  G_abatement_prices$(included_industries[d] and included_service[es])
  G_abatement_prices_k$(included_industries[d])
  ;

$GROUP G_abatement_quantities
  G_abatement_quantities$(included_industries[d] and included_service[es])
  G_abatement_quantities_k$(included_industries[d])
  ;

$GROUP G_abatement_values
  G_abatement_values$(included_industries[d] and included_service[es])
  ;

$GROUP G_abatement_other
  G_abatement_other$(included_industries[d] and included_service[es])
  ;

	#AGGREGATE GROUPS 

    $PGROUP PG_abatement_flat_dummies 
    	PG_abatement_dummies
    ;

		$GROUP G_abatement_flat_after_last_data_year
			G_abatement_prices
			G_abatement_quantities
			G_abatement_other
		;

# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

	$GROUP+ price_variables
		G_abatement_prices
	;

	$GROUP+ quantity_variables
		G_abatement_quantities
	;

	$GROUP+ value_variables
    G_abatement_values
	;

	$GROUP+ other_variables
		G_abatement_other
	;

	#Add dummies to main flat-group 
	$PGROUP+ PG_flat_after_last_data_year
		PG_abatement_flat_dummies
	;
		# Add dummies to main groups
	$GROUP+ G_flat_after_last_data_year
		G_abatement_flat_after_last_data_year
	;


# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$BLOCK abatement G_abatement_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 
# and included_industries[d] and included_service[es])
  # Price index, technology
	.. pT[l,es,d,t]	=E= sum(e, uTE[l,es,e,d,t]*pEpj[es,e,d,t])
										+ uTK[l,es,d,t]*pK_abatement[d,t];

  # Scaled technology price
	.. InputLog_Tutil[l,es,d,t] =E= svP[es,d,t]/(pT[l,es,d,t]/pT_bar[es,d,t]);

  # 
  # InputErrorf_qTutil[l,es,d,t]$(d1theta[l,es,d,t])..	
  #   InputErrorf_qTutil[l,es,d,t]*eP[l,es,d,t] =E= log(InputLog_Tutil[l,es,d,t]) + 0.5*eP[l,es,d,t]**2;

  .. InputErrorf_qTutil[l,es,d,t]*eP[l,es,d,t] =E= log((InputLog_Tutil[l,es,d,t]*InputLog_Tutil[l,es,d,t])**0.5)
                                                  + 0.5*eP[l,es,d,t]**2;

  # Rate of utilization of technologies
	.. qTutil[l,es,d,t] =E= theta[l,es,d,t]*errorf(InputErrorf_qTutil[l,es,d,t]);
  
  #
  # InputErrorf_cTutil[l,es,d,t]$(d1theta[l,es,d,t]).. 
  #   InputErrorf_cTutil[l,es,d,t]*eP[l,es,d,t] =E= log(InputLog_Tutil[l,es,d,t]) - 0.5*eP[l,es,d,t]**2;

  .. InputErrorf_cTutil[l,es,d,t]*eP[l,es,d,t] =E= log((InputLog_Tutil[l,es,d,t]*InputLog_Tutil[l,es,d,t])**0.5)
                                                - 0.5*eP[l,es,d,t]**2;

	# Nonlinear costs
	.. cTutil[l,es,d,t] =E= theta[l,es,d,t]*errorf(InputErrorf_cTutil[l,es,d,t]);

	# Price index for energy purposes
	.. pES[es,d,t] =E= sum(l, cTutil[l,es,d,t]*pT[l,es,d,t]);

	# Shadow value identifying marginal technology for energy purpose
	svP[es,d,t].. 1 =E= sum(l, qTutil[l,es,d,t]);

  # Average technology price
  .. pT_bar[es,d,t] =E= (sum(l, theta[l,es,d,t]*pT[l,es,d,t])
                                                                 / sum(l, theta[l,es,d,t]))
                                                                 * (1/sum(l, d1theta[l,es,d,t]));

### AGGREGATES ###

  # Value of energy service
  .. vES[es,d,t] =E= qES[es,d,t]*pES[es,d,t];

  # Production costs (total costs of energy?)
  .. qT[l,es,d,t]	=E= cTutil[l,es,d,t]*qES[es,d,t];

  # Use of energy goods
  .. qE_tech[es,e,d,t] =E= sum(l, uTE[l,es,e,d,t]*qT[l,es,d,t]);

  # Use of machine capital for technologies
  qK_tech[d,t].. qK_tech[d,t] =E= sum((l,es), uTK[l,es,d,t]*qT[l,es,d,t]);

$ENDBLOCK

# Add equation and endogenous variables to main model
model main / abatement /;
$GROUP+ main_endogenous G_abatement_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP abatement_data_variables
  theta[l,es,d,t]
  uTE[l,es,e,d,t]
  uTK[l,es,d,t]
;
@load(abatement_data_variables, "../data/data.gdx")
$GROUP+ data_covered_variables abatement_data_variables;

# Dummies
d1theta[l,es,d,t] = yes$(theta.l[l,es,d,t] and included_industries[d] and included_service[es]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t] and included_industries[d] and included_service[es]);
d1pK_abatement[d,t] = yes$(sum((l,es), d1theta[l,es,d,t]));
d1qE_tech[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));

# Initial values
pK_abatement.l[d,t]$(sum((l,es), d1theta[l,es,d,t])) = 0.1;
qES.l[es,d,t] = sum(e, qEpj.l[es,e,d,t]);

svP.l[es,d,t]$(sum(l, d1theta[l,es,d,t])) = 1;
eP.l[l,es,d,t]$(d1theta[l,es,d,t]) = 0.5;

# Electrification technologies that are not present in data
$import calib_electrification_techs.gms


# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

# Add equations and calibration equations to calibration model
model calibration /
  abatement
/;
# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  G_abatement_endogenous

  calibration_endogenous
;