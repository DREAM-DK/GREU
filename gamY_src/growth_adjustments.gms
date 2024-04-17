
parameters
  gp "Steady state rate of inflation." /0.02/
  gq "Steady state labor saving technical progress." /0.01/

  fp "1+gp"
  fq "1+gq"
  fv "fp * fq"

  fpt[t] "fp^(t-tBase)"
  fqt[t] "fq^(t-tBase)"
  fvt[t] "fv^(t-tBase)"
;


fp = 1 + gp;
fq = 1 + gq;
fv = fp * fq;

fpt[t] = fp ** (t.val - tBase.val);
fqt[t] = fq ** (t.val - tBase.val);
fvt[t] = fv ** (t.val - tBase.val);