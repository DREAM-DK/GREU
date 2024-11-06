
$LOOP all_variables:
{name}_exists_dummy{sets}{$}[<t>t_dummies] = {name}_exists_dummy{sets}{$}[<t>'%calibration_year%'];
$ENDLOOP


$LOOP PG_energy_markets_prices_dummies:
	{name}{sets}{$}[<t>t_dummies] = {name}{sets}{$}[<t>'%calibration_year%'];
$ENDLOOP 

$LOOP G_flat:
	{name}.l{sets}{$}[<t>t_dummies]$({conditions}) = {name}.l{sets}{$}[<t>'%calibration_year%'];
$ENDLOOP

#  $LOOP G_energy_markets:
#  	d1{name}{sets}{$}[<t>t_dummies] = d1{name}{sets}{$}[<t>'%calibration_year%'];
#  $ENDLOOP

#  d1OneSX[ene,t_dummies] = d1OneSX[ene,'%calibration_year%'];


#  $LOOP G_energy_markets_prices:
#  	d1{name}{sets}{$}[<t>t_dummies] = d1{name}{sets}{$}[<t>'%calibration_year%'];
#  $ENDLOOP

#  $LOOP G_energy_markets_other_variables:
#  	d1{name}{sets}{$}[<t>t_dummies] = d1{name}{sets}{$}[<t>'%calibration_year%'];
#  $ENDLOOP
