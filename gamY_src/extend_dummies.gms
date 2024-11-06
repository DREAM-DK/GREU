
$LOOP all_variables:
{name}_exists_dummy{sets}{$}[<t>t_dummies] = {name}_exists_dummy{sets}{$}[<t>'%calibration_year%'];
$ENDLOOP

$LOOP PG_energy_markets_flat_dummies:
	{name}{sets}{$}[<t>t_dummies] = {name}{sets}{$}[<t>'%calibration_year%'];
$ENDLOOP 



