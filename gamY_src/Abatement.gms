$macro loga(x) log(((x)*(x))**0.5)

# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
	#DEMAND PRICES
		$PGROUP PG_abatement_dummies
      d1theta[l,es,i,t]
      d1pK_abatement[i,t]
      d1uTE[l,es,e,i,t]
      d1qE_tech[es,e,i,t]
    ;

		$GROUP G_abatement_prices 
      pREpj[es,e,i,t]$(d1pREpj_base[es,e,i,t]) "Energy price."
      pES[es,i,t]$(sum(l, d1theta[l,es,i,t])) "Price index for energy purposes"
      pT[l,es,i,t]$(d1theta[l,es,i,t]) "Price index, technology."
      pK_abatement[i,t]$(d1pK_abatement[i,t]) "User cost on capital. Should probably distinguish between investment types."
      pT_bar[es,i,t] "Average technology price"
		;

		$GROUP G_abatement_quantities
      qE_tech[es,e,i,t]$(d1qE_tech[es,e,i,t]) "Energy input, technology"
      qES[es,i,t]$(sum(e, d1pREpj_base[es,e,i,t])) "Energy service"
      qTutil[l,es,i,t]$(d1theta[l,es,i,t]) "Rate of utilization of technologies"
      qT[l,es,i,t]$(d1theta[l,es,i,t]) "Production costs (total costs of energy?)"
    #   qK_tech[i,t] "Use of machine capital for technologies"
		;

		$GROUP G_abatement_values
      vES[es,i,t]$(sum(l, d1theta[l,es,i,t])) "Value of energy service"
		;

		$GROUP G_abatement_other
      theta[l,es,i,t]$(d1theta[l,es,i,t]) "Potential, technology."
      uTE[l,es,e,i,t]$(d1uTE[l,es,e,i,t]) "Energy use, technology."
      uTK[l,es,i,t]$(d1theta[l,es,i,t]) "Capital use, technology."
      svP[es,i,t]$(sum(l, d1theta[l,es,i,t])) "Average technology price"
      InputLog_Tutil[l,es,i,t]$(d1theta[l,es,i,t]) ""
      eP[l,es,i,t]$(d1theta[l,es,i,t]) "Smoothing parameter for technology adoption"
      InputErrorf_qTutil[l,es,i,t]$(d1theta[l,es,i,t]) ""
      InputErrorf_cTutil[l,es,i,t]$(d1theta[l,es,i,t]) ""
      cTutil[l,es,i,t]$(d1theta[l,es,i,t]) "Nonlinear technology costs"
    ;

	#AGGREGATE GROUPS 

    $PGROUP PG_abatement_flat_dummies 
    	PG_abatement_dummies
    ;

		$GROUP G_abatement_flat_after_last_data_year
			G_abatement_prices
			G_abatement_quantities
			G_abatement_other
      # -uTK
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
  # Price index, technology
	pT[l,es,i,t]$(d1theta[l,es,i,t])..	pT[l,es,i,t]	=E= sum(e, uTE[l,es,e,i,t]*pREpj[es,e,i,t])
																	                    + uTK[l,es,i,t]*pK_abatement[i,t];

  # Scaled technology price
	InputLog_Tutil[l,es,i,t]$(d1theta[l,es,i,t]).. 
    InputLog_Tutil[l,es,i,t] =E= svP[es,i,t]/(pT[l,es,i,t]/pT_bar[es,i,t]);

  # 
  InputErrorf_qTutil[l,es,i,t]$(d1theta[l,es,i,t])..	
    InputErrorf_qTutil[l,es,i,t]*eP[l,es,i,t] =E= log(InputLog_Tutil[l,es,i,t])+0.5*eP[l,es,i,t]**2;

  # Rate of utilization of technologies
	qTutil[l,es,i,t]$(d1theta[l,es,i,t])..	
    qTutil[l,es,i,t] =E= theta[l,es,i,t]*errorf(InputErrorf_qTutil[l,es,i,t]);
  
  #
  InputErrorf_cTutil[l,es,i,t]$(d1theta[l,es,i,t]).. 
    InputErrorf_cTutil[l,es,i,t]*eP[l,es,i,t] =E= log(InputLog_Tutil[l,es,i,t])-0.5*eP[l,es,i,t]**2;

	# Nonlinear costs
	cTutil[l,es,i,t]$(d1theta[l,es,i,t])..	cTutil[l,es,i,t] =E= theta[l,es,i,t]*errorf(InputErrorf_cTutil[l,es,i,t]);

	# Price index for energy purposes
	pES[es,i,t]$(sum(l, d1theta[l,es,i,t])).. pES[es,i,t] =E= sum(l, cTutil[l,es,i,t]*pT[l,es,i,t]);

	# Shadow value identifying marginal technology for energy purpose
	svP[es,i,t]$(sum(l, d1theta[l,es,i,t])).. 1 =E= sum(l, qTutil[l,es,i,t]);

  # Average technology price
  pT_bar[es,i,t]$(sum(l, d1theta[l,es,i,t])).. pT_bar[es,i,t] =E= (sum(l, theta[l,es,i,t]*pT[l,es,i,t])
                                                                 / sum(l, theta[l,es,i,t]))
                                                                 * (1/sum(l, d1theta[l,es,i,t]));

