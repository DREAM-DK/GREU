# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$SetGroup+ SG_flat_after_last_data_year
  d1sTPotential[l,es,d,t] "Dummy determining the existence of technology potentials"
  d1pT_e[es,e,d,t] "Dummy determining the existence of input price of energy in technologies for energy services"
  d1pT_k[d,t] "Dummy determining the existence of user costs for technologies"
  d1uTE[l,es,e,d,t] "Dummy determining the existence of energy input in technology"
  d1qES_e[es,e,d,t] "Dummy determining the existence of energy use (sum across technologies)"
  d1qES[es,d,t] "Dummy determining the existence of energy service, quantity"
;

$Group+ all_variables
  # Exogenous variables
  pT_k[d,t]$(d1pT_k[d,t]) "User cost of capital in technologies for energy services"
  pT_e[es,e,d,t]$(d1pT_e[es,e,d,t]) "Input price of energy in technologies for energy services" 
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
  qES_k[d,t]$(d1pT_k[d,t]) "Quantity of machinery capital in energy services"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK abatement_equations abatement_endogenous $(t1.val <= t.val and t.val <= tEnd.val) 

  # Exogenous variables
# ..  pT_e[es,e,d,t] =E=  pEpj[es,e,d,t] ; 

  # Endogenous variables

  # Average price of technology l at full potential, ie. when sTSupply=sTPotential
	.. pTPotential[l,es,d,t]	=E= sum(e, uTE[l,es,e,d,t]*pT_e[es,e,d,t])
										+ uTK[l,es,d,t]*pT_k[d,t];

  # Supply of tecnology l in ratio of energy demand qES
  .. sTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*@cdfLogNorm(pESmarg[es,d,t],pTPotential[l,es,d,t],eP[l,es,d,t]);
  
	# Shadow value identifying marginal technology for energy purpose
	pESmarg[es,d,t].. 1 =E= sum(l, sTSupply[l,es,d,t]);

# Supplementary output

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
#jsk  sTPotential[l,es,d,t]
  theta[l,es,d,t]
  uTE[l,es,e,d,t]
  uTK[l,es,d,t]
;
@load(abatement_data_variables, "../data/data.gdx")
$GROUP+ data_covered_variables abatement_data_variables;

#jsk
sTPotential.l[l,es,d,t] =  theta.l[l,es,d,t] ;

# ------------------------------------------------------------------------------
# Parameters for stress testing the model
# ------------------------------------------------------------------------------

# Take aways from the stress tests:
# 1. If combining stress_restrict_techs and stress_price_base_tech, the model will not solve.
# 2. If combining stress_reduced_potential_base_tech and stress_increase_price_backstop_tech, the model will not solve.
# 3. If stress_price_base_tech is = 1000, then the model will not solve.

$SETGLOBAL stress_restrict_techs 0
$SETGLOBAL stress_price_base_tech 0 # stress_price_base_tech2 must be equal to 0, if stress_price_base_tech is equal to 1
$SETGLOBAL stress_price_base_tech2 0 # stress_price_base_tech must be equal to 0, if stress_price_base_tech2 is equal to 1
$SETGLOBAL stress_reduced_potential_base_tech 0
$SETGLOBAL stress_increase_price_backstop_tech 0
$SETGLOBAL stress_decrease_price_backstop_tech 0
$SETGLOBAL stress_no_backstop_tech 0
$SETGLOBAL stress_increase_eP 0

# Stress test: Stort samlet potentiale og meget dyre teknologier i enden af udbudskurven
# Stress test: Lille forskel mellem marginale og næstbilligste, men så en stor forskel ift. den næst-næst billigste
# Stress test: Lavere priser

# ------------------------------------------------------------------------------
# Creating dummy data
# ------------------------------------------------------------------------------
$import calib_dummy_techs.gms

# Set dummy determining the existence of technology potentials
d1sTPotential[l,es,d,t] = yes$(sTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1pT_k[d,t] = yes$(sum((l,es), d1sTPotential[l,es,d,t]));
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));
d1pT_e[es,e,d,t] = yes$(pT_e.l[es,e,d,t]);
# d1pT_e[es,e,d,t] = yes$(d1pEpj_base[es,e,d,t] or d1tqEpj[es,e,d,t]);
d1qES[es,d,t] = yes$(qES.l[es,d,t]);
# d1qES[es,d,t] = yes$(sum(e, d1pEpj_base[es,e,d,t]) or $(sum(e, d1tqEpj[es,e,d,t])));

# Initial values
# pT_k.l[d,t]$(sum((l,es), d1sTPotential[l,es,d,t])) = 0.1;
# qES.l[es,d,t] = sum(e, qEpj.l[es,e,d,t]);

pESmarg.l[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) = 1;
eP.l[l,es,d,t]$(d1sTPotential[l,es,d,t]) = 0.05;

$IF1 %stress_increase_eP% = 1:
  eP.l[l,es,d,t]$(d1sTPotential[l,es,d,t]) = 0.5;
$ENDIF1

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
  
  pT_e[es,e,d,t]
  qES_e[es,e,d,t]

  pTPotential[l,es,d,t]

  pT_k[d,t]
  qES_k[d,t]

  sTSupply[l,es,d,t]
  vTSupply[l,es,d,t]
  # pTSupply[l,es,d,t]

  sTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  uTK[l,es,d,t]
  pESmarg[es,d,t]

  eP[l,es,d,t]
 ;

$ENDIF # calibration