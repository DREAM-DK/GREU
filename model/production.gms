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
    qY0_i[i,t]$(d1Y_i[i,t]) "Cost price index, net of installation costs and other costs not in CES-nesting tree"

    qProd[pf,i,t]$(d1Prod[pf,i,t]) "Production quantity, both nests and factors"

    vtBotded[i,t]$(d1Y_i[i,t]) "Value of bottom-up deductions, bio kroner"
    vProdOtherProductionCosts[i,t]$(d1Y_i[i,t]) "Other production costs not in CES-nesting tree, bio. kroner"
    vDiffMarginAvgE[i,t]$(d1Y_i[i,t]) "Difference between marginal and average energy-costs, bio. kroner"
    vtEmmRxE[i,t]$(d1Y_i[i,t]) "Taxes on non-energy related emissions, bio. kroner"

    uProd[pf,i,t]$(d1Prod[pf,i,t]) "CES-Share of production for nest or factor (pf)"
    eProd[pFnest,i] "Elasticity of substitution between production nests"

    pProd2pNest[pf,pfNest,i,t]$(d1Prod[pf,i,t] and d1Prod[pfNest,i,t]) "Price ratio between production factor and its nest."

    qPFtop2qY[i,t] "Ratio between qProd[pf_top] and qY_i in basis year where prices are set to 1."

    jqE_re_i[re,i,t]$(d1E_re_i[re,i,t]) "J-term to be endogenized when energy module is turned on. Necessary, because bottom-up energy is partly in the top and partly in CES-nests"
    jpProd[pf,i,t]$(d1Prod[pf,i,t]) "J-term to be endogenized when energy module is turned on"

    vGVA_i[i,t] "Approximation of gross value added on industry level"
  ;
 
$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

  $BLOCK production_equations production_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    # Output is determined in the input-output system, to meet the demand at the prevailing price levels.
    # Given the level of production, we determine the most cost-effective way to produce it in this module.
    .. qY0_i[i,t] =E= qPFtop2qY[i,t] * qY_i[i,t];


    ..qProd[pf_top,i,t] =E= qY0_i[i,t]; #This is just a 1:1 further, further down the line qProd will have installation costs substracted 

    # Marginal cost. These are marginal cost of production from CES-production (pProd['TopPfunction']), net of any adjustment costs, and other costs not covered in the production function
    .. pY0_i[i,t] * qY0_i[i,t] =E= pProd['TopPfunction',i,t] * qProd['TopPfunction',i,t]
                                + vProdOtherProductionCosts[i,t];

    pProd2pNest[pf,pfNest,i,t]$(pf_mapping[pfNest,pf,i])..
      pProd2pNest[pf,pfNest,i,t] =E= pProd[pf,i,t] / pProd[pfNest,i,t];

    #CES-nests in production function
    qProd[pf,i,t]$(not pf_top[pf])..
      qProd[pf,i,t] =E= uProd[pf,i,t]
                      * sum(pf_mapping[pfNest,pf,i],
                          pProd2pNest[pf,pfNest,i,t]**(-eProd[pfNest,i]) * qProd[pfNest,i,t]
                      );

        .. pProd[pfNest,i,t] * qProd[pfNest,i,t] =E= sum(pf_mapping[pfNest,pf,i], pProd[pf,i,t] * qProd[pf,i,t]);

    # # Other production costs, not in nesting tree 
    .. vProdOtherProductionCosts[i,t] =E= 
                                            vtY_i_NetTaxSub[i,t]           #Net production taxes and subsidies, excluding ETS free allowances
                                           -vtBotded[i,t]                   #"Bottom deductions on energy-use"
                                          + vEnergycostsnotinnesting[i,t]   #Energy costs not in nesting tree
                                          - vNetGov2Corp_xIO[i,t]
                                          ;

    .. vGVA_i[i,t] =E= sum(pf_top, pProd[pf_top,i,t]*qProd[pf_top,i,t]) - pProd['RxE',i,t]*qProd['RxE',i,t]
                      -sum(pf_bottom_e, pProd[pf_bottom_e,i,t]*qProd[pf_bottom_e,i,t]);        

  $ENDBLOCK

  $BLOCK production_bottom_link_equations production_bottom_link_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    .. pProd[RxE,i,t] =E= pD[i,t] + jpProd[Rxe,i,t];
    qR2qY_i[i,t].. qD[i,t] =E= qProd['RxE',i,t];

    .. pProd[pf_bottom_capital,i,t] =E= sum(sameas[pf_bottom_capital,k], pK_k_i[k,i,t] / pK_k_i[k,i,tBase]); # We set the price to 1 in the base year, and adjust the quantity inversely
    qK2qY_k_i[k,i,t].. sum(sameas[pf_bottom_capital,k], qProd[pf_bottom_capital,i,t]) =E= qK_k_i[k,i,t] * pK_k_i[k,i,tBase];

    #When energy is turned on the IO/factor-demand variables pE_re_i and qE_re_i =/= pProd[pf_bottom_e] and qProd[pf_bottom_e].
    #This is due to a) Not all energy being handled in CES-nest (some of the energy is Leontief in top of p-function), 
    #               b) The energy-prices in pProd, qProd are based on marginal tax-rates (i.e. before deductions).
    #               c) When abatement is turned on pProd and qProd are further also comprised of abatement costs, which are the full abatement cost including technology and materials for a given technology
    #To handle this a couple of J-terms are introduced. jpProd ensures that pProd[pf_bottom_e] is equal to the marginal price of energy (i.e. with marginal tax-rate applying and including abatement costs)
    #jqE_re_i ensures that the input_output system is balanced in values. jqE_re_i is computed so that total energy-costs, pE_re_i * qE_re_i matches bottom-up computation of total energy-costs (see energy_markerkets.gms for link)
    #AKB, to be investigated: Maybe qE_re_i, computed as a residual, become meaningless as a "quantity". 
    .. pProd[pf_bottom_e,i,t] =E= sum(pf_bottom_e2re[pf_bottom_e,re], pE_re_i[re,i,t]) + jpProd[pf_bottom_e,i,t];    
    
    qE2qY_re_i[re,i,t]..  
      qE_re_i[re,i,t] =E= sum(pf_bottom_e2re[pf_bottom_e,re], qProd[pf_bottom_e,i,t]) + jqE_re_i[re,i,t]; 

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
  ;

  @inf_growth_adjust()
  @load(G_production_data_variables, "../data/data.gdx")
  @remove_inf_growth_adjustment()
  $Group+ data_covered_variables G_production_data_variables$(t.val <= %calibration_year%), -qProd;

  # ------------------------------------------------------------------------------
  # Exogenous variables 
  # ------------------------------------------------------------------------------

  eProd.l[pfNest,i] = 0.7;

  # ------------------------------------------------------------------------------
  # Initial values  
  # ------------------------------------------------------------------------------

  pProd.l[pfNest,i,tDataEnd] = 1;
  pY0_i.l[i,tDataEnd] = 1;

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