### AGGREGATES ###

  # Value of energy service
  vES[es,i,t]$(sum(l, d1theta[l,es,i,t])).. vES[es,i,t] =E= qES[es,i,t]*pES[es,i,t];

  # Production costs (total costs of energy?)
  qT[l,es,i,t]$(d1theta[l,es,i,t]).. qT[l,es,i,t]	=E= cTutil[l,es,i,t]*qES[es,i,t];

  # Use of energy goods
  qE_tech[es,e,i,t]$(sum(l, d1theta[l,es,i,t])).. qE_tech[es,e,i,t] =E= sum(l, uTE[l,es,e,i,t]*qT[l,es,i,t]);

  # # Use of machine capital for technologies
  # qK_tech[i,t].. qK_tech[i,t] =E= sum((l,es), uTK[l,i,es,t]*qT[l,i,es,t]);

$ENDBLOCK

# Add equation and endogenous variables to main model
model main / abatement /;
$GROUP+ main_endogenous G_abatement_endogenous;

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$GROUP abatement_data_variables
  theta[l,es,i,t]
  uTE[l,es,e,i,t]
  uTK[l,es,i,t]
;
@load(abatement_data_variables, "../data/data.gdx")
$GROUP+ data_covered_variables abatement_data_variables;

# qES.l[i,es,t] = sum(e, qE.l[i,es,e,t]);

# uTK.l[l,es,i,t] = uTK.l[l,es,i,t];

d1theta[l,es,i,t] = yes$(theta.l[l,es,i,t]);
d1uTE[l,es,e,i,t] = yes$(uTE.l[l,es,e,i,t]);
d1pK_abatement[i,t] = yes$(sum((l,es), d1theta[l,es,i,t]));
d1qE_tech[es,e,i,t] = yes$(sum(l, d1uTE[l,es,e,i,t]));

pK_abatement.l[i,t]$(sum((l,es), d1theta[l,es,i,t])) = 0.1;
qES.l[es,i,t] = sum(e, qREpj.l[es,e,i,t]);

svP.l[es,i,t]$(sum(l, d1theta[l,es,i,t])) = 1;
eP.l[l,es,i,t]$(d1theta[l,es,i,t]) = 0.5;

# Electrification technologies that are not present in data
$import calib_electrification_techs.gms

# set included_s[i] /
#   '01011'
#   /;

