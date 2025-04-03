# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1sTPotential[l,es,d,t] "Dummy determining the existence of technology potentials"
  d1pTE[es,e,d,t] "Dummy determining the existence of input price of energy in technologies for energy services"
  d1pTK[d,t] "Dummy determining the existence of user costs for technologies"
  d1uTE[l,es,e,d,t] "Dummy determining the existence of energy input in technology"
  d1qES_e[es,e,d,t] "Dummy determining the existence of energy use (sum across technologies)"
  d1qES[es,d,t] "Dummy determining the existence of energy service, quantity"
;

$Group+ all_variables
  # Exogenous variables
  pTK[d,t]$(d1pTK[d,t]) "User cost of capital in technologies for energy services"
  pTE_base[es,e,d,t]$(d1pTE[es,e,d,t]) "Base price of energy input, excl. taxes, billion EUR per PJ"
  pTE_tax[es,e,d,t]$(d1pTE[es,e,d,t]) "Tax on energy input, billion EUR per PJ"
  pTE[es,e,d,t]$(d1pTE[es,e,d,t]) "Input price of energy in technologies for energy services" 
  qES[es,d,t]$(d1qES[es,d,t]) "Energy service, quantity."
  
  sTPotential[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Potential supply by technology l in ratio of energy service (share of qES)"
  theta[l,es,d,t]$(d1sTPotential[l,es,d,t]) "jsk same sTPotential. only used adhoc for loading data"
  eP[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Parameter governing efficiency of costs of technology l (smoothing parameter)"
  
  uTE[l,es,e,d,t]$(d1uTE[l,es,e,d,t]) "Input of energy in technology l per PJ output at full potential"
  uTK[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Input of machinery capital in technology l per PJ output output at full potential"
    
  # Endogenous variables
  pTPotential[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Average price of technology l at full potential, ie. when sTSupply=sTPotential"

  sTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Supply by technology l in ratio of energy service (share of qES)"
  pESmarg[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Marginal price of energy services based on the supply by technologies"
  
  # Supplementary output
  vTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Value (or costs) of energy service supplied by technology l "

  vES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Value of energy service" 
  pES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Energy service, price."
   
  qES_e[es,e,d,t]$(d1qES_e[es,e,d,t]) "Quantity of energy in energy services"
  qES_k[d,t]$(d1pTK[d,t]) "Quantity of machinery capital in energy services"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK abatement_equations abatement_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 
  
## Input for the model

  # Price on energy input including taxes
  .. pTE[es,e,d,t] =E=  pTE_base[es,e,d,t] + pTE_tax[es,e,d,t]; 

## Core of the model

  # Average price of technology l at full potential, ie. when sTSupply=sTPotential
	.. pTPotential[l,es,d,t]	=E= sum(e, uTE[l,es,e,d,t]*pTE[es,e,d,t])
										+ uTK[l,es,d,t]*pTK[d,t];

  # Supply of tecnology l in ratio of energy demand qES
  .. sTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*@cdfLogNorm(pESmarg[es,d,t],pTPotential[l,es,d,t],eP[l,es,d,t]);
  
	# Shadow value identifying marginal technology for energy purpose
	pESmarg[es,d,t].. 1 =E= sum(l, sTSupply[l,es,d,t]);

## Supplementary output

  # Value (or costs) of energy service supplied by technology l
  .. vTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*@Int_cdfLogNorm(pESmarg[es,d,t],pTPotential[l,es,d,t],eP[l,es,d,t])*qES[es,d,t]*pTPotential[l,es,d,t];

  # Value of energy service
  .. vES[es,d,t] =E= sum(l,vTSupply[l,es,d,t]);

	# Price index for energy purposes
	.. pES[es,d,t] =E= vES[es,d,t] / qES[es,d,t] ;

  # Use of energy goods - Adjusted for price of supply being lower than at full potential
  .. qES_e[es,e,d,t] =E= sum(l$(d1sTPotential[l,es,d,t]), uTE[l,es,e,d,t]*vTSupply[l,es,d,t]/pTPotential[l,es,d,t] ) ;
  
  # Use of machinery capital for technologies - Adjusted for price of supply being lower than at full potential
  .. qES_k[d,t] =E= sum((l,es)$(d1sTPotential[l,es,d,t]), uTK[l,es,d,t]*vTSupply[l,es,d,t]/pTPotential[l,es,d,t] ) ;

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
  sTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  uTK[l,es,d,t]
  pTE_base[es,e,d,t]
  pTE_tax[es,e,d,t]
  pTK[d,t]
  qES[es,d,t]
;
@load(abatement_data_variables, "../data/Abatement_data/Abatement_dummy_data.gdx")
$GROUP+ data_covered_variables abatement_data_variables;

# ------------------------------------------------------------------------------
# Dummies and initial values
# ------------------------------------------------------------------------------

pTE.l[es,e,d,t] =  pTE_base.l[es,e,d,t] + pTE_tax.l[es,e,d,t];
pTPotential.l[l,es,d,t]	= sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])
										    + uTK.l[l,es,d,t]*pTK.l[d,t];

# Defining efficiency of costs of technology l (smoothing parameter)"
eP.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = 0.01;

# Set dummy determining the existence of technology potentials
d1sTPotential[l,es,d,t] = yes$(sTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1pTK[d,t] = yes$(sum((l,es), d1sTPotential[l,es,d,t]));
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));
d1pTE[es,e,d,t] = yes$(pTE.l[es,e,d,t]);
d1qES[es,d,t] = yes$(qES.l[es,d,t]);

# ------------------------------------------------------------------------------
# Depicting discrete and smooth supply curves
# ------------------------------------------------------------------------------
$import Supply_curves_abatement.gms
execute_unloaddi "abatement_data_load.gdx";
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
  # qES[es,d,t]
  pES[es,d,t]
  vES[es,d,t]
  
  # pTE[es,e,d,t]
  qES_e[es,e,d,t]

  pTPotential[l,es,d,t]

  # pTK[d,t]
  qES_k[d,t]

  sTSupply[l,es,d,t]
  vTSupply[l,es,d,t]

  # sTPotential[l,es,d,t]
  # uTE[l,es,e,d,t]
  # uTK[l,es,d,t]
  pESmarg[es,d,t]

  eP[l,es,d,t]
 ;

$ENDIF # calibration