# ======================================================================================================================
# Abatement Model Reporting
# ======================================================================================================================
# This file generates reports and analysis of the abatement model results.
# It calculates key metrics and indicators for model evaluation.

# ----------------------------------------------------------------------------------------------------------------------
# 1. Report Variables
# ----------------------------------------------------------------------------------------------------------------------

$IF %stage% == "report_def":

$Group+ report_variables "Report variables"
  sqTPotential_sum[es,d,t] "Sum of potentials for each energy service"
  sqTAdoption[l,es,d,t] "Adoption rate of technologies (between 0 and 1)"
  pTSupply[l,es,d,t] "Average price of energy service supplied by technology l."
  uTK[l,es,d,t] "Average capital intensity of adopted variants of technology l"
  qESE_MechCh[es,e,d,t] "Change in energy input with baseline energy service demand"
  qES_baseline[es,d,t] "Energy service demand in baseline"
  qESE_baseline[es,e,d,t] "Energy input in baseline"
  ;

$ENDIF # report_def

# ----------------------------------------------------------------------------------------------------------------------
# 2. Baseline values
# ----------------------------------------------------------------------------------------------------------------------

$IF %stage% == "report_baseline":

  qES_baseline.l[es,d,t] = qES.l[es,d,t];

  qESE_baseline.l[es,e,d,t] = qESE.l[es,e,d,t];

$ENDIF # report_baseline


# ----------------------------------------------------------------------------------------------------------------------
# 3. Metric Calculations
# ----------------------------------------------------------------------------------------------------------------------

$IF %stage% == "report":

# 2.1 Technology Potential Analysis
sqTPotential_sum.l[es,d,t]$(sum(l, d1sqTPotential[l,es,d,t])) = 
  sum(l, sqTPotential.l[l,es,d,t]);

# 2.2 Technology Adoption Analysis
sqTAdoption.l[l,es,d,t]$(d1sqTPotential[l,es,d,t]) = 
  sqT.l[l,es,d,t] / sqTPotential.l[l,es,d,t];

# Calculate average capital intensity as conditional expectation
# For technologies with adoption, calculate average capital intensity using conditional expectation formula
uTK.l[l,es,d,t]$(d1sqTPotential[l,es,d,t] and sqT.l[l,es,d,t]>0.001)
  = @CondExpLogNorm(uTKmarg.l[l,es,d,t], uTKexp.l[l,es,d,t], eP.l[l,es,d,t]) ;

# 2.3 Price Analysis
pTSupply.l[l,es,d,t]$(d1sqTPotential[l,es,d,t] and (sqT.l[l,es,d,t]*qES.l[es,d,t])) =
    pTK.l[d,t]*uTK.l[l,es,d,t] + sum(e$(d1pEpj[es,e,d,t] and d1uTE[l,es,e,d,t]), pEpj_marg.l[es,e,d,t]*uTE.l[l,es,e,d,t]);

# 2.4 Energy Input Demand Change
qESE_MechCh.l[es,e,d,t]$(sum(l, d1sqTPotential[l,es,d,t]))
  = qES_baseline.l[es,d,t] * sum(l$(d1sqTPotential[l,es,d,t]), sqT.l[l,es,d,t] * uTE.l[l,es,e,d,t])
  - qESE_baseline.l[es,e,d,t];

$ENDIF # report
