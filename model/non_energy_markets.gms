# ------------------------------------------------------------------------------
# Variable, dummy and group creation
# ------------------------------------------------------------------------------

$IF %stage% == "variables":

			$SetGroup+ SG_flat_after_last_data_year 
			  d1Y_i_d_non_ene[i,d,t] ""
			  d1M_i_d_non_ene[i,d,t] ""
			;


			$Group+ all_variables
        vY_i_d_non_ene[i,d,t]$(d1Y_i_d_non_ene[i,d,t]) ""
        qY_i_d_non_ene[i,d,t]$(d1Y_i_d_non_ene[i,d,t]) ""
        pY_i_d_non_ene[i,d,t]$(d1Y_i_d_non_ene[i,d,t]) ""
        tY_i_d_non_ene[i,d,t]$(d1Y_i_d_non_ene[i,d,t]) ""
        vtY_i_d_non_ene[i,d,t]$(d1Y_i_d_non_ene[i,d,t]) ""
        jqY_i_d_non_ene[i,d,t]$(d1Y_i_d_non_ene[i,d,t]) ""
        jqY_i_d[i,d,t]$(d1Y_i_d[i,d,t]) ""

        vM_i_d_non_ene[i,d,t]$(d1M_i_d_non_ene[i,d,t]) ""
        qM_i_d_non_ene[i,d,t]$(d1M_i_d_non_ene[i,d,t]) ""
        pM_i_d_non_ene[i,d,t]$(d1M_i_d_non_ene[i,d,t]) ""
        tM_i_d_non_ene[i,d,t]$(d1M_i_d_non_ene[i,d,t]) ""
        vtM_i_d_non_ene[i,d,t]$(d1M_i_d_non_ene[i,d,t]) ""
        jqM_i_d_non_ene[i,d,t]$(d1M_i_d_non_ene[i,d,t]) ""
        jqM_i_d[i,d,t]$(d1M_i_d[i,d,t]) ""


        rM_non_ene[i,d,t]$(d1M_i_d_non_ene[i,d,t] or d1M_i_d_non_ene[i,d,t]) ""
        rYM_non_ene[i,d,t]$(d1Y_i_d_non_ene[i,d,t] or d1M_i_d_non_ene[i,d,t]) ""

        vD_non_ene[d,t]$(sum(i, d1Y_i_d_non_ene[i,d,t]) or sum(i, d1M_i_d_non_ene[i,d,t])) ""
        pD_non_ene[d,t]$(sum(i, d1Y_i_d_non_ene[i,d,t]) or sum(i, d1M_i_d_non_ene[i,d,t])) ""
        qD_non_ene[d,t]$(sum(i, d1Y_i_d_non_ene[i,d,t]) or sum(i, d1M_i_d_non_ene[i,d,t])) ""


        sSupply_e_i_m[e,i,t]$(d1pM_CET[e,i,t]) ""
        sSupply_e_i_y[e,i,t]$(d1pY_CET[e,i,t]) ""
				;


			$Group+ G_flat_after_last_data_year
				tY_i_d_non_ene
        tM_i_d_non_ene
			;

			$Group G_non_energy_markets_data
			  vY_i_d_non_ene
				vM_i_d_non_ene
				vtY_i_d_non_ene
				vtM_i_d_non_ene
				qD_non_ene
				;

	$ENDIF 
  
  # ------------------------------------------------------------------------------
	# Equations
	# ------------------------------------------------------------------------------

	$IF %stage% == "equations":

    
    $BLOCK non_energy_markets_clearing non_energy_markets_clearing_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

				#Links to CET
				#  ..qY_CET[out_other,i,t] =E= sum(d_non_ene, qY_i_d_non_ene[i,d_non_ene,t]) + qD_EAV[t]$(i_wholesale[i]) + qD_CAV[t]$(i_cardealers[i]) + qD_DAV[t]$(i_retail[i]);
				 ..qY_CET[out_other,i,t] =E= sum(d_non_ene,qY_i_d[i,d_non_ene,t]/ (1+tY_i_d[i,d_non_ene,tBase])) + qD_EAV[t]$(i_wholesale[i]) + qD_CAV[t]$(i_cardealers[i]) + qD_DAV[t]$(i_retail[i]);


				#  ..qM_CET[out_other,i,t] =E= sum(d_non_ene, qM_i_d_non_ene[i,d_non_ene,t]);
				 ..qM_CET[out_other,i,t] =E= sum(d_non_ene,qM_i_d[i,d_non_ene,t]/ (1+tM_i_d[i,d_non_ene,tBase]));


				 .. vY_CET[out_other,i,t] =E= pY_CET[out_other,i,t]*qY_CET[out_other,i,t];

				 .. vM_CET[out_other,i,t] =E= pM_CET[out_other,i,t]*qM_CET[out_other,i,t];

    $ENDBLOCK 

    $BLOCK non_energy_markets_IO non_energy_markets_IO_endogenous $(t1.val <= t.val and t.val <= tEnd.val)

				#Demand split on 
				 ..qY_i_d_non_ene[i_control,d_non_ene,t] =E= (1-rM_non_ene[i_control,d_non_ene,t]) * rYM_non_ene[i_control,d_non_ene,t] * qD_non_ene[d_non_ene,t];

				 ..qM_i_d_non_ene[i_control,d_non_ene,t] =E= rM_non_ene[i_control,d_non_ene,t]     * rYM_non_ene[i_control,d_non_ene,t] * qD_non_ene[d_non_ene,t];	


				 .. pY_i_d_non_ene[i_control,d_non_ene,t] =E= (1+tY_i_d_non_ene[i_control,d_non_ene,t]) * pY_CET['out_other',i_control,t];

				 .. pM_i_d_non_ene[i_control,d_non_ene,t] =E= (1+tM_i_d_non_ene[i_control,d_non_ene,t]) * pM_CET['out_other',i_control,t];	

				 .. vY_i_d_non_ene[i_control,d_non_ene,t] =E= pY_i_d_non_ene[i_control,d_non_ene,t] * qY_i_d_non_ene[i_control,d_non_ene,t];

				 .. vM_i_d_non_ene[i_control,d_non_ene,t] =E= pM_i_d_non_ene[i_control,d_non_ene,t] * qM_i_d_non_ene[i_control,d_non_ene,t];	

				 .. vtY_i_d_non_ene[i_control,d_non_ene,t] =E= tY_i_d_non_ene[i_control,d_non_ene,t] * pY_CET['out_other',i_control,t] * qY_i_d_non_ene[i_control,d_non_ene,t];

				 .. vtM_i_d_non_ene[i_control,d_non_ene,t] =E= tM_i_d_non_ene[i_control,d_non_ene,t] * pM_CET['out_other',i_control,t] * qM_i_d_non_ene[i_control,d_non_ene,t];

				 .. vD_non_ene[d_non_ene,t] =E= sum(i_control, vY_i_d_non_ene[i_control,d_non_ene,t]+ vM_i_d_non_ene[i_control,d_non_ene,t]);

				 .. pD_non_ene[d_non_ene,t]*qD[d_non_ene,t] =E= vD_non_ene[d_non_ene,t];

		$ENDBLOCK 

		$BLOCK non_energy_markets_links non_energy_markets_links_endogenous $(t1.val <= t.val and t.val <=tEnd.val)
			
				 #Link to factor demand
					jpProd[Rxe,i,t]..
						pProd[RxE,i,t] =E= sum(d_non_ene$d_non_ene2i(d_non_ene,i), pD_non_ene[d_non_ene,t]);

					qD_non_ene&_RxE[d_non_ene,t]$sum(i,d_non_ene2i(d_non_ene,i))..
			    	 qD_non_ene[d_non_ene,t] =E= sum(i$d_non_ene2i(d_non_ene,i), qProd['RxE',i,t]);

					qD_non_ene&_k[d_non_ene,t]$sum(k,d_non_ene2k(d_non_ene,k))..
							qD_non_ene[d_non_ene,t] =E= sum((k,i)$d_non_ene2k(d_non_ene,k), qI_k_i[k,i,t]);

					qD_non_ene&_invt[d_non_ene,t]$(sameas[d_non_ene,'invt'])..
						qD_non_ene['invt',t] =E= qD['invt',t];


					$(not tEnd[t])..
						jpK_k_i[k,i,t] =E= pD_non_ene[k,t] - (1-rKDepr_k_i[k,i,t]) / (1+rHurdleRate_i[i,t+1]) * pD_non_ene[k,t+1]*fp;
					jpK_k_i&_tEnd[k,i,t]$(tEnd[t])..
						pK_k_i[k,i,t] =E= pD_non_ene[k,t] - (1-rKDepr_k_i[k,i,t]) / (1+rHurdleRate_i[i,t]) * pD_non_ene[k,t]*fp;
					#Links to input-output

						#Non-energy quantities
						# rYM&_only_Y_i[i_control,d_non_ene,t]$(not sameas[d_non_ene,'invt'] and d1Y_i_d_non_ene[i_control,d_non_ene,t] and not d1M_i_d_non_ene[i_control,d_non_ene,t])..
						# 	qY_i_d_non_ene[i_control,d_non_ene,t] =E= qY_i_d[i_control,d_non_ene,t]/ (1+tY_i_d[i_control,d_non_ene,tBase]) + jqY_i_d_non_ene[i_control,d_non_ene,t]; 

						# #
						# rYM&_only_M_i[i_control,d_non_ene,t]$(not sameas[d_non_ene,'invt'] and d1M_i_d_non_ene[i_control,d_non_ene,t] and not d1Y_i_d_non_ene[i_control,d_non_ene,t])..
						# 	qM_i_d_non_ene[i_control,d_non_ene,t] =E= qM_i_d[i_control,d_non_ene,t]/ (1+tM_i_d[i_control,d_non_ene,tBase]) + jqM_i_d_non_ene[i_control,d_non_ene,t]; 

						# #NOTE THAT THIS IS RM0 (not RM), BECAUSE OF THE "IMPORTS.GMS"-MODULE THAT TAKES OVER RM IN INPUT_OUTPUT
						# rM0&_both_M_and_Y[i_control,d_non_ene,t]$(not sameas[d_non_ene,'invt'] and d1M_i_d_non_ene[i_control,d_non_ene,t] and d1Y_i_d_non_ene[i_control,d_non_ene,t])..
						# 	qM_i_d_non_ene[i_control,d_non_ene,t] =E= qM_i_d[i_control,d_non_ene,t]/ (1+tM_i_d[i_control,d_non_ene,tBase]) + jqM_i_d_non_ene[i_control,d_non_ene,t]; 

					#Prices/total value of non-energy
					# jfpY_i_d[i,d_non_ene,t]..
					# 	pY_i_d[i,d_non_ene,t]*qY_i_d[i,d_non_ene,t]  =E= pY_i_d_non_ene[i,d_non_ene,t] * qY_i_d_non_ene[i,d_non_ene,t] + vY_i_d_calib[i,d_non_ene,t]; 

					# jfpM_i_d[i,d_non_ene,t]..
					# 	pM_i_d[i,d_non_ene,t]*qM_i_d[i,d_non_ene,t]  =E= pM_i_d_non_ene[i,d_non_ene,t] * qM_i_d_non_ene[i,d_non_ene,t] + vM_i_d_calib[i,d_non_ene,t]; 

		$ENDBLOCK

    model  main/
           non_energy_markets_clearing
           non_energy_markets_IO 
          #  non_energy_markets_links
           /

    $Group+ main_endogenous 
      non_energy_markets_clearing_endogenous
      non_energy_markets_IO_endogenous
      # non_energy_markets_links_endogenous
    ;


