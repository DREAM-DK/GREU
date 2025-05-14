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
  qES[es,d,t]$(d1qES[es,d,t]) "Energy service, quantity."
  
  sTPotential[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Potential supply by technology l in ratio of energy service (share of qES)"
  theta[l,es,d,t]$(d1sTPotential[l,es,d,t]) "jsk same sTPotential. only used adhoc for loading data"
  eP[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Parameter governing efficiency of costs of technology l (smoothing parameter)"
  
  uTE[l,es,e,d,t]$(d1uTE[l,es,e,d,t]) "Input of energy in technology l per PJ output at full potential"
  uTKexp[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Average input of machinery capital in technology l per PJ output at full potential"
    
  # Endogenous variables
  uTKexp[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Average input of machinery capital in technology l per PJ output at level of supply"
  uTKmargNoBound[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Input of machinery capital in technology l per PJ output at the margin of supply - Unrestricted"
  uTKmarg[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Input of machinery capital in technology l per PJ output at the margin of supply - Lower bounded"
  pTE[es,e,d,t]$(d1pTE[es,e,d,t]) "Input price of energy in technologies for energy services" 
  pTPotential[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Average price of technology l at full potential, ie. when sTSupply=sTPotential"
  pT[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Average price of technology l at level of supply"

  sTold[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Supply by technology l in ratio of energy service (share of qES)"
  sqT2qES[l,es,d,t]$(d1sTPotential[l,es,d,t])   "Supply by technology l in ratio of energy service (share of qES)"

  pESmarg[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Marginal price of energy services based on the supply by technologies"

  # Supplementary output
  vTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t]) "Value (or costs) of energy service supplied by technology l "

  vESold[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Value of energy service" 
  vES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Value of energy service" 
  pESold[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Energy service, price."
  pES[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) "Energy service, price."

  qES_e[es,e,d,t]$(d1qES_e[es,e,d,t]) "Quantity of energy in energy services"
  qES_k[d,t]$(d1pTK[d,t]) "Quantity of machinery capital in energy services"

  qESE[es,e,d,t]$(d1qES_e[es,e,d,t]) "Quantity of energy in energy services"
  qESK[es,d,t]$(d1pTK[d,t])             "Quantity of machinery capital in energy services"
;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK abatement_equations_core abatement_endogenous_core $(t1.val <= t.val and t.val <= tEnd.val) 
  
## Input for the model

  # Price on energy input including taxes
  .. pTE[es,e,d,t] =E=  pTE_base[es,e,d,t] + pTE_tax[es,e,d,t]; 

## Core of the model

#---------------------------JSK start---------------------------
  # Equality between marginal price of energy service and marginal price of technology determines capital intensity of technologies at the margin of supply
  uTKmargNoBound[l,es,d,t].. pESmarg[es,d,t] =E= sum(e, uTE[l,es,e,d,t]*pTE[es,e,d,t]$(d1pTE[es,e,d,t] and d1uTE[l,es,e,d,t]))	+ uTKmargNoBound[l,es,d,t]*pTK[d,t];

  #uTKmargNoBound[l,es,d,t].. pESmarg[es,d,t] =E= sum(e, uTE[l,es,e,d,t])	+ uTKmargNoBound[l,es,d,t];

  # A lower bound close to zero is set to avoid indeterminancy in cdfLognorm in sqTqES. uTKmargNoBoun<=0 happen when a technology is very energy intensive (ineffecient).
  #.. uTKmarg[l,es,d,t] =E= @max(0.001, uTKmargNoBound[l,es,d,t]  );
  .. uTKmarg[l,es,d,t] =E= @InInterval(0.001, uTKmargNoBound[l,es,d,t],uTKexp[l,es,d,t]*[1+5*eP[l,es,d,t]] );

  # Supply of tecnology l in ratio of energy service demand qES
 .. sqT2qES[l,es,d,t] =E= sTPotential[l,es,d,t]*@cdfLogNorm(uTKmarg[l,es,d,t],uTKexp[l,es,d,t],eP[l,es,d,t]);
 #.. sqT2qES[l,es,d,t] =E= sTPotential[l,es,d,t]*@cdfLogNorm(uTKmargNobound[l,es,d,t],uTKexp[l,es,d,t],eP[l,es,d,t]);

 #Average capital intensity at level of supply
 # .. uTK[l,es,d,t] =E= @CondExpLogNorm(uTKmarg[l,es,d,t],uTKexp[l,es,d,t],eP[l,es,d,t]) ;

 	# Shadow value identifying marginal technology for energy purpose
	pESmarg[es,d,t].. 1 =E= sum(l$(d1sTPotential[l,es,d,t]), sqT2qES[l,es,d,t]) ;
                
#---------------------------JSK end---------------------------

  # Average price of technology l at full potential, ie. when sTSupply=sTPotential
	# .. pTPotential[l,es,d,t]	=E= sum(e, uTE[l,es,e,d,t]*pTE[es,e,d,t])
	# 									+ uTKexp[l,es,d,t]*pTK[d,t];

  # Supply of tecnology l in ratio of energy demand qES
  # .. sTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*@cdfLogNorm(pESmarg[es,d,t],pTPotential[l,es,d,t],eP[l,es,d,t]);
  
	# Shadow value identifying marginal technology for energy purpose
	# pESmarg[es,d,t].. 1 =E= sum(l, sTSupply[l,es,d,t]);

$ENDBLOCK

$BLOCK abatement_equations_output abatement_endogenous_output $(t1.val <= t.val and t.val <= tEnd.val) 
## Supplementary output
#---------------------------JSK start---------------------------
  # Use of energy in production of energy service
  .. qESE[es,e,d,t] =E= qES[es,d,t] * sum(l$(d1sTPotential[l,es,d,t]), sqT2qES[l,es,d,t] * uTE[l,es,e,d,t] ) ;
    
  # Use of machinery capital for technologies - Adjusted for price of supply being lower than at full potential
  .. qESK[es,d,t] =E= sum(l$(d1sTPotential[l,es,d,t]),sTPotential[l,es,d,t]*@PartExpLogNorm(uTKmarg[l,es,d,t],uTKexp[l,es,d,t],eP[l,es,d,t]) ) ;
                    # The line above may seem unintuitive. It is equivalent to below, but which 
                    # may result in division by zero error. This is also why uTK is only calculated in the reporting
                    # sum(l$(d1sTPotential[l,es,d,t]),sqT2qES[l,es,d,t]*uTK[l,es,d,t]);
                   
                 
                    
.. vES[es,d,t] =E=    sum(e,qESE[es,e,d,t]*pTE[es,e,d,t]) + qESK[es,d,t]*pTK[d,t]  ;

 .. pES[es,d,t] =E=    vES[es,d,t] / qES[es,d,t] ;   
#---------------------------JSK end---------------------------

  # Value (or costs) of energy service supplied by technology l
  # .. vTSupply[l,es,d,t] =E= sTPotential[l,es,d,t]*@Int_cdfLogNorm(pESmarg[es,d,t],pTPotential[l,es,d,t],eP[l,es,d,t])*qES[es,d,t]*pTPotential[l,es,d,t];

  # Value of energy service
  # .. vES[es,d,t] =E= sum(l,vTSupply[l,es,d,t]);

	# # Price index for energy purposes
	# .. pES[es,d,t] =E= vES[es,d,t] / qES[es,d,t] ;

  # Use of energy goods - Adjusted for price of supply being lower than at full potential
  # .. qES_e[es,e,d,t] =E= sum(l$(d1sTPotential[l,es,d,t]), uTE[l,es,e,d,t]*vTSupply[l,es,d,t]/pTPotential[l,es,d,t] ) ;
  
  # # Use of machinery capital for technologies - Adjusted for price of supply being lower than at full potential
  # .. qES_k[d,t] =E= sum((l,es)$(d1sTPotential[l,es,d,t]), uTKexp[l,es,d,t]*vTSupply[l,es,d,t]/pTPotential[l,es,d,t] ) ;

$ENDBLOCK

$GROUP abatement_endogenous
        abatement_endogenous_core
        abatement_endogenous_output
;

$MODEL abatement_equations  
        abatement_equations_core
        abatement_equations_output 
;

# Add equation and endogenous variables to main model
model main / abatement_equations /;
$GROUP+ main_endogenous abatement_endogenous;

#To help the solver this function add bounds to variables in the abatement module if they are ulready unfixed
$FUNCTION Setbounds_abatement():
  uTKmarg.lo[l,es,d,t]$(sTPotential.l[l,es,d,t] and uTKmarg.lo[l,es,d,t] ne uTKmarg.up[l,es,d,t]) = 0.001*0.99;
  uTKmarg.up[l,es,d,t]$(sTPotential.l[l,es,d,t] and uTKmarg.lo[l,es,d,t] ne uTKmarg.up[l,es,d,t]) = uTKexp.l[l,es,d,t]*[1+5*eP.l[l,es,d,t]]*1.01 ;
  sqT2qES.lo[l,es,d,t]$(sTPotential.l[l,es,d,t] and sqT2qES.lo[l,es,d,t] ne sqT2qES.up[l,es,d,t]) = 0.00000000001;
  sqT2qES.up[l,es,d,t]$(sTPotential.l[l,es,d,t] and sqT2qES.lo[l,es,d,t] ne sqT2qES.up[l,es,d,t]) = sTPotential.l[l,es,d,t] ;
  pESmarg.lo[es,d,t]$(sum(l,sTPotential.l[l,es,d,t]) and pESmarg.lo[es,d,t] ne pESmarg.up[es,d,t]) = 0.001;
$ENDFUNCTION


$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

$GROUP abatement_data_variables
  sTPotential[l,es,d,t]
  uTE[l,es,e,d,t]
  uTKexp[l,es,d,t]
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

uTKexp.l[l,es,d,t] = uTKexp.l[l,es,d,t] * 100;
uTKexp.l['t1',es,d,t] = uTKexp.l['t1',es,d,t] * 10;

pTE.l[es,e,d,t] =  pTE_base.l[es,e,d,t] + pTE_tax.l[es,e,d,t];
pTPotential.l[l,es,d,t]	= sum(e, uTE.l[l,es,e,d,t]*pTE.l[es,e,d,t])
										    + uTKexp.l[l,es,d,t]*pTK.l[d,t];

# Defining efficiency of costs of technology l (smoothing parameter)"
eP.l[l,es,d,t]$(sTPotential.l[l,es,d,t]) = 0.03;

# Set dummy determining the existence of technology potentials
d1sTPotential[l,es,d,t] = yes$(sTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1pTK[d,t] = yes$(sum((l,es), d1sTPotential[l,es,d,t]));
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));
d1pTE[es,e,d,t] = yes$(pTE.l[es,e,d,t]);
d1qES[es,d,t] = yes$(qES.l[es,d,t]);

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
  pESold[es,d,t]
  vES[es,d,t]
  
  # pTE[es,e,d,t]
  qES_e[es,e,d,t]

  pTPotential[l,es,d,t]

  # pTK[d,t]
  qES_k[d,t]

  sTold[l,es,d,t]
  vTSupply[l,es,d,t]

  # sTPotential[l,es,d,t]
  # uTE[l,es,e,d,t]
  # uTKexp[l,es,d,t]
  uTKmarg[l,es,d,t]
  pESmarg[es,d,t]

  sqT2qES[l,es,d,t]

  eP[l,es,d,t]
 ;

$ENDIF # calibration