# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
$IF %stage% == "variables":

$Group+ all_variables
  qCHh[cf,t] "Private consumption of households."
  pCHh[cf,t] "Usercost of private consumption of households."
  uCHh[cf,t]  "Household consumption preferences"
  pCHh2pNest[cf,cfNest,t] "Relative prices between consumption levels"
  eCHh[cfNest] "Substitution elasticity in consumption function"
  jD_c[c,t] "Adjustment of consumption due to behavior"
  jpCHh[cf,t] "J-term to be endogenized when energy module is turned on. Energy prices in the consumption nesting are based on marginal tax-rates"
  jvtBotded_Hh[t] "Households' bottom deductions on energy-use, i.e. energy at marginal prices less payments (endogenized by energy_and_emissions_taxes module when active)."
  ;

$ENDIF # variables

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
$IF %stage% == "equations":

$BLOCK consumption_disaggregated_equations consumption_disaggregated_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

# Link to rest of the model

# Prices comes from the input-output module
  pCHh&_cf_bottom[cf_bottom,t]..
    pCHh[cf_bottom,t] =E= sum(c $c2cf_bottom_mapping[c,cf_bottom], pD[c,t]) + jpCHh[cf_bottom,t];

# The aggregate consumption is determined in the households/ramsey_household module
# Bottom deductions are subtracted, as energy in the nesting is valued at marginal prices
  qCHh&_cf_top[cf,t]$(cf_top[cf] and not t1[t]).. qCHh[cf,t] * pCHh[cf,t] - jvtBotded_Hh[t] =E= vC[t];

# Disaggregated quantities are determind in this section and linked to qD
  jD_c[c,t]$(not t1[t]).. qD[c,t] =E= sum(cf_bottom $c2cf_bottom_mapping[c,cf_bottom], qCHh[cf_bottom,t]); 


# The CES consumption function

  qCHh[cf,t]$(not cf_top[cf])..
    qCHh[cf,t] =E= uCHh[cf,t]
                    * sum(cf_mapping[cfNest,cf],
                        pCHh2pNest[cf,cfNest,t]**(-eCHh[cfNest]) * qCHh[cfNest,t]
                    );

  .. pCHh[cfNest,t] * qCHh[cfNest,t] =E= sum(cf_mapping[cfNest,cf], pCHh[cf,t] * qCHh[cf,t]);

  pCHh2pNest[cf,cfNest,t]$(cf_mapping[cfNest,cf])..
   pCHh2pNest[cf,cfNest,t] * pCHh[cfNest,t] =E= pCHh[cf,t];



$ENDBLOCK

# Add equation and endogenous variables to main model
model main / consumption_disaggregated_equations /;
$Group+ main_endogenous consumption_disaggregated_endogenous;

$ENDIF # equations

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
$IF %stage% == "exogenous_values":

#                         TopCfunction
#               /             0.3                 \
#          HouSer                                   NonHou
#         / 0.3 \                               /     1.04    \
#      cHouEne cHou                    GooTouSer               CarSer
#                                      / 0.94 \                / 0.3 \
#                                   Goods         TourServ   cCarEne cCar
#                                  / 0.3 \        / 1.25 \
#                                Food cNonFood   cSer  cTou  
#                              / 1.1 \
#                  Meat cFoodDairy cFoodVeg cFoodBev

eCHh.l['TopCfunction'] = 0.3;
eCHh.l['HouSer'] = 0.3;
eCHh.l['NonHou'] = 1.04;
eCHh.l['GooTouSer'] = 0.94;
eCHh.l['CarSer'] = 0.3;
eCHh.l['Goods'] = 0.3;
eCHh.l['TourServ'] = 1.25;
eCHh.l['Food'] = 1.1;


jpCHh.l[cf,t] = 0;
jvtBotded_Hh.l[t] = 0;

qCHh.l[cf_bottom,t] = sum(c $c2cf_bottom_mapping[c,cf_bottom], qD.l[c,t]);
qCHh.l[cfNest,t] =  sum(cf_mapping[cfNest,cf], qCHh.l[cf,t]);
qCHh.l[cfNest,t] =  sum(cf_mapping[cfNest,cf], qCHh.l[cf,t]);
qCHh.l[cfNest,t] =  sum(cf_mapping[cfNest,cf], qCHh.l[cf,t]);
qCHh.l[cfNest,t] =  sum(cf_mapping[cfNest,cf], qCHh.l[cf,t]);
qCHh.l[cfNest,t] =  sum(cf_mapping[cfNest,cf], qCHh.l[cf,t]);
qCHh.l[cfNest,t] =  sum(cf_mapping[cfNest,cf], qCHh.l[cf,t]);


$ENDIF # exogenous_values

# ------------------------------------------------------------------------------
# Starting values
# ------------------------------------------------------------------------------
$IF %stage% == "starting_values":

set_time_periods(%calibration_year%, %calibration_year%);

$Group non_default_starting_values
  # Variables that require custom starting values
;

# Set custom starting values for the variables in non_default_starting_values here

$ENDIF # starting_values

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
$IF %stage% == "calibration":

# Add equations and calibration equations to calibration model
model calibration /
  consumption_disaggregated_equations
/;


# Add endogenous variables to calibration model
$Group calibration_endogenous
  consumption_disaggregated_endogenous

  -qCHh[cf,t1]$(not cf_top[cf]), uCHh[cf,t1]$(not cf_top[cf]) 
  calibration_endogenous
;

$GROUP+ G_flat_after_last_data_year
uCHh[cf,t]$(not cf_top[cf]) #No CES-share on aggregate consumption
;

$ENDIF # calibration

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
$IF %stage% == "tests":
$ENDIF # tests