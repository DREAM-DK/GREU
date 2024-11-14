# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------
	
$PGROUP PG_production_dummies
  d1Prod[pf,i,t] "Dummy for production function"
  d1Y[i,t] "Dummy for production function"
  d1pProd_uc_tEnd
;	

$PGROUP PG_production_dummies_flat_dummies 
  PG_production_dummies 
;
$GROUP G_production_prices 
  pProd[pf,i,t]$(d1Prod[pf,i,t]) "Production price, both nests and factors"
  pY0_CET[out,i,t]$(d1pY_CET[out,i,t]) "Cost price of production in CET-split"
  pY0[i,t]$(d1Y[i,t]) "Cost price of production net of installation costs"
;

$GROUP G_production_quantities 
  qProd[pf,i,t]$(d1Prod[pf,i,t]) "Production quantity, both nests and factors"
  qY[i,t]$(d1Y[i,t])             "Production quantity net of installation costs"
;

$GROUP G_production_values
  vtBotded[i,t]$(d1Y[i,t]) "Value of bottom-up deductions"
  vProdOtherProductionCosts[i,t]$(d1Y[i,t]) "Other production costs not in CES-nesting tree"
  vtNetproductionRest[i,t]$(d1Y[i,t])       "Net production subsidies and taxes not internalized in user-cost of capital and not included in other items listed below"
  vDiffMarginAvgE[i,t]$(d1Y[i,t])           "Difference between marginal and average energy-costs"
  vtEmmRxE[i,t]$(d1Y[i,t])                  "Taxes on non-energy related emissions"
  vtCAP_prodsubsidy[i,t]$(d1Y[i,t])         "Agricultural subsidies from EU CAP subsidizing production directly"
;

$GROUP G_production_other 
  uProd[pf,i,t]$(d1Prod[pf,i,t])      "Share of production nest in production"
  eProd[pFnest,i]                     "Elasticity of substitution between production nests"
  markup[out,i,t]$(d1pY_CET[out,i,t]) "Markup on production"
  uY_CET[out,i,t]$(d1pY_CET[out,i,t]) "Share of production in CET-split"
  eCET[i]                             "Elasticity of substitution in CET-split"
  markup_calib[i,t]$(d1Y[i,t])        "Markup on production, used in calibration"
  rFirms[i,t]$(d1Y[i,t])              "Firms' discount rate, nominal"
  delta[pf,i,t]$(d1Prod[pf,i,t] and pf_bottom_capital[pf]) "Depreciation rate of capital"
  jpProd[pf,i,t]$(d1Prod[pf,i,t])     "j-T"
;

$GROUP G_production_flat_after_last_data_year 
  G_production_prices
  G_production_quantities
  G_production_values
  G_production_other, -jpProd
  # pProd 
  # qProd 
  # uProd 

  # uY_CET
  # pY0_CET
  # qY 
  # markup 
  # vtBotded
;

$GROUP G_production_data_variables
  pProd
  qProd
  vtNetproductionRest
  vtCAP_prodsubsidy
;

# ------------------------------------------------------------------------------
# Add to main groups
# ------------------------------------------------------------------------------

$GROUP+ price_variables 
  G_production_prices
;
$GROUP+ quantity_variables
  G_production_quantities
;
$GROUP+ value_variables
  G_production_values
;
$GROUP+ other_variables
  G_production_other
;

$GROUP+ data_covered_variables 
  G_production_data_variables
;

$PGROUP+ PG_flat_after_last_data_year 
  PG_production_dummies_flat_dummies 
;

$GROUP+ G_flat_after_last_data_year 
  G_production_flat_after_last_data_year
