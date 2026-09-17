# Why a labor productivity gain lowers the wage

A permanent one percent labor productivity gain lowers the nominal wage by about
one percent. It should raise it by one percent. This note reports what we
measured, and what we think causes it.

The wage is not the fault. The wage is a magnifier of a demand gap, and the
demand gap comes from household wealth. Household wealth cannot grow with the
economy, because the model measures it as net financial assets and gives
households no way to buy a claim on a larger capital stock.

## The experiment

We raise labor productivity by one percent in every industry from `t1+5` to `T`,
and we raise the foreign export market by one percent over the same period:

```julia
scenario[Production.uProd[labor_type,:,shock_period]] .*= (1 + shock_size)^(E-1)
scenario[Exports.qXMarket_p[:,shock_period]] .*= 1 + shock_size
```

We drop `:PhillipsCurve` from `model_modules`. Employment then stays at its
baseline level and `pW` clears the labor market in each year. The printed
employment deviation is `1e-14`, so the closure works.

We first confirmed that the shock is a true labor augmenting productivity gain.
With the CES demand and price equations in `Production.jl`, a productivity factor
`A` on labor gives `u'_L = u_L * A^(e-1)`. The same expression satisfies the
demand equation and the implied price index, so the substitution is exact. Every
nest in `full_nesting` uses `elasticity = 0.7`, and `prune_nesting` cannot change
that value, so `E = 0.7` is right in every industry. The shock is not the fault.

## What the numbers show

Percentage deviations from baseline, last year of the horizon. Every real
quantity should read `+1.0`, and every price should read `0.0`.

| variable | fiscal closure only | with corporate closure | target |
|---|---|---|---|
| `qGDP` | −0.71 | −0.01 | +1.0 |
| `qC` | −2.95 | −2.88 | +1.0 |
| `qI` | +1.16 | +0.58 | +1.0 |
| `qX` | +0.75 | +2.68 | +1.0 |
| `qG` | +1.01 | +1.47 | +1.0 |
| capital stock | +1.38 | +0.34 | +1.0 |
| `pW` | −0.94 | −0.75 | +1.0 |
| `qHhWealth` | −3.05 | −3.08 | +1.0 |
| employment | 0.0 | 0.0 | 0.0 |

The second column adds a closure that holds `vNetFinAssets[:NonFinCorp]` on its
baseline path and lets the corporate payout rate adjust. That closure moves about
36 000 MEUR of the counterpart from the corporate sector to the rest of the
world. It changes the real side by a lot. It leaves household wealth alone:
−3.05 against −3.08.

Household wealth is invariant to where the counterpart sits. That result told us
the drain is not the government, and not the corporate budget.

## Problem 1: household wealth has a unit root

This is the main problem.

Real household wealth is net financial assets and nothing else:

```julia
# ConsumptionSavingsDecision.jl:86
qHhWealth[t=t1:T], pC[t] * qHhWealth[t] == vNetFinAssets[:Hh,t]
```

It holds no capital, and no present value of future wages. It enters utility as a
level, so consumption depends on the level directly:

```julia
# ConsumptionSavingsDecision.jl:95-98
dU2dWealth[t=t1:T], dU2dWealth[t] * qHhWealth[t]^eHhWealth == uHhWealthPreference

qC[t=t1:(T-1)], dU2dC[t] == dU2dWealth[t]
  + βHh * (1 + mHhReturn[t+1]) * pC[t] / (pC[t+1]*fp) * dU2dC[t+1]*fq^(-eHhConsumption)
```

Households never transact in equity:

```julia
# Households.jl:69, before our change
vFinPosition_s_f[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T], vFinTransactions_f[s,f,al,t] == 0
```

Their capital gain is the pooled issuer average, and the pool counts the rest of
the world as an issuer:

```julia
# FinancialRevaluations.jl:23
const equity_issuer = [:NonFinCorp, :FinCorp, :RoW]

# FinancialRevaluations.jl:81-82
rFinReval_s_f[s=sector, f=[:Equity], al=[:Assets], t=t1:T],
rFinReval_s_f[s,f,al,t] == rFinReval_f[f,t]
```

