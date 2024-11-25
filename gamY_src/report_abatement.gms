parameter
  qE_diff[es,e,i,t]
  qE_diff_sum[es,i,t]
  qE_pct[es,e,i,t]
  qAdoption[l,es,i,t]
  ;

qE_diff[es,e,i,t] = qE_tech.l[es,e,i,t] - qREpj.l[es,e,i,t];
qE_diff_sum[es,i,t] = sum(e, qE_diff[es,e,i,t]);

qE_pct[es,e,i,t]$(d1pREpj_base[es,e,i,t]) = (qE_tech.l[es,e,i,t]/qREpj.l[es,e,i,t] - 1)*100;

qAdoption[l,es,i,t]$(d1theta[l,es,i,t]) = errorf(InputErrorf_qTutil.l[l,es,i,t]);

# execute_unloaddi "report.gdx";