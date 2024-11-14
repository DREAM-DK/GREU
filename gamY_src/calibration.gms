# ==============================================================================
# Calibration
# ==============================================================================
# Limit the model to only include elements that are not dummied out
model calibration /
  $LOOP all_variables:
    {name}({name}_exists_dummy)
  $ENDLOOP
/;

@set(data_covered_variables, _data, .l) # Save values of data covered variables prior to calibration

$GROUP+ calibration_endogenous - nonexisting;

# ------------------------------------------------------------------------------
# Static calibration
# ------------------------------------------------------------------------------

set_time_periods(%calibration_year%, %calibration_year%);
$LOOP calibration_endogenous: # Set starting values for main_endogenous variables to 1 if no other value is given
  {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = 0.5;
$ENDLOOP

$FIX all_variables; $UNFIX calibration_endogenous;

# Starting values to hot-start solver
# $GROUP G_do_not_load ;
# $GROUP G_load calibration_endogenous, - G_do_not_load;
# @load_as(G_load, "previous_calibration.gdx", .l);

d1pProd_uc_tEnd = no;
execute_unload 'static_calibration_pre.gdx';
solve calibration using CNS;
execute_unload 'static_calibration.gdx';

 # ------------------------------------------------------------------------------
 # Dynamic calibration
 # ------------------------------------------------------------------------------
 
 set_time_periods(%calibration_year%, %terminal_year%);
 # Starting values to hot-start solver
 # $GROUP G_do_not_load ;
 # $GROUP G_load calibration_endogenous, - G_do_not_load;
 # @load_as(G_load, "previous_calibration.gdx", .l);

 #Extending dummies with "flat forecast" after last data year
	$LOOP all_variables: #Extending exist dummies
		{name}_exists_dummy{sets}{$}[<t>t_dummies] = {name}_exists_dummy{sets}{$}[<t>'%calibration_year%'];
	$ENDLOOP

	$LOOP PG_flat_after_last_data_year: #Extending model dummies 
		{name}{sets}{$}[<t>t_dummies] = {name}{sets}{$}[<t>'%calibration_year%'];
	$ENDLOOP 

 #Extending variables with "flat forecast" after last data year
	 $LOOP G_flat_after_last_data_year:
		{name}.l{sets}{$}[<t>t_dummies] = {name}.l{sets}{$}[<t>'%calibration_year%'];
	 $ENDLOOP

 # Set starting values for endogenous variables value in t1
	 $LOOP calibration_endogenous: 
	 {name}.l{sets}$({conditions} and {name}.l{sets} = 0) = {name}.l{sets}{$}[<t>t1];
	 $ENDLOOP

	 $GROUP G_calibration_endogenous_x 
			calibration_endogenous
			-uY_CET$(sameas[out,'WholeAndRetailSaleMarginE']) #Den her flytter sig en my...
			-uY_CET$(sameas[out,'Firewood and woodchips'])    #Den her flytter sig en my..
			-uY_CET$(sameas[out,'Natural gas (Extraction)'])
			-uY_CET
			-jpProd                                                  
			-pProd[pf_bottom_capital,i,t]
			-G_emissions_BU_quantities 
			
			-G_emissions_aggregates_quantities
			-G_emissions_aggregates_other
	 ;
		

 d1pProd_uc_tEnd = yes;
 $FIX all_variables; $UNFIX calibration_endogenous;
	@set(G_calibration_endogenous_x, _endosaved, .l); # Save values of data covered variables prior to calibration
 execute_unloaddi "calibration_pre.gdx";
 solve calibration using CNS;
 execute_unloaddi "calibration.gdx";
 
 @assert_no_difference(G_calibration_endogenous_x, 1e-6, _endosaved, .l, "Calibration changed endogenous variables.");


#  @assert_no_difference(data_covered_variables, 1e-6, _data, .l, "Calibration changed variables covered by data.")