# d1theta[l,es,i,t]$(not (included_s[i])) = no;
# d1uTE[l,es,e,i,t]$(not (included_s[i])) = no;
# d1pK_abatement[i,t] = no;
# d1pK_abatement[i,t] = yes$(sum((l,es), d1theta[l,es,i,t]));
# d1qE_tech[es,e,i,t] = no;
# d1qE_tech[es,e,i,t] = yes$(sum(l, d1uTE[l,es,e,i,t]));


## Recalibration of technology potentials (start)
# pREpj_base.l[es,e,i,t]$(d1pREpj_base[es,e,i,t]) = (1+fpRE.l[es,e,i,t]) * pE_avg.l[e,t];

# pREpj.l[es,e,i,t]$(d1pREpj_base[es,e,i,t]) = (1+tpRE.l[es,e,i,t]) * pREpj_base.l[es,e,i,t];
# pREpj.l[es,e,i,t]$(d1tqRE[es,e,i,t]) = tqRE.l[es,e,i,t];

# # Technology price
# pT.l[l,es,i,t]$(d1theta[l,es,i,t]) = sum(e$(d1uTE[l,es,e,i,t]), uTE.l[l,es,e,i,t]*pREpj.l[es,e,i,t])
# 																	  + uTK.l[l,es,i,t]*pK_abatement.l[i,t];

# parameter
#   d1Expensive_tech[l,es,i,t]
#   d1Expensive_tech_test[es,i,t]
#   ;

# d1Expensive_tech[l,es,i,t]$(d1theta[l,es,i,t]) = yes$(pT.l[l,es,i,t] >= sum(ll, pT.l[ll,es,i,t]) / sum(ll, d1theta[ll,es,i,t]));

# d1Expensive_tech[l,es,i,t]$(d1theta[l,es,i,t]) = yes$(pT.l[l,es,i,t] >= smax(ll, pT.l[ll,es,i,t]) - 0.001);
# d1Expensive_tech_test[es,i,t] = smax(ll, pT.l[ll,es,i,t]);

# theta.l[l,es,i,t]$(d1Expensive_tech[l,es,i,t] and d1theta[l,es,i,t]) = (1.1 - sum(ll$(not d1Expensive_tech[ll,es,i,t] and d1theta[l,es,i,t]), theta.l[ll,es,i,t]))
#                                                                       / sum(ll, d1Expensive_tech[ll,es,i,t]);

# theta.l[l,es,i,t]$(d1Expensive_tech[l,es,i,t]) = theta.l[l,es,i,t]*1.05; # We scale the most expensive technology potentials by 5 pct.

# theta.l[l,es,i,t] = theta.l[l,es,i,t]*1.001; # We scale technology potentials by 20 pct.

## Recalibration of technology potentials (end)








parameters
  theta_sum[es,i,t]
  ;

theta_sum[es,i,t]$(sum(l, d1theta[l,es,i,t])) = sum(l, theta.l[l,es,i,t]);

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
# $BLOCK abatement_calibration G_abatement_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
#   # Energy prices are held constant in forecast years
#   # pE_base[i,es,e,t]$(t.val > t1.val).. pE_base[i,es,e,t] =E= pE_base[i,es,e,t1];

#   # Technology potentials are held constant in forecast years
#   # theta[l,i,es,t]$(t.val > t1.val).. theta[l,i,es,t] =E= theta[l,i,es,t1];
#   # uTE[l,es,e,i,t]$(t.val > t1.val).. uTE[l,es,e,i,t] =E= uTE[l,es,e,i,t1];
#   # uTK[l,es,i,t]$(t.val > t1.val).. uTK[l,es,i,t] =E= uTK[l,es,i,t1];
#   # pK_abatement[i,t]$(t.val > t1.val).. pK_abatement[i,t] =E= pK_abatement[i,t1];
#   # eP[l,es,i,t]$(t.val > t1.val).. eP[l,es,i,t] =E= eP[l,es,i,t1];
  
# $ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  abatement
  # abatement_calibration
/;
# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  # G_abatement_calibration_endogenous
  G_abatement_endogenous

  calibration_endogenous
;