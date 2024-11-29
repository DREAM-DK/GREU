# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

  $SetGroup+ SG_flat_after_last_data_year
    d1Prod[pf,i,t] "Dummy for production function"
  ;	

  $Group+ all_variables
    pProd[pf,i,t]$(d1Prod[pf,i,t]) "Production price index, both nests and factors"
    pY0_i[i,t]$(d1Y_i[i,t]) "Cost price index, net of installation costs and other costs not in CES-nesting tree"

    qProd[pf,i,t]$(d1Prod[pf,i,t]) "Production quantity, both nests and factors"

    vtBotded[i,t]$(d1Y_i[i,t]) "Value of bottom-up deductions, bio kroner"
    vProdOtherProductionCosts[i,t]$(d1Y_i[i,t]) "Other production costs not in CES-nesting tree, bio. kroner"
    vtNetproductionRest[i,t]$(d1Y_i[i,t]) "Net production subsidies and taxes not internalized in user-cost of capital and not included in other items listed below, bio. kroner"
    vDiffMarginAvgE[i,t]$(d1Y_i[i,t]) "Difference between marginal and average energy-costs, bio. kroner"
    vtEmmRxE[i,t]$(d1Y_i[i,t]) "Taxes on non-energy related emissions, bio. kroner"
    vtCAP_prodsubsidy[i,t]$(d1Y_i[i,t]) "Agricultural subsidies from EU CAP subsidizing production directly, bio. kroner"

    uProd[pf,i,t]$(d1Prod[pf,i,t]) "CES-Share of production for nest or factor (pf)"
    eProd[pFnest,i] "Elasticity of substitution between production nests"

    pProd2pNest[pf,pfNest,i,t]$(d1Prod[pf,i,t] and d1Prod[pfNest,i,t]) "Price ratio between production factor and its nest."

    qPFtop2qY[i] "Ratio between qProd[pf_top] and qY_i in basis year where prices are set to 1."
  ;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

  $BLOCK production_equations production_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    # Output is determined in the input-output system, to meet the demand at the prevailing price levels.
    # Given the level of production, we determine the most cost-effective way to produce it in this module.
    .. qProd[pf_top,i,t] =E= qPFtop2qY[i] * qY_i[i,t];

    # Marginal cost. These are marginal cost of production from CES-production (pProd['TopPfunction']), net of any adjustment costs, and other costs not covered in the production function
    .. pY0_i[i,t] * qY_i[i,t] =E= pProd['TopPfunction',i,t] * qProd['TopPfunction',i,t]
                                + vProdOtherProductionCosts[i,t];

    .. pProd2pNest[pf,pfNest,i,t] =E= pProd[pf,i,t] / pProd[pfNest,i,t];

    #CES-nests in production function
    qProd[pf,i,t]$(not pf_top[pf])..
      qProd[pf,i,t] =E= uProd[pf,i,t]
                      * sum(pf_mapping[pfNest,pf,i],
                          pProd2pNest[pf,pfNest,i,t]**(-eProd[pfNest,i]) * qProd[pfNest,i,t]
                      );

    .. pProd[pfNest,i,t] * qProd[pfNest,i,t] =E= sum(pf_mapping[pfNest,pf,i], pProd[pf,i,t] * qProd[pf,i,t]);

    # # Other production costs, not in nesting tree 
    # .. vProdOtherProductionCosts[i,t] =E= vtNetproductionRest[i,t]      #Net production subsidies and taxes not internalized in user-cost of capital and not included in other items listed below
    #                                     - vtBotded[i,t]                 #"Bottom deductions on energy-use"
    #                                     - vDiffMarginAvgE[i,t]          #"Difference between marginal and average energy-costs"
    #                                     + vtEmmRxE[i,t]                 #Taxes on non-energy related emissions
    #                                     - vtCAP_prodsubsidy[i,t]        #Agricultural subsidies from EU CAP subsidizing production directly.
    #                                     + vEnergycostsnotinnesting[i,t] #Energy costs not in nesting tree
    #                                     ;
  $ENDBLOCK

  $BLOCK production_bottom_link_equations production_bottom_link_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    .. pProd[RxE,i,t] =E= pD[i,t];
    qR2qY_i[i,t].. qD[i,t] =E= qProd['RxE',i,t];

    .. pProd[pf_bottom_capital,i,t] =E= sum(sameas[pf_bottom_capital,k], pK_k_i[k,i,t] / pK_k_i[k,i,tBase]); # We set the price to 1 in the base year, and adjust the quantity inversely
    qK2qY_k_i[k,i,t].. qK_k_i[k,i,t] =E= sum(sameas[pf_bottom_capital,k], qProd[pf_bottom_capital,i,t]) * pK_k_i[k,i,tBase];

    .. pProd[pf_bottom_e,i,t] =E= pE_i[i,t]; 
    qE2qY_i[i,t].. qE_i[i,t] =E= sum(pf_bottom_e, qProd[pf_bottom_e,i,t]);
    # .. pProd[machine_energy,i,t] =E= pREmachine[i,t]; 
    # .. pProd[heating_energy,i,t] =E= pREes['heating',i,t];
    # .. pProd[transport_energy,i,t] =E= pREes['transport',i,t];

    .. pProd[labor,i,t] =E= pL_i[i,t];
    qL2qY_i[i,t].. qL_i[i,t] =E= qProd['labor',i,t];
  $ENDBLOCK

  # Add equation and endogenous variables to main model
  model main /
    production_equations
    production_bottom_link_equations
  /;
  $Group+ main_endogenous 
    production_endogenous
    production_bottom_link_endogenous
  ;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":
  # ------------------------------------------------------------------------------
  # Data 
  # ------------------------------------------------------------------------------
  $Group G_production_data_variables 
    pProd
    qProd
    vtNetproductionRest
    vtCAP_prodsubsidy
  ;

  @inf_growth_adjust()
  @load(G_production_data_variables, "../data/data.gdx")
  @remove_inf_growth_adjustment()
  $Group+ data_covered_variables G_production_data_variables$(t.val <= %calibration_year%), -qProd;

  # ------------------------------------------------------------------------------
  # Exogenous variables 
  # ------------------------------------------------------------------------------
  eProd.l[pFnest,i]$(not pf_top[pFnest]) = 0.1;

  # ------------------------------------------------------------------------------
  # Initial values  
  # ------------------------------------------------------------------------------
  pProd.l[pfNest,i,tDataEnd] = 1;

  qProd.l[pfNest,i,t] =  sum(pf_bottom$(pf_mapping[pfNest,pf_bottom,i]), pProd.l[pf_bottom,i,t]*qProd.l[pf_bottom,i,t]);
  qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);
  qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);
  qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);
  qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);

  qY_i.l[i,t] = qProd.l['TopPfunction',i,t];

  vtBotded.l[i,tDataEnd] = 0.05;

  # ------------------------------------------------------------------------------
  # Dummies 
  # ------------------------------------------------------------------------------
    d1Prod[pf,i,t] = yes$(qProd.l[pf,i,t]);
$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

# Add equations and calibration equations to calibration model
model calibration /
  production_equations
  production_bottom_link_equations
/;

  # Add endogenous variables to calibration model
  $Group calibration_endogenous
    production_endogenous
    production_bottom_link_endogenous

    -qR2qY_i[i,t1], uProd[RxE,i,t1]
    -qK2qY_k_i[k,i,t1], uProd[pf_bottom,i,t1]
    -qProd[pf_bottom_e,i,t1], uProd[pf_bottom_e,i,t1]
    -qE2qY_i[i,t1], qProd[heating_energy,i,t1]$(d1Prod[heating_energy,i,t1]), qProd[machine_energy,i,t1]$(not d1Prod['heating_energy',i,t1])

    -qL2qY_i[i,t1], uProd[labor,i,t1]
    # -qProd[pf_bottom,i,t1], uProd[pf_bottom,i,t1]
    -pProd[pfNest,i,t1]$(not pf_top[pfNest]), uProd[pfNest,i,t1]$(not pf_top[pfNest])

    qPFtop2qY[i], -pProd[pf_top,i,tBase]

    calibration_endogenous
  ;

  $Group G_flat_after_last_data_year
    uProd[pf,i,t]
  ;

$ENDIF # calibration