$BLOCK production_calibration_equations production_calibration_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
  # jpK_k_i[k,i,t]$(t1[t] and not tEnd[t]).. qK_k_i[k,i,t] =E= qK_k_i[k,i,t+1];

$ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  production_equations
  production_bottom_link_equations
  # production_calibration_equations
/;

# Add endogenous variables to calibration model
$Group calibration_endogenous
  production_endogenous
  production_bottom_link_endogenous
  production_calibration_endogenous

  #Endo/exo in the partial model
  uProd[pf_bottom,i,t1], -qProd[pf_bottom,i,t1]
  uProd[pfNest,i,t1]$(not pf_top[pfNest]), -pProd[pfNest,i,t1]$(not pf_top[pfNest])
  qPFtop2qY[i,tBase], -pProd[pf_top,i,tBase] #Normalize price at 1
  

  #Items are swapped back, the module is calibrated alongside factor_demand
  qProd[RxE,i,t1]
  qProd[pf_bottom_capital,i,t1]
  # qProd[pf_bottom_e,i,t1]
  jqE_re_i[re,i,t1] #£Temp, erstatter opvenstående 
  qProd[labor,i,t1]

  # -qR2qY_i[i,t1], uProd[RxE,i,t1]
  # -qK2qY_k_i[k,i,t1], uProd[pf_bottom,i,t1]
  # -qProd[pf_bottom_e,i,t1], uProd[pf_bottom_e,i,t1]

  # -qL2qY_i[i,t1], uProd[labor,i,t1]
  # -pProd[pfNest,i,t1]$(not pf_top[pfNest]), uProd[pfNest,i,t1]$(not pf_top[pfNest])


  calibration_endogenous
;

$Group+ G_flat_after_last_data_year
  uProd
  qPFtop2qY
;

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
  # $onDotL
  # parameter test_production_function[pf,i,t];
  # test_production_function[pfNest,i,t]$(qProd[pfNest,i,t] <> 0)
  #   = sum(pf_mapping[pfNest,pf,i],
  #       uProd[pf,i,t]**(1/eProd[pfNest,i]) * qProd[pf,i,t]**(1-1/eProd[pfNest,i])
  #     )**(1/(1-1/eProd[pfNest,i]))
  #   - qProd[pfNest,i,t];
  # test_production_function[pfNest,i,t]$(abs(test_production_function[pfNest,i,t]) < 1e-6) = 0;
  # ABORT$(sum([pfNest,i,t], abs(test_production_function[pfNest,i,t]))) "qProd does not match production function.", test_production_function;
  # $offDotL
$ENDIF # tests