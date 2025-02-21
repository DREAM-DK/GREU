# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1sTPotential[l,es,d,t] "Dummy determining the existence of technology potentials"
  d1pK_abatement[d,t] "Dummy determining the existence of user costs for technologies"
  d1uTE[l,es,e,d,t] "Dummy determining the existence of energy input in technology"
  d1qE_tech[es,e,d,t] "Dummy determining the existence of energy use (sum across technologies)"
;

$Group+ all_variables
  qES[es,d,t]$(sum(e, d1pEpj_base[es,e,d,t]) or $(sum(e, d1tqEpj[es,e,d,t]))) "Energy service, quantity."
  pES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Energy service, price."
  vES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Value of energy service" 
                              
  
  pEpj[es,e,d,t]$(d1pEpj_base[es,e,d,t] or d1tqEpj[es,e,d,t]) "Energy price."
  qE_tech[es,e,d,t]$(d1qE_tech[es,e,d,t]) "Energy input, technology."

  pT[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Price per PJ of energy service for technology l at full potential, ie. when sTSupply=sTPotential"
  pT_bar[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Average technology price."

  pK_abatement[d,t]$(d1pK_abatement[d,t]) "User cost on capital. Should probably distinguish between investment types."
  qK_tech[d,t]$(d1pK_abatement[d,t]) "Use of machine capital for technologies."

  sTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Ratio of Energy Service (qES) supplied by technology l"
  qT[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Production costs (total costs of energy?)."

  sTPotential[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Potential ratio of energy service (qES) supplied by technology l"
  theta[l,es,d,t]$(d1sTPotential[l,es,d,t]) "jsk same sTPotential. only used adhoc for loading data"
  uTE[l,es,e,d,t]$(d1uTE[l,es,e,d,t]) "Energy use, technology."
  uTK[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Capital use, technology."
  svP[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Average technology price"
  # InputLog_Tutil[l,es,d,t]$(d1sTPotential[l,es,d,t]) ""
  eP[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Smoothing parameter for technology adoption"
  #InputErrorf_sTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) ""
  #InputErrorf_cTutil[l,es,d,t]$(d1sTPotential[l,es,d,t]) ""
  cTutil[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Nonlinear technology costs"
  vTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Value (or costs) of energy service supplied by technology l "
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK abatement_equations abatement_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 
# and included_industries[d] and included_service[es])
  # Price index, technology
	.. pT[l,es,d,t]	=E= sum(e, uTE[l,es,e,d,t]*pEpj[es,e,d,t])
										+ uTK[l,es,d,t]*pK_abatement[d,t];

  # Scaled technology price
	#.. InputLog_Tutil[l,es,d,t] =E= svP[es,d,t]/(pT[l,es,d,t]/pT_bar[es,d,t]);
  #.. InputLog_Tutil[l,es,d,t] =E= svP[es,d,t]/pT[l,es,d,t];

  # 
  # InputErrorf_sTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t])..	
  #   InputErrorf_sTSupply[l,es,d,t]*eP[l,es,d,t] =E= log(InputLog_Tutil[l,es,d,t]) + 0.5*eP[l,es,d,t]**2;

  #.. InputErrorf_sTSupply[l,es,d,t]*eP[l,es,d,t] =E= log((InputLog_Tutil[l,es,d,t]*InputLog_Tutil[l,es,d,t])**0.5)
  #                                                + 0.5*eP[l,es,d,t]**2;

  # Supply of tecnology l in ratio of energy demand qES
  	.. sTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*errorf(
                                                            log( ( (svP[es,d,t]/pT[l,es,d,t])**2 )**0.5)
                                                            + 0.5*eP[l,es,d,t]**2
                                                            );
  
  #
  # InputErrorf_cTutil[l,es,d,t]$(d1sTPotential[l,es,d,t]).. 
  #   InputErrorf_cTutil[l,es,d,t]*eP[l,es,d,t] =E= log(InputLog_Tutil[l,es,d,t]) - 0.5*eP[l,es,d,t]**2;

 # .. InputErrorf_cTutil[l,es,d,t]*eP[l,es,d,t] =E= log((InputLog_Tutil[l,es,d,t]*InputLog_Tutil[l,es,d,t])**0.5)
#                                                - 0.5*eP[l,es,d,t]**2;

	# Nonlinear costs
	.. cTutil[l,es,d,t] =E= sTPotential[l,es,d,t]*errorf(
                                                            log( ( (svP[es,d,t]/pT[l,es,d,t])**2 )**0.5)
                                                            - 0.5*eP[l,es,d,t]**2   
                                                        );

# Value (or costs) of energy service supplied by technology l
.. vTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*errorf(
                                                            log( ( (svP[es,d,t]/pT[l,es,d,t])**2 )**0.5)
                                                            - 0.5*eP[l,es,d,t]**2   
                                                        )
                          *qES[es,d,t]*pT[l,es,d,t];


	# Price index for energy purposes
	.. pES[es,d,t] =E= sum(l, cTutil[l,es,d,t]*pT[l,es,d,t]);

	# Shadow value identifying marginal technology for energy purpose
	svP[es,d,t].. 1 =E= sum(l, sTSupply[l,es,d,t]);

  # Average technology price
  .. pT_bar[es,d,t] =E= (sum(l, sTPotential[l,es,d,t]*pT[l,es,d,t])
                                                                 / sum(l, sTPotential[l,es,d,t]))
                                                                 * (1/sum(l, d1sTPotential[l,es,d,t]));

### AGGREGATES ###

  # Value of energy service
  .. vES[es,d,t] =E= sum(l,vTSupply[l,es,d,t]);

  # Production costs (total costs of energy?)
  .. qT[l,es,d,t]	=E= cTutil[l,es,d,t]*qES[es,d,t];

  # Use of energy goods
  .. qE_tech[es,e,d,t] =E= sum(l, uTE[l,es,e,d,t]*qT[l,es,d,t]);

  # Use of machine capital for technologies
  .. qK_tech[d,t] =E= sum((l,es), uTK[l,es,d,t]*qT[l,es,d,t]);

$ENDBLOCK

# Add equation and endogenous variables to main model
model main / abatement_equations /;
$GROUP+ main_endogenous abatement_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$GROUP abatement_data_variables
#jsk  sTPotential[l,es,d,t]
  theta[l,es,d,t]
  uTE[l,es,e,d,t]
  uTK[l,es,d,t]
;
@load(abatement_data_variables, "../data/data.gdx")
$GROUP+ data_covered_variables abatement_data_variables;

#jsk
sTPotential.l[l,es,d,t] =  theta.l[l,es,d,t] ;

## Limiting the model to only one industry and one energy service
set included_industries[d] /
  '10030'
  /;

set included_service[es] /
  'heating'
  /;

# Dummies
d1sTPotential[l,es,d,t] = yes$(sTPotential.l[l,es,d,t] and included_industries[d] and included_service[es]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t] and included_industries[d] and included_service[es]);
d1pK_abatement[d,t] = yes$(sum((l,es), d1sTPotential[l,es,d,t]));
d1qE_tech[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));

# Initial values
pK_abatement.l[d,t]$(sum((l,es), d1sTPotential[l,es,d,t])) = 0.1;
qES.l[es,d,t] = sum(e, qEpj.l[es,e,d,t]);

svP.l[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) = 1;
eP.l[l,es,d,t]$(d1sTPotential[l,es,d,t]) = 0.5;

# Electrification technologies that are not present in data
$import calib_electrification_techs.gms

$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

# Add equations and calibration equations to calibration model
model calibration /
  abatement_equations
/;
# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  abatement_endogenous

  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  qES[es,d,t]
  pES[es,d,t]
  vES[es,d,t]
  
  pEpj[es,e,d,t]
  qE_tech[es,e,d,t]

  pT[l,es,d,t]
  pT_bar[es,d,t]

  pK_abatement[d,t]
  qK_tech[d,t]

  sTSupply[l,es,d,t]
  vTSupply[l,es,d,t]
  qT[l,es,d,t]

  sTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  uTK[l,es,d,t]
  svP[es,d,t]
  # InputLog_Tutil[l,es,d,t]
  eP[l,es,d,t]
  #InputErrorf_sTSupply[l,es,d,t]
  #InputErrorf_cTutil[l,es,d,t]
  cTutil[l,es,d,t]
;

$ENDIF # calibration