;

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
  $BLOCK production production_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

    pY_CET[out,i,t]$(d1pY_CET[out,i,t]).. 
      pY_CET[out,i,t] =E= pY0_CET[out,i,t] * (1 + markup[out,i,t]);

    pY0_CET[out,i,t]$(d1pY_CET[out,i,t]).. 
      qY_CET[out,i,t] =E= uY_CET[out,i,t] * (pY0_CET[out,i,t]/pY0[i,t])**eCET[i] *qY[i,t];  

    qY[i,t]$(d1Y[i,t]).. 
      pY0[i,t] * qY[i,t] =E= sum(out$d1pY_CET[out,i,t], pY0_CET[out,i,t] * qY_CET[out,i,t]); 


    #Computing marginal costs. These are marginal cost of production from CES-production (pProd['KETELBER']), net of installation costs, and other costs not covered in the production function
    pY0[i,t]$(d1Y[i,t]).. 
      pY0[i,t] * qY[i,t] =E=  pProd['TopPfunction',i,t] * qProd['TopPfunction',i,t] 
                            + vProdOtherProductionCosts[i,t];  #- qKinstcost[i,t])
                          

    qProd&_top[pf,i,t]$(d1Prod[pf,i,t] and pf_top[pf]).. 
      qProd[pf,i,t] =E= qY[i,t];  #+ qKinstcost[i,t];

    #CES-nests in production function
    qProd[pf,i,t]$(d1Prod[pf,i,t] and not pf_top[pf])..
      qProd[pf,i,t] =E= uProd[pf,i,t] * sum(pfNest$(pf_mapping[pfNest,pf,i]), (pProd[pfNest,i,t]/pProd[pf,i,t])**(-eProd[pfNest,i])*qProd[pFnest,i,t]);  

    pProd&_nest[pfNest,i,t]$(d1Prod[pfNest,i,t])..
      pProd[pfNest,i,t] * qProd[pfNest,i,t] =E= sum(pf$(pf_mapping[pfNest,pf,i]), pProd[pf,i,t]*qProd[pf,i,t]);

    #Computing other production costs, not in nesting tree 

    vProdOtherProductionCosts[i,t]$(d1Y[i,t]).. 
      vProdOtherProductionCosts[i,t] =E= vtNetproductionRest[i,t] #Net production subsidies and taxes not internalized in user-cost of capital and not included in other items listed below
                                       - vtBotded[i,t]            #"Bottom deductions on energy-use"
                                       - vDiffMarginAvgE[i,t]     #"Difference between marginal and average energy-costs"
                                       + vtEmmRxE[i,t]            #Taxes on non-energy related emissions
                                       - vtCAP_prodsubsidy[i,t]   #Agricultural subsidies from EU CAP subsidizing production directly.
                                       ;

  $ENDBLOCK

  $BLOCK production_usercost production_usercost_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    pProd[pf,i,t]$(t1.val <= t.val and t.val<tEnd.val and d1Prod[pf,i,t] and pf_bottom_capital[pf]).. 
      # pProd[pf,i,t] =E= (1+rFirms[i,t+1]) - (1-delta[pf,i,t])*fv + jpProd[pf,i,t];
      pProd[pf,i,t] =E= 1  - (1-delta[pf,i,t])/(1+rFirms[i,t+1])*fv + jpProd[pf,i,t]; #Primo-dateret user-cost kommer til at se sådan her ud

    pProd&_tEnd[pf,i,t]$(t.val=tEnd.val and d1Prod[pf,i,t] and pf_bottom_capital[pf] and d1pProd_uc_tEnd).. 
      pProd[pf,i,t] =E= pProd[pf,i,t-1];   
  $ENDBLOCK

  $BLOCK production_energydemand_link production_energydemand_link_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
      pProd&_machine_energy[pf,i,t]$(d1Prod[pf,i,t] and sameas[pf,'machine_energy'])..
        pProd[pf,i,t] =E= pREmachine[i,t]; 

      pProd&_heating[pf,i,t]$(d1Prod[pf,i,t] and sameas[pf,'heating_energy'])..
        pProd[pf,i,t] =E= pREes['heating',i,t];

      pProd&_transport[pf,i,t]$(d1Prod[pf,i,t] and sameas[pf,'transport_energy'])..
        pProd[pf,i,t] =E= pREes['transport',i,t];
  $ENDBLOCK    

