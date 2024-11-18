
set i_load "Production industries.";
set k_load "Capital types.";
set c_load "Private consumption types.";
set g_load "Government consumption types.";
set x_load "Export types.";

$gdxIn ../data/data.gdx
$load i_load = i
$load k_load = k 
$load c_load = c 
$load g_load = g 
$load x_load = x
$gdxIn

set d "Demand components."/
  set.i_load 
  set.k_load 
  set.c_load 
  set.g_load 
  set.x_load
  /;
  
set di[d] "Intermediate input types."
  /set.i_load/
  ;

set i[d] "Industries producing demand components."
  /set.i_load/
  ;

set i "Production industries."; alias(i,i_a);
set m[i] "Industries with imports.";

set k[d] "Capital types."
  /set.k_load/
  ;

set c[d] "Consumption categories."
  /set.c_load/
  ;

set g[d] "Public consumption categories"
  /set.g_load/
  ;

set x[d] "Export types."
  /set.x_load/
  ;
