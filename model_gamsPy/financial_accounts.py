from global_container import Variable, Set, Block, Group
from growth_adjustment import inflation_adj, growth_adj, fp, fq, fv
from sets.time import t, t1
from sets.sectors import sector, Hh, Corp, Gov, RoW
from sets.input_output import k, i, i_private, i_public
from gamspy import Sum as Σ

# ------------------------------------------------------------------------------
# Variable and dummy definitions
# ------------------------------------------------------------------------------
vNetFinAssets = Variable(name="vNetFinAssets", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Net financial assets by sector.")
vNetDebtInstruments = Variable(name="vNetDebtInstruments", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Net debt instruments by sector.")
vNetEquity = Variable(name="vNetEquity", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Net equity instruments by sector.")

vNetInterests = Variable(name="vNetInterests", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Net interests received by sector.")
rInterests = Variable(name="rInterests", domain=t,
  description="Interest rate.")
rInterests_s = Variable(name="rInterests_s", domain=[sector,t],
  description="Interest rate by sector.")
jrInterests_s = Variable(name="jrInterests_s", domain=[sector,t],
  description="Deviation from average interest rate by sector.")

vNetRevaluations = Variable(name="vNetRevaluations", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Revaluations by sector.")
rRevaluations_s = Variable(name="rRevaluations_s", domain=[sector,t],
  description="Revaluations rate.")

vNetDividends = Variable(name="vNetDividends", domain=[sector,t], tags=[inflation_adj, growth_adj],
  description="Net dividends received by sector.")
rDividends = Variable(name="rDividends", domain=t,
  description="Dividends rate.")

# Will be moved to other modules:
vEBITDA_i = Variable(name="vEBITDA", domain=[i,t], tags=[inflation_adj, growth_adj],
  description="Earnings before interests, taxes, depreciation, and amortization by industry.")
vHhTaxes = Variable(name="vHhTaxes", domain=t, tags=[inflation_adj, growth_adj],
  description="Taxes on income and wealth of households and non-profits.")
vHhTransfers = Variable(name="vHhTransfers", domain=t, tags=[inflation_adj, growth_adj],
  description="Transfers to households and non-profits from government.")
vCorpTaxes = Variable(name="vCorpTaxes", domain=t, tags=[inflation_adj, growth_adj],
  description="Taxes on corporations, excluding net duties paid through investments and intermediate goods purchases.")
vI_private = Variable(name="vI_private", domain=t, tags=[inflation_adj, growth_adj],
  description="Total capital investments in private sector.")
vI_public = Variable(name="vI_public", domain=t, tags=[inflation_adj, growth_adj],
  description="Total capital investments in public sector.")

# ------------------------------------------------------------------------------
# Equations
# ------------------------------------------------------------------------------
def define_equations():
  global main_block
  main_block = Block(condition=t.val >= t1.val)

  from factor_demand import vI_k_i, vInvt_i, vE_i
  from labor_market import vWages, vWages_i
  from input_output import vC, vG, vtY, vtM, vM, vX, vY_i, vD

  main_block[...] = vI_private[t] == Σ(i.where[i_private[i]], Σ(k, vI_k_i[k,i,t]) + vInvt_i[i,t])
  main_block[...] = vI_public[t] == Σ(i.where[i_public[i]], Σ(k, vI_k_i[k,i,t]) + vInvt_i[i,t])

  main_block[...] = (
    vNetFinAssets[Hh,t] == vNetFinAssets[Hh,t-1]/fv
                         + vNetInterests[Hh,t] + vNetDividends[Hh,t] + vNetRevaluations[Hh,t]
                         + vWages[t]
                         + vHhTransfers[t]
                         - vC[t]
                         - vHhTaxes[t]
  )

  main_block[...] = (
    vNetFinAssets[Corp,t] == vNetFinAssets[Corp,t-1]/fv
                            + vNetInterests[Corp,t] + vNetDividends[Corp,t] + vNetRevaluations[Corp,t]
                            + Σ(i.where[i_private[i]], vEBITDA_i[i,t]) - vI_private[t]
                            - vCorpTaxes[t]
  )

  main_block[...] = (
    vNetFinAssets[Gov,t] == vNetFinAssets[Gov,t-1]/fv
                            + vNetInterests[Gov,t] + vNetDividends[Gov,t] + vNetRevaluations[Gov,t]
                            - vG[t]
                            - vHhTransfers[t]
                            + Σ(i.where[i_public[i]], vEBITDA_i[i,t]) - vI_public[t]
                            + vtY[t] + vtM[t] # Net duties, paid through R, E, I, C, G, and X
                            + vHhTaxes[t] + vCorpTaxes[t]
  )

  main_block[...] = (
    vNetFinAssets[RoW,t] == vNetFinAssets[RoW,t-1]/fv
                          + vNetInterests[RoW,t] + vNetDividends[RoW,t] + vNetRevaluations[RoW,t]
                          + vM[t]
                          - vX[t]
  )

  main_block[...] = vEBITDA_i[i,t] == vY_i[i,t] - vWages_i[i,t] - vD[i,t] - vE_i[i,t] # Net duties should be subtracted here

  # For now, we assume that households own all domestic equity going forward
  main_block[...] = vNetEquity[Gov,t] == 0
  main_block[...] = vNetEquity[RoW,t] == 0
  main_block[...] = vNetEquity[Hh,t] == -vNetEquity['Corp',t]

  # And we set corporate debt to zero
  main_block[vNetEquity[Corp,t]] = vNetDebtInstruments[Corp,t] == 0

  # Debt instruments are residual given net financial assets and equity
  main_block[...] = vNetDebtInstruments[sector,t] == vNetFinAssets[sector,t] - vNetEquity[sector,t]

  # For now we assume that corporations pay out any excess cash as dividends (issue stocks)
  # And we do not calculate value of the firm for endogenous revaluations
  main_block[rDividends[t]] = (
    -vNetDividends['Corp',t] == Σ(i.where[i_private[i]], vEBITDA_i[i,t]) - vI_private[t]
                              + vNetInterests['Corp',t] # is negative
                              - vCorpTaxes[t]
                              - (vNetDebtInstruments['Corp',t] - vNetDebtInstruments['Corp',t-1]/fv) # Purchasing securities or repaying debt (issuing debt or selling securities)
  )

  # For now assume no non-domestic equities
  main_block[...] = vNetDividends[sector,t] == rDividends[t] * vNetEquity[sector,t-1]/fv

  main_block[...] = vNetInterests[sector,t] == rInterests_s[sector,t] * vNetDebtInstruments[sector,t-1]/fv
  main_block[...] = vNetRevaluations[sector,t] == rRevaluations_s[sector,t] * vNetFinAssets[sector,t-1]/fv

  main_block[...] = rInterests_s[sector,t] == rInterests[t] + jrInterests_s[sector,t]

  # Interests of sectors sum to zero. Rest of World is residual.
  main_block[jrInterests_s[RoW,t]] = Σ(sector, vNetInterests[sector,t]) == 0

# ------------------------------------------------------------------------------
# Data and exogenous parameters
# ------------------------------------------------------------------------------
data_variables = (
  Group()
  # + vNetFinAssets[sector,t1]
  # + vNetDebtInstruments[sector,t1]
  # + vNetEquity[sector,t1]
  # + vNetInterests[sector,t1]
  # + rInterests[t1]
)

# We use rough values for financial accounts based on MAKRO for now
vNetDebtInstruments.l['Hh',t] = 670
vNetDebtInstruments.l['Corp',t] = 200
vNetDebtInstruments.l['Gov',t] = -440
vNetDebtInstruments.l['RoW',t] = -Σ(sector, vNetDebtInstruments.l[sector,t])

vNetFinAssets.l['Hh',t] = 6690
vNetFinAssets.l['Corp',t] = -5570
vNetFinAssets.l['Gov',t] = 270
vNetFinAssets.l['RoW',t] = - Σ(sector, vNetFinAssets.l[sector,t])

vNetEquity.l[sector,t] = vNetFinAssets.l[sector,t] - vNetDebtInstruments.l[sector,t]

# And set interests to 4% for all sectors, and revaluations to zero
rInterests.l[t] = 0.04
vNetInterests.l[sector,t] = rInterests.l[t] * vNetDebtInstruments.l[sector,t-1]

# ------------------------------------------------------------------------------
# Calibration
# ------------------------------------------------------------------------------
def define_calibration():
  global calibration_block
  calibration_block = main_block.copy()

  calibration_block.endogenous = (
    main_block.endogenous
    - vNetFinAssets[sector,t1].where[~RoW[sector]] + jrInterests_s[sector,t1].where[~RoW[sector]]
    - vNetRevaluations[sector,t1] + rRevaluations_s[sector,t1]
  )

# ------------------------------------------------------------------------------
# Tests
# ------------------------------------------------------------------------------
def tests():
  for var in [vNetInterests,
              vNetDividends,
              vNetRevaluations,
              vNetDebtInstruments,
              vNetEquity,
              vNetFinAssets]:
    sector_balance = var.l.records.groupby('t')['level'].sum()
    assert sector_balance.max() < 1e-9, f"{var.name} do not sum to zero."
