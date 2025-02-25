# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1sTPotential[l,es,d,t] "Dummy determining the existence of technology potentials"
  d1pK_abatement[d,t] "Dummy determining the existence of user costs for technologies"
  d1uTE[l,es,e,d,t] "Dummy determining the existence of energy input in technology"
  d1qES_e[es,e,d,t] "Dummy determining the existence of energy use (sum across technologies)"
;

$Group+ all_variables
  # Exogenous variables
  pK_abatement[d,t]$(d1pK_abatement[d,t]) "User cost on capital. Should probably distinguish between investment types."
  pEpj[es,e,d,t]$(d1pEpj_base[es,e,d,t] or d1tqEpj[es,e,d,t]) "Price of energy in energy services" 
  qES[es,d,t]$(sum(e, d1pEpj_base[es,e,d,t]) or $(sum(e, d1tqEpj[es,e,d,t]))) "Energy service, quantity."
  
  sTPotential[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Potential supply by technology l in ratio of energy service (share of qES)"
  theta[l,es,d,t]$(d1sTPotential[l,es,d,t]) "jsk same sTPotential. only used adhoc for loading data"
  eP[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Parameter governing efficiency of costs of technology l (smoothing parameter)"
  
  uTE[l,es,e,d,t]$(d1uTE[l,es,e,d,t]) "Input of energy in technology l per PJ output at full potential"
  uTK[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Input of machinery capital in technology l per PJ output output at full potential"
    
  # Endogenous variables
  pT[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Average price of technology l at full potential, ie. when sTSupply=sTPotential"

  sTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Supply by technology l in ratio of energy service (share of qES)"
  vTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Value (or costs) of energy service supplied by technology l "
  pESmarg[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Marginal price of energy services based on the supply by technologies l"
  
  # Supplementary output
  pTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Average price of energy service supplied by technology l."

  vES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Value of energy service" 
  pES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Energy service, price."
   
  qES_e[es,e,d,t]$(d1qES_e[es,e,d,t]) "Quantity of energy in energy services"
  qES_k[d,t]$(d1pK_abatement[d,t]) "Quantity of machinery capital in energy services"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK abatement_equations abatement_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 
# and included_industries[d] and included_service[es])

  # Average price of technology l at full potential, ie. when sTSupply=sTPotential
	.. pT[l,es,d,t]	=E= sum(e, uTE[l,es,e,d,t]*pEpj[es,e,d,t])
										+ uTK[l,es,d,t]*pK_abatement[d,t];

  # Supply of tecnology l in ratio of energy demand qES
  	.. sTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*errorf(
                                                            (
                                                            log( ( (pESmarg[es,d,t]/pT[l,es,d,t])**2 )**0.5)
                                                            + 0.5*eP[l,es,d,t]**2
                                                            )/eP[l,es,d,t]
                                                            );
  

	
# Value (or costs) of energy service supplied by technology l
.. vTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*errorf(
                                                            (
                                                            log( ( (pESmarg[es,d,t]/pT[l,es,d,t])**2 )**0.5)
                                                            - 0.5*eP[l,es,d,t]**2   
                                                            )/eP[l,es,d,t]
                                                        )
                          *qES[es,d,t]*pT[l,es,d,t];


	# Shadow value identifying marginal technology for energy purpose
	pESmarg[es,d,t].. 1 =E= sum(l, sTSupply[l,es,d,t]);

# Supplementary output

# Average price of energy service supplied by technology l. Dead end variable. Can be moved to reporting if issues with division by zero occurs.
  .. pTSupply[l,es,d,t] =E= vTSupply[l,es,d,t] / ( sTSupply[l,es,d,t] * qES[es,d,t] ) ;

  # Value of energy service
  .. vES[es,d,t] =E= sum(l,vTSupply[l,es,d,t]);

	# Price index for energy purposes
	.. pES[es,d,t] =E= vES[es,d,t] / qES[es,d,t] ;

    # Use of energy goods - Adjusted for price of supply being lower than at full potential
  .. qES_e[es,e,d,t] =E= sum(l$(d1sTPotential[l,es,d,t]), uTE[l,es,e,d,t]*vTSupply[l,es,d,t]/pT[l,es,d,t] ) ;
  
   # Use of machinery capital for technologies - Adjusted for price of supply being lower than at full potential
  .. qES_k[d,t] =E= sum((l,es)$(d1sTPotential[l,es,d,t]), uTK[l,es,d,t]*vTSupply[l,es,d,t]/pT[l,es,d,t] ) ;

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

# Set dummy determining the existence of technology potentials
d1sTPotential[l,es,d,t] = yes$(sTPotential.l[l,es,d,t] and included_industries[d] and included_service[es]);

#Load additional electrification technologies that are not present in data (backstop technologies)
$import calib_electrification_techs.gms

d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t] and included_industries[d] and included_service[es]);
d1pK_abatement[d,t] = yes$(sum((l,es), d1sTPotential[l,es,d,t]));
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));

# Initial values
pK_abatement.l[d,t]$(sum((l,es), d1sTPotential[l,es,d,t])) = 0.1;
qES.l[es,d,t] = sum(e, qEpj.l[es,e,d,t]);

pESmarg.l[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) = 1;
eP.l[l,es,d,t]$(d1sTPotential[l,es,d,t]) = 0.5;




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
  qES_e[es,e,d,t]

  pT[l,es,d,t]

  pK_abatement[d,t]
  qES_k[d,t]

  sTSupply[l,es,d,t]
  vTSupply[l,es,d,t]
  pTSupply[l,es,d,t]

  sTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  uTK[l,es,d,t]
  pESmarg[es,d,t]

  eP[l,es,d,t]
 ;

$ENDIF # calibration