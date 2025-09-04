$GROUP G_baseline # Variables that we want to be reported as baseline values (her listes de modelvariable, som man vil have en baseline-værdi af)
	G_baseline ""
       
       qESE[es,e,d,t] ""
       qESK[es,d,t] ""
       vESK[es,d,t] ""
;


# Create baseline variables for reporting
$onmultiR
$GROUP G_baseline_newvars # (her dannes _baseline-variablene)
       $LOOP G_baseline:
              {name}_baseline{sets} ""
       $ENDLOOP

;       
$offmulti

$LOOP G_baseline: # (her får _baseline-variablene sin værdi)
{name}_baseline.l{sets} = {name}.l{sets};
$ENDLOOP
