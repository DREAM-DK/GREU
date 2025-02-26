parameter
  sTPotential_sum[es,d,t]
  qE_diff[es,e,d,t]
  qE_diff_sum[es,d,t]
  qE_pct[es,e,d,t]
  qAdoption[l,es,d,t]
  ;

sTPotential_sum[es,d,t]$(sum(l, d1sTPotential[l,es,d,t])) = sum(l, sTPotential.l[l,es,d,t]);

# qE_diff[es,e,d,t]$(d1qES_e[es,e,d,t]) = qES_e.l[es,e,d,t] - qEpj.l[es,e,d,t];
# qE_diff_sum[es,d,t] = sum(e, qE_diff[es,e,d,t]);

# qE_pct[es,e,d,t]$(d1pEpj_base[es,e,d,t] and d1qES_e[es,e,d,t]) = (qES_e.l[es,e,d,t]/qEpj.l[es,e,d,t] - 1)*100;

qAdoption[l,es,d,t]$(d1sTPotential[l,es,d,t]) = sTSupply.l[l,es,d,t] / sTPotential.l[l,es,d,t] ;

# execute_unloaddi "report.gdx";