Now put the two together. The stock change identity in adjusted units is

```
position[t] = position[t-1]/fv + transactions[t] + reval[t] + otherVolume[t]
reval[t]    = rFinReval * position[t-1]/fv
```

With zero transactions, a constant adjusted stock needs
`rFinReval = fv - 1`. The revaluation rate does nothing but cancel the division
by `fv`. **The adjusted stock therefore has a unit root.** A lower stock gives a
smaller revaluation, which gives a lower stock. Nothing pulls it back.

The measurements agree:

| year | `vNetFinTransactions[:Hh]` | `vNetFinReval[:Hh]` | `vFinReval_s_f[:Hh,:Equity,:Assets]` |
|---|---|---|---|
| 2070 | +957 | −1987 | −1987 |
| 2073 | +1003 | −2030 | −2030 |
| 2075 | +1071 | −2095 | −2095 |

Read the first two columns together. Consumption value falls 3.29 percent while
wage income falls 0.75 percent, so households **save more** than in baseline, and
`vNetFinTransactions` is positive in every year. Their wealth still falls. Saving
cannot do that. Only revaluation can.

Read the last two columns. They are equal to the last digit. The whole net
revaluation is the equity item. Debt contributes nothing.

The source of the hit is small and permanent. `rFinReval_f[:Equity]` deviates by
−0.00031 in 2070 and by −0.00041 in 2075. It gets worse, and it does not return
to zero. Applied to a large stock, that is about −2000 MEUR each year, and about
−69 447 MEUR by 2070. Nothing has settled at `T`.

The trigger in this shock is foreign equity issuance. `:RoW` issues 2292 MEUR more
equity each year. All owners share one average rate, so more foreign issuance
lowers the capital gain of resident households. That is bookkeeping with no
economic content: in a market, new foreign shares change what households own, not
the value of each share they already hold.

**The general consequence is worse than this one shock. Any shock that moves the
pooled revaluation rate gives a permanent and arbitrary level shift in household
wealth, and consumption depends on that level.** A terminal year value is a point
on a drifting path, not a long run answer.

## Problem 2: firm value is a balance sheet residual

Corporate equity value does not track the capital stock. It is the residual of
the balance sheet:

```julia
# Corporations.jl:154-157
vFinPosition_s_f[s=[:NonFinCorp], f=[:Equity], al=[:Liab], t=t1:T],
vNetFinAssets[s,t] == ∑(vFinPosition_s_f[s,f,:Assets,t] for f in fin_instrument)
                    - ∑(vFinPosition_s_f[s,f,:Liab,t] for f in fin_instrument)
```

The measured result, in percent:

| variable | deviation |
|---|---|
| `vFinPosition_s_f[:NonFinCorp,:Equity,:Liab]` | +0.079 |
| `vFinPosition_s_f[:NonFinCorp,:Debt,:Liab]` | −0.135 |
| `vK_s[:NonFinCorp]` | −0.135 |
| `vFinPosition_s_f[:NonFinCorp,:Debt,:Assets]` | −0.162 |
| `vNonFinCorpExpenses` | −0.162 |

Debt liabilities and the capital value move by the same amount, because a fixed
ratio ties them. Debt assets and expenses do the same. Firm value moves by +0.08
percent while the physical capital stock rises 0.34 percent. Tobin's q falls while
investment rises. That is not consistent.

`FinancialRevaluations.jl:85-88` holds the correct present value equation, but a
shock leaves `rFirmRequiredReturn_s` exogenous at 0.08. In a steady state the
equation gives a multiple of `fv/(1 + r - fv)`, which is `1.0302/0.0498 = 20.7`.
A small permanent change in the dividend less issue flow moves firm value about
twenty one times as much. `mHhReturn` did not move in either run, so no arbitrage
ties the household discount rate to the firm required return.

## Problem 3: the wage magnifies the demand gap

The top nest is tied to output by two exogenous terms:

```julia
# Production.jl:119-120
qProd[n=node, i=industry, t=t1:T; n == topNest[i]],
qProd[n,i,t] - qFixedCost_i[i,t] - qProductionLoss[i,t] == qTop2qY[i,t] * qY_i[i,t]
```