$ENDIF


# ------------------------------------------------------------------------------
# Data 
# ------------------------------------------------------------------------------

	$IF %stage% == "exogenous_values":

	  	@inf_growth_adjust()
			@load(G_non_energy_markets_data, "../data/data.gdx")
			@remove_inf_growth_adjustment()

			$Group+ data_covered_variables
				G_non_energy_markets_data$(t.val <= %calibration_year%)
			;

		#Data

		pY_i_d_non_ene.l[i,d_non_ene,t]$(abs(vY_i_d_non_ene.l[i,d_non_ene,t])> 1e-6) = 1;
		pM_i_d_non_ene.l[i,d_non_ene,t]$(abs(vM_i_d_non_ene.l[i,d_non_ene,t])> 1e-6) = 1;
		qY_i_d_non_ene.l[i,d_non_ene,t]$(abs(vY_i_d_non_ene.l[i,d_non_ene,t])> 1e-6) = vY_i_d_non_ene.l[i,d_non_ene,t] - vtY_i_d_non_ene.l[i,d_non_ene,t];
		qM_i_d_non_ene.l[i,d_non_ene,t]$(abs(vM_i_d_non_ene.l[i,d_non_ene,t])> 1e-6) = vM_i_d_non_ene.l[i,d_non_ene,t] - vtM_i_d_non_ene.l[i,d_non_ene,t];
		
		vY_i_d_non_ene.l[i,d_non_ene,t]$(abs(vY_i_d_non_ene.l[i,d_non_ene,t]) <1e-6) = 0;
		vM_i_d_non_ene.l[i,d_non_ene,t]$(abs(vM_i_d_non_ene.l[i,d_non_ene,t]) <1e-6) = 0;

		pD_non_ene.l[d_non_ene,t] = fpt[t];

		rYM_non_ene.l[i,d_non_ene,t]$(vY_i_d_non_ene.l[i,d_non_ene,t] or vM_i_d_non_ene.l[i,d_non_ene,t]) = (vY_i_d_non_ene.l[i,d_non_ene,t] + vM_i_d_non_ene.l[i,d_non_ene,t])/sum(d_non_ene_a, vY_i_d_non_ene.l[i,d_non_ene_a,t] + vM_i_d_non_ene.l[i,d_non_ene_a,t]);
		rM_non_ene.l[i,d_non_ene,t]$(vM_i_d_non_ene.l[i,d_non_ene,t] and not vY_i_d_non_ene.l[i,d_non_ene,t]) = vM_i_d_non_ene.l[i,d_non_ene,t]/(vM_i_d_non_ene.l[i,d_non_ene,t] + vY_i_d_non_ene.l[i,d_non_ene,t]);

		# ------------------------------------------------------------------------------
		# Dummies
		# ------------------------------------------------------------------------------


		d1Y_i_d_non_ene[i,d_non_ene,t] = yes$(abs(vY_i_d_non_ene.l[i,d_non_ene,t])>1e-6);
		d1M_i_d_non_ene[i,d_non_ene,t] = yes$(abs(vM_i_d_non_ene.l[i,d_non_ene,t])>1e-6);



$ENDIF

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------

$IF %stage% == "calibration":

    $BLOCK non_energy_markets_clearing_calibration non_energy_markets_clearing_calibration_endogenous $(t1.val <= t.val and t.val <=tEnd.val)

			# jqY_i_d_non_ene[i_control,d_non_ene,t]$(t.val > t1.val and d1Y_i_d_non_ene[i_control,d_non_ene,t] and not sameas[d_non_ene,'invt'])..
			# 	jqY_i_d_non_ene[i_control,d_non_ene,t] =E= 0;

			# jqM_i_d_non_ene[i_control,d_non_ene,t]$(t.val > t1.val and d1M_i_d_non_ene[i_control,d_non_ene,t] and not sameas[d_non_ene,'invt'])..
			# 	jqM_i_d_non_ene[i_control,d_non_ene,t] =E= 0;


			# jqY_i_d[i,re,t]$(t.val > t1.val and d1Y_i_d[i,re,t])..
			# 	jqY_i_d[i,re,t] =E= 0;

			# jqM_i_d[i,re,t]$(t.val > t1.val and d1M_i_d[i,re,t])..
			# 	jqM_i_d[i,re,t] =E= 0;

	$ENDBLOCK 

	model calibration /
           non_energy_markets_clearing
           non_energy_markets_IO 
          #  non_energy_markets_clearing_calibration
          #  non_energy_markets_links
          /;

  $Group calibration_endogenous
  	
    non_energy_markets_clearing_endogenous
    # non_energy_markets_clearing_calibration_endogenous

    non_energy_markets_IO_endogenous
		-vtY_i_d_non_ene[i,d_non_ene,t1], tY_i_d_non_ene[i,d_non_ene,t1]
		-vtM_i_d_non_ene[i,d_non_ene,t1], tM_i_d_non_ene[i,d_non_ene,t1]
		
		-qY_i_d_non_ene[i,d_non_ene,t1], rYM_non_ene[i,d_non_ene,t1]
		-qM_i_d_non_ene[i,d_non_ene,t1], rM_non_ene[i,d_non_ene,t1]$(d1Y_i_d_non_ene[i,d_non_ene,t1] and d1M_i_d_non_ene[i,d_non_ene,t1])


		# non_energy_markets_links_endogenous
		# jqY_i_d_non_ene[i_control,d_non_ene,t1]$(d1Y_i_d_non_ene[i_control,d_non_ene,t1] and not d1M_i_d_non_ene[i,d_non_ene,t1])
		# jqM_i_d_non_ene[i_control,d_non_ene,t1]$(not d1Y_i_d_non_ene[i_control,d_non_ene,t1] and d1M_i_d_non_ene[i,d_non_ene,t1])
		# jqM_i_d_non_ene[i_control,d_non_ene,t1]$(d1Y_i_d_non_ene[i_control,d_non_ene,t1] and d1M_i_d_non_ene[i,d_non_ene,t1])

		#Non_energy io-prices
		# vY_i_d_calib[i,d_non_ene,t1], -jfpY_i_d[i,d_non_ene,t1]
		# vM_i_d_calib[i,d_non_ene,t1], -jfpM_i_d[i,d_non_ene,t1]



    calibration_endogenous
  ;

$ENDIF


