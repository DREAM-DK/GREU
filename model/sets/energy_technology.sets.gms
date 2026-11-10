
set l "Technology name." /t1*t1000/;

set es2k(es,k) /
  heating . iB
  transport . iT
  (appliances,process_normal,process_special,in_ETS,unspecified) . iM
  /;

alias(l,ll);
alias(e,ee);
alias(es,es_a);

# Parameters governing new energy use in energy technology model (not already defined in CGE model)
parameter
  d1pEpj_base_CGE[es,e,d,t]
  d1pEpj_CGE[es,e,d,t]
  d1pEpj_marg_CGE[es,e,i,t]
  d1pEpj_marg_inNest_CGE[es,e,i,t]
  d1tqEpj_CGE[es,e,d,t]
  d1qEpj_CGE[es,e,d,t]
  d1tCO2_ETS_E_CGE[em,es,e,d,t]
  d1tCO2_ETS_CGE[d,t]
  d1tCO2_ETS2_E_CGE[em,es,e,d,t]
  d1tCO2_ETS2_CGE[d,t]
  d1EmmE_BU_CGE[em,es,e,d,t]
  uEmmE_BU_CGE[em,es,e,d,t]
  d1tCO2_E_CGE[em,es,e,d,t]
  tCO2_Emarg_CGE[em,es,e,i,t]
  d1tE_duty_CGE[etaxes,es,e,d,t]

  d1pEpj_base_energy_technology[es,e,d,t]
  d1pEpj_energy_technology[es,e,d,t]
  d1pEpj_marg_energy_technology[es,e,i,t]
  d1pEpj_marg_inNest_energy_technology[es,e,i,t]
  d1tqEpj_energy_technology[es,e,d,t]
  d1qEpj_energy_technology[es,e,d,t]
  d1tCO2_ETS_E_energy_technology[em,es,e,d,t]
  d1tCO2_ETS_energy_technology[d,t]
  d1tCO2_ETS2_E_energy_technology[em,es,e,d,t]
  d1tCO2_ETS2_energy_technology[d,t]
  d1EmmE_BU_energy_technology[em,es,e,d,t]
  uEmmE_BU_energy_technology[em,es,e,d,t]
  d1tCO2_E_energy_technology[em,es,e,d,t]
  tCO2_Emarg_energy_technology[em,es,e,i,t]
  d1tE_duty_energy_technology[etaxes,es,e,d,t]

  d1no_energy_price[e] "Dummy determining whether new energy use in the energy technology model should get dimensions in the CGE model (i.e. the energy price is not priced in the CGE model)"
;

# Initialisation of parameters governing new energy use in energy technology model (not already defined in CGE model)
d1EmmE_BU_energy_technology[em,es,e,d,t] = no;
