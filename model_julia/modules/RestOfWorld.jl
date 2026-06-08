# ==============================================================================
# Rest of World (sector-accounts slice)
# ==============================================================================
# Populates the rest-of-world entries of the SectorAccounts interface
# variables.
#
# In ESA the rest-of-world account is presented from RoW's point of view as
# the counterparty of the domestic economy. The trade balance enters as
# "primary income" of RoW: when the domestic economy imports more than it
# exports, that is income to RoW (and RoW becomes a net lender to us).
# RoW has no final consumption and no gross capital formation in this
# framework; those are recorded only for resident sectors.

module RestOfWorld

import JuMP
using SquareModels
import ..db
import ..Time: t, t1, T
import ..InputOutput: vM, vX
import ..SectorAccounts: vPrimaryIncome, vNetTransfers, vFinalConsumption, vGrossCapitalFormation

function define_equations()
  return @block db begin
    # RoW's "primary income" with the domestic economy is the trade balance
    # from the domestic side: imports minus exports (InputOutput vM, vX).
    vPrimaryIncome[s=[:RoW], t=t1:T],
    vPrimaryIncome[s,t] == vM[t] - vX[t]
  end
end

end # module