# $BLOCK production_labormarket_link production_labormarket_link_endogenous $(t1.val and t.val <= tEnd.val)
#   pProd&_labor[pf,i,t]$(d1Prod[pf,i,t] and sameas[pf,'labor'])..
#     pProd[pf,i,t] =E= pL[i,t];
# $ENDBLOCK

# Add equation and endogenous variables to main model
model main / production 
             production_energydemand_link
            #  production_labormarket_link
            production_usercost
            /;
$GROUP+ main_endogenous 
  production_endogenous
  production_energydemand_link_endogenous
  # production_labormarket_link_endogenous
  production_usercost_endogenous
  ;

# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------

@load(G_production_data_variables, "../data/data.gdx")
$GROUP+ data_covered_variables G_production_data_variables;


# ------------------------------------------------------------------------------
# Exogenous variables 
# ------------------------------------------------------------------------------

eProd.l[pFnest,i]$(not sameas[pFnest,'TopPfunction']) = 0.1;
eCET.l[i] = 5;

delta.l[pf,i,t]$(d1Prod[pf,i,t] and pf_bottom_capital[pf]) = 0.05;
rFirms.l[i,t]$(sum(pf,d1Prod[pf,i,t] and pf_bottom_capital[pf])) = 0.07;

# ------------------------------------------------------------------------------
# Initial values  
# ------------------------------------------------------------------------------

pProd.l[pfNest,i,tDataEnd] = 1;
pProd.l[pf_bottom_capital,i,tDataEnd] = 1  - (1-delta.l[pf_bottom_capital,i,tDataEnd])/(1+rFirms.l[i,tDataEnd])*fv;

qProd.l[pfNest,i,t] =  sum(pf_bottom$(pf_mapping[pfNest,pf_bottom,i]), pProd.l[pf_bottom,i,t]*qProd.l[pf_bottom,i,t]);
qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);
qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);
qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);
qProd.l[pfNest,i,t] =  sum(pf$(pf_mapping[pfNest,pf,i]), pProd.l[pf,i,t]*qProd.l[pf,i,t]);

qY.l[i,t] = qProd.l['TopPfunction',i,t];

pY0.l[i,tDataEnd] = 1;
pY0_CET.l[out,i,t]$(d1pY_CET[out,i,t]) = pY_CET.l[out,i,t]; 

vtBotded.l[i,tDataEnd] = 0.05;

# ------------------------------------------------------------------------------
# Dummies 
# ------------------------------------------------------------------------------

d1Prod[pf,i,t] = yes$(qProd.l[pf,i,t]);
d1Y[i,t]       = yes$(sum(out,d1pY_CET[out,i,t]));

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

 $BLOCK production_calibration production_calibration_endogenous $(t.val=t1.val)
  markup[out,i,t]$(d1pY_CET[out,i,t]).. 
    markup[out,i,t] =E= markup_calib[i,t];

    
 $ENDBLOCK

# Add equations and calibration equations to calibration model
model calibration /
  production
  production_energydemand_link
  production_usercost
  production_calibration
/;

# Add endogenous variables to calibration model
$GROUP calibration_endogenous
  production_endogenous
  production_energydemand_link_endogenous

  -qProd[pf_bottom,i,t1], uProd[pf_bottom,i,t1]
  -pProd[pfNest,i,t1]$(not pf_top[pfNest]), uProd[pfNest,i,t1]$(not pf_top[pfNest])

  -pY_CET[out,i,t1], uY_CET[out,i,t1]
  -qY[i,t1], markup_calib[i,t1]
  production_calibration_endogenous

  production_usercost_endogenous
  -pProd[pf_bottom_capital,i,t1], jpProd[pf_bottom_capital,i,t1]  

  calibration_endogenous
;