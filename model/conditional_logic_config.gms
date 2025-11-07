# =============================================================================
# CONDITIONAL LOGIC CONFIGURATION
# =============================================================================
# This file contains conditional logic blocks that can be toggled on/off
# based on model settings and parameters.

# =============================================================================
# EXOGENOUS SUPPLY PRICES LOGIC
# =============================================================================
# When exogenous_supply_prices = 1, certain energy price variables are
# exogenized and markup variables are endogenized for energy commodities
# that have both production and imports.

$FUNCTION apply_exogenous_supply_prices_logic():
  $IF %exogenous_supply_prices% == 1:
    $GROUP+ main_endogenous 
      -pE_avg[e,t]$(these_e[e] and sum(i,d1pY_CET[e,i,t]) and sum(i,d1pM_CET[e,i,t])) # Average energy price is exogenized if there is both production and imports of energy
      # Mark-up is endogenized 
      rMarkup_out_i[e,i,t]$(d1pY_CET[e,i,t]), -pY_CET[e,i,t]$(d1pY_CET[e,i,t])
      pM_CET[e,i,t]$(these_e[e] and d1pM_CET[e,i,t] and sum(i_a,d1pY_CET[e,i_a,t]))
    ;
  $ENDIF
$ENDFUNCTION
