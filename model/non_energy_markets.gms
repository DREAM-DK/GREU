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
    vtNetproductionRest[i,t]$(d1Y_i[i,t]) "Net production subsidies and taxes not internalized in user-cost of capital and not included in other items listed below, bio. kroner"
    vDiffMarginAvgE[i,t]$(d1Y_i[i,t]) "Difference between marginal and average energy-costs, bio. kroner"
    vtEmmRxE[i,t]$(d1Y_i[i,t]) "Taxes on non-energy related emissions, bio. kroner"
    vtCAP_prodsubsidy[i,t]$(d1Y_i[i,t]) "Agricultural subsidies from EU CAP subsidizing production directly, bio. kroner"

    uProd[pf,i,t]$(d1Prod[pf,i,t]) "CES-Share of production for nest or factor (pf)"
    eProd[pFnest,i] "Elasticity of substitution between production nests"

    pProd2pNest[pf,pfNest,i,t]$(d1Prod[pf,i,t] and d1Prod[pfNest,i,t]) "Price ratio between production factor and its nest."

    qPFtop2qY[i,t] "Ratio between qProd[pf_top] and qY_i in basis year where prices are set to 1."
  ;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------


 qY_CET['out_other',i,t] =E= sum(d_xre, qY_i_d[i,d_xre,t]) #Non-energy
                          +  sum(d_xre, qY_i_enemargins[i,])

#Energy-markets in energy_markets


qY_i_enemargins[i,]