# ----------------------------------------------------------------------------------------------------------------------
# 1. Update energy dummies and prices
# ----------------------------------------------------------------------------------------------------------------------
model energy_price_partial / energy_demand_prices
                             energy_and_emissions_taxes
                             
                            # -E_pEpj_base_es_e_d
                            # -E_pEpj_own_es_e_d
                            # -E_pEpj_marg_base
                            # -E_pEpj_marg_nonpriced
                            # -E_pEpj_marg_own
                            # -E_pEpj_base
                            # -E_pEpj_nonpriced
                            # -E_pEpj_own
                            # -E_vEpj_base_es_e_d
                            # -E_vEpj_NAS_es_e_d
                            # -E_vEpj_es_e_d
                             /;

$Group energy_price_partial_endogenous
  energy_demand_prices_endogenous
  energy_and_emissions_taxes_endogenous
  # -pEpj_base$(d1pEpj_base[es,e,d,t])
  # -pEpj_own$(d1pEpj_own[es,e,d,t])
  # -pEpj_marg$(d1pEpj[es,e,d,t]) 
  # -pEpj$(d1pEpj[es,e,d,t] and d1pEpj_base[es,e,d,t])
  # -pEpj$(d1pEpj[es,e,d,t] and d1tqEpj[es,e,d,t])
  # -pEpj$(d1pEpj[es,e,d,t] and d1pEpj_own[es,e,d,t])
  # -vEpj_base
  # -vEpj_NAS
  # -vEpj

  ;

$import Dummies_new_energy_use.gms;


# 3.1 Pre-model Solution
@add_exist_dummies_to_model(energy_price_partial);