`qTop2qY` and `qFixedCost_i` are both `ForecastConstant`, so the input bundle
moves with output at a fixed rate. Labor demand in the nest is

```
dln q_L = dln u'_L + dln Q + e * (dln P - dln p_W)
```

Set `dln q_L = 0`, because employment is fixed. With `e = 0.7` and a labor share
in the nest near 0.5, this gives about `dln p_W = (dln Q - 0.65%) / 0.35`. **A one
percent output shortfall needs about a three percent wage fall.** The gain is
`1 / ((1 - e) * s_L)`, near 2.9.

The wage number is therefore a symptom with a gain near three. The measured
−0.75 percent corresponds to gross output growing about 0.27 percent instead of
one percent. Do not tune the labor market to fix it.

## Problem 4: exogenous levels do not scale

A productivity gain is only a clean scaling of the economy if every exogenous
level scales with it. These do not:

- `qCTouristMarket`
- `qFixedCost_i`
- real transfers: `vSocialBenefits`, `vNetPensionSaving`, `vOtherTransfers`
- `vntProductionOther_i`
- opening financial stocks at `t1-1`

Each one is small on its own. Together they stop the model from reproducing a
known answer, and they make every channel hard to read.

**We suggest a pure scale test before any further work on this shock.** Raise all
exogenous quantity levels by one percent, labor supply included. The answer is
known in advance: each real quantity rises one percent, and each price stays put.
Every line that misses one percent names an inhomogeneous variable directly. The
productivity shock mixes that question with a second one, and it cannot separate
them.

## What we changed, and what happened

We replaced the zero transaction rule in `Households.jl` with a share rule, so
households buy their share of new issues:

```julia
vFinPosition_s_f[s=[:Hh], f=[:Equity], al=[:Assets], t=t1:T],
vFinPosition_s_f[s,f,al,t] ==
  rHhEquityAssets2TotalEquity[t] * ∑(vFinPosition_s_f[s2,f,:Liab,t] for s2 in sector)
```

The endogenous variable does not change, and transactions stay the residual of
the stock change identity. Those transactions are the purchases.

We first made the same change for `:FinCorp`. That does not work. FinCorp equity
appears on both sides within one period, because its own liability is the balance
sheet residual and sits inside the total. The solution must then invert a factor
near `1 - φ_F/(1 + r_DL2EL)`, and FinCorp has large cross holdings and high
leverage. CONOPT stalled. Before the change it reached a feasible point in three
iterations with full Newton steps. After it, the step collapsed at each iteration,
0.11, 0.20, 0.10, 0.068, 0.042, 0.025, 0.015, 0.0087, 0.0052, 0.0040, 0.0020, and
the infeasibility stopped falling near 61. More time does not help. We reverted
the FinCorp rule and left a comment at `Corporations.jl:123`.

The household share rule alone is triangular, because households do not issue
equity of any size, so the total does not depend on them.

This work is not finished. The household rule removes the dilution, but `:FinCorp`
keeps its unit root, and it was the second largest loss at −46 898 MEUR. Its
equity liability is a balance sheet residual inside the total that households now
follow, so part of the leak still reaches them.

## Suggested order of work

1. Run the pure scale test. Fix the inhomogeneous exogenous levels in Problem 4.
   This is cheap and it removes noise from every later reading.
2. Anchor `rFirmRequiredReturn_s` to `mHhReturn`. This gives firm value an
   economic anchor instead of a bookkeeping residual, and it fixes `:FinCorp` and
   `:NonFinCorp` at the same time. A portfolio rule cannot do this.
3. Decide what household wealth should measure. If consumption is to respond to
   wealth as a level, the wealth measure has to include a claim on the capital
   stock. If it is not, the level term belongs out of the utility function.

Item 2 is the one we would do first if only one is possible. It is the reason the
financial block cannot price a larger capital stock.

## How to reproduce

`model_julia/Shock2.jl` holds the shock, the fiscal closure, and the diagnostic
tables that produced every number above. Run the whole file. Each
`@endo_exo_swap!` changes `block` in place, so a partial run gives a different
model.
