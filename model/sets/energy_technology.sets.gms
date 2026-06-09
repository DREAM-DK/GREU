
set l "Technology name." /t1*t1000/;

set es2k(es,k) /
  heating . iB
  transport . iT
  (appliances,process_normal,process_special,in_ETS,unspecified) . iM
  /;

alias(l,ll);
alias(e,ee);
alias(es,es_a);