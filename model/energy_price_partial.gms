# ----------------------------------------------------------------------------------------------------------------------
# 1. Update energy dummies and prices
# ----------------------------------------------------------------------------------------------------------------------
model energy_price_partial / energy_demand_prices
                             energy_and_emissions_taxes
                             
                            #  -E_pEpj_base
                            #  -E_pEpj_nonpriced
                            #  -E_pEpj_own
                            #  -E_vEpj_base_es_e_d
                            #  -E_vEpj_NAS_es_e_d
                            #  -E_vEpj_es_e_d
                             /;


# $MODEL energy_price_partial
#   energy_demand_prices
#   energy_and_emissions_taxes
#   ;

$Group energy_price_partial_endogenous
  energy_demand_prices_endogenous
  energy_and_emissions_taxes_endogenous
  # -pEpj$(d1pEpj_base[es,e,d,t])
  # -vEpj_base
  # -vEpj_NAS
  # -vEpj

  ;

$import Dummies_new_energy_use.gms;


# 3.1 Pre-model Solution
@add_exist_dummies_to_model(energy_price_partial);
