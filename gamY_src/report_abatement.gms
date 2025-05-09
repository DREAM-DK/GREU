parameter
  sTPotential_sum[es,d,t] "Sum of potentials for each energy service"
  sTAdoption[l,es,d,t] "Adoption rate of technologies (between 0 and 1)"
  pTSupply[l,es,d,t] "Average price of energy service supplied by technology l."
  qE_diff[es,e,d,t]
  qE_diff_sum[es,d,t]
  qE_pct[es,e,d,t]
  ;

sTPotential_sum[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) = sum(l, sTPotential.l[l,es,d,t]);
sTAdoption[l,es,d,t]$(d1sTPotential[l,es,d,t])            = sTold.l[l,es,d,t] / sTPotential.l[l,es,d,t] ;
pTSupply[l,es,d,t]$(d1sTPotential[l,es,d,t] and (sTold.l[l,es,d,t]*qES.l[es,d,t]))              
                                                          = vTSupply.l[l,es,d,t] / (sTold.l[l,es,d,t] * qES.l[es,d,t]) ;
# qE_diff[es,e,d,t]$(d1qES_e[es,e,d,t]) = qES_e.l[es,e,d,t] - qEpj.l[es,e,d,t];
# qE_diff_sum[es,d,t] = sum(e, qE_diff[es,e,d,t]);

# qE_pct[es,e,d,t]$(d1pEpj_base[es,e,d,t] and d1qES_e[es,e,d,t]) = (qES_e.l[es,e,d,t]/qEpj.l[es,e,d,t] - 1)*100;



# execute_unloaddi "report.gdx";