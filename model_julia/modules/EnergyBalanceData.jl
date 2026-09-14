# Fetch the physical energy account from Eurostat PEFA.
# Convert terajoules to petajoules, map source codes to model labels, and check
# that supply equals use for each resident account.
# Keep emission factors and the model equations in other modules.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("EnergyBalanceSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module EnergyBalanceData

using DataFrames
using DataFramesMeta
using CSV


import ..DataUtils: long_format, sum_by
import ..EurostatClient
import ..Settings: calibration_year, country_code, first_data_year
import ..EnergyBalanceSettings:
  activity_balance_atol,
  activity_balance_rtol,
  boundary_account,
  discrepancy_product,
  energy_balance_data_dir,
  eurostat_pefa_dataset,
  household_purpose,
  households,
  pj_per_source_unit,
  section,
  section_to_industry,
  source_activity,
  source_boundary,
  source_industry,
  source_product,
  source_unit,
  supply_flow,
  unspecified,
  use_flow

const data_years = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_years]

# ==========================================
# Source
# ==========================================

""" Stop the build when the country omits a code the account needs."""
function assert_published(name, wanted, reported)
  unpublished = setdiff(wanted, reported)
  @assert isempty(unpublished) "$country_code publishes no PEFA $name: $unpublished"
end

""" 
Fetch the PEFA supply and use table in petajoules.

Filter only what every row must share. A server-side `prod_nrg` or `nace_r2`
filter returns an empty response for a code the country omits, which is then indistinguishable 
from a zero.
"""
function fetch_pefa()
  df = EurostatClient.fetch_table(
    eurostat_pefa_dataset,
    "unit" => source_unit,
    "geo" => country_code,
    "stk_flow" => supply_flow,
    "stk_flow" => use_flow,
    year_params...,
  )
  assert_published("product", source_product, df.prod_nrg)
  assert_published("activity", [source_activity; source_boundary], df.nace_r2)
  assert_published("year", string.(data_years), df.time)
  df.value .*= pj_per_source_unit
  return df
end


# ==========================================
# Model labels
# ==========================================

# PEFA names an account, not a purpose. Households appear three times, once per purpose.
# Every other account appears once and takes :unspecified.
const activity_purpose = merge(
  Dict(string(s) => (activity = section_to_industry[s], purpose = unspecified) for s in section),
  Dict(code => (activity = households, purpose = p) for (code, p) in household_purpose),
  Dict(code => (activity = a, purpose = unspecified) for (code, a) in boundary_account),
)
@assert length(activity_purpose) == length(source_activity) + length(source_boundary) "each source account needs one label"


const balance_name = Dict(supply_flow => :supply, use_flow => :use)

# SD_IO is not an energy product, so it stays out of source_product. The balance
# needs it: it is where a country books the gap when supply and use do not close.
const balance_product = [source_product; discrepancy_product]

# Membership runs once per row, so a Set rather than the ordered vector.
const wanted_product = Set(balance_product)

const model_activity = [source_industry; households; collect(values(boundary_account))]

"""
Map PEFA codes to model labels and drop what the account does not use.

The 61 NACE sub-details and the five product aggregates fall out here, because
neither lookup holds them. PEFA reports them beside the cells, so keeping them
would count the same energy twice. `SD_IO` is kept: it is a discrepancy, not an
aggregate, and the balance does not close without it outside Denmark.
"""
function map_to_model(df)
  mapped = @chain df begin
    @rsubset(haskey(activity_purpose, :nace_r2) && :prod_nrg in wanted_product)
    @rtransform begin
      :balance = balance_name[:stk_flow]
      :product = Symbol(:prod_nrg)
      :activity = activity_purpose[:nace_r2].activity
      :purpose = activity_purpose[:nace_r2].purpose
      :year = parse(Int, :time)
    end
    @select(:balance, :product, :activity, :purpose, :year, :value)
  end
  assert_published("mapped activity", model_activity, mapped.activity)
  assert_published("mapped product", Symbol.(balance_product), mapped.product)
  return mapped
end


# ==========================================
# Balance
# ==========================================

# Energy is conserved, so each resident account gives out what it takes in.
# The boundary accounts are where energy enters and leaves the economy, so they
# do not balance and stay out: ROW_ACT use is 402.5 PJ against a Danish export of 
# 402.3 PJ, which is a real gap and not an error.
const resident_account = Set([source_industry; households])

# The deepest lag in the model is two periods (qK_k_i[t-2] in CapitalAdjustmentCosts.jl:58), so an equation
# at t1 reads back to calibration_year - 2. Earlier years are fetched and loaded, but no equation reads them, so a 
# source defect there must not stop the build. Sweden 2015 is an example: 52 PJ of use rows are unpublished.
# If a module adds a deeper lag, this number must follow it.
const first_checked_year = calibration_year - 2

""" 
Assert that supply equals use for each resident account.

The check runs per purpose, not per activity. PEFA publishes households three times and
each of the three balances on its own, so summing the purposes away first would let one purpose
cover  another one's gap.

`SD_IO` is inside the sum. Without it 12 of 34 countries fail in all sections.

Years before first_checked_year are loaded, but not checked.
"""
function assert_activity_balance(mapped)
  sides = @chain mapped begin
    @rsubset(:activity in resident_account && :year >= first_checked_year)
    @by([:activity, :purpose, :year, :balance], :value = sum(:value))
  end
  supply = @chain sides begin
    @rsubset(:balance == Symbol("supply"))
    @select(:activity, :purpose, :year, :supply = :value)
  end
  use = @chain sides begin
    @rsubset(:balance == Symbol("use"))
    @select(:activity, :purpose, :year, :use = :value)
  end
  joined = outerjoin(supply, use, on = [:activity, :purpose, :year])
  @assert nrow(joined) == nrow(supply) == nrow(use) "Each resident account needs  a supply and a use side"
  gaps = @rsubset(joined, !isapprox(:supply, :use; rtol = activity_balance_rtol, atol = activity_balance_atol))
  @assert isempty(gaps) "Physical energy does not balance for $(nrow(gaps)) resident accounts:\n$gaps"  
  return nothing
end


# ==========================================
# Refresh
# ==========================================

"""
Net SD_IO per resident account: supply minus use.

PEFA books SD_IO where a country's supply and use do not close, so it is what
makes the account balance. `assert_activity_balance` counts it. The model must
count it too, or the two functions assert different things: without it, 3 of
the 13 target countries fail the model test, the largest by 17.1 PJ in `iC`.
Denmark reports zero everywhere, which is why a Denmark-only build cannot see
the difference.

The table is dense, with zeros. The discrepancy is a correction per account
rather than a sparse flow, and a dense table makes Denmark run the same path as
the countries that need it.
"""
function discrepancy_by_account(mapped)
  signed = @chain mapped begin
    @rsubset(:activity in resident_account && :product == Symbol(discrepancy_product))
    @rtransform(:value = :balance == Symbol("supply") ? :value : -:value)
    sum_by([:activity, :year])
  end
  account = sort!(unique(a for a in mapped.activity if a in resident_account))
  year = sort!(unique(mapped.year))
  dense = DataFrame(
    activity = repeat(account, inner = length(year)),
    year = repeat(year, outer = length(account)),
  )
  discrepancy = leftjoin(dense, signed, on = [:activity, :year])
  discrepancy.value = coalesce.(discrepancy.value, 0.0)
  sort!(discrepancy, [:activity, :year])
  return discrepancy
end


"""
Split the mapped account into the four variables the model reads.

`SD_IO` goes out here. It closes the balance, but no model variable consumes a discrepancy. 
Exacy zeros go out too: PEFA reports them, and a cell with no flow needs no variable.
Negative cells stay - `CH_INV_PA` books a stock drawdown as negative use, which is physical, not an error.
"""
function energy_balance_variables(mapped)
  cells = @rsubset(mapped, :product != Symbol(discrepancy_product) && !iszero(:value))
  supply = @chain cells begin
    @rsubset(:balance == Symbol("supply"))
    sum_by([:product, :activity, :year])
  end
  use_by_purpose = @chain cells begin
    @rsubset(:balance == Symbol("use"))
    sum_by([:product, :purpose, :activity, :year])
  end
  use = sum_by(use_by_purpose, [:product, :activity, :year])
  shares = innerjoin(use_by_purpose, rename(use, :value => :total), on = [:product, :activity, :year])
  @assert nrow(shares) == nrow(use_by_purpose) "Each purpose cell needs its account total"
  shares.value = shares.value ./ shares.total
  totals = sum_by(shares, [:product, :activity, :year])
  @assert all(isapprox.(totals.value, 1.0; atol = 1e-9)) "Purpose shares must sum to one"
  sort!(supply, [:activity, :product, :year])
  sort!(use, [:activity, :product, :year])
  sort!(use_by_purpose, [:activity, :product, :purpose, :year])
  sort!(shares, [:activity, :product, :purpose, :year])
  return (; supply, use, use_by_purpose, shares)
end


function refresh_energy_balance_data!(dir = energy_balance_data_dir)
  mkpath(dir)
  mapped = map_to_model(fetch_pefa())
  assert_activity_balance(mapped)
  cells = energy_balance_variables(mapped)
  discrepancy = discrepancy_by_account(mapped)
  # Index letters: `e` is the energy product, `m` the purpose, `d` the account —
  # the 21 industries, households, and the three boundary accounts. `d` follows
  # the legacy GAMS model, where `qEpj[es,e,d,t]` indexes the same set. `a` is
  # taken by the consumption node in ConsumptionGroups.jl.
  CSV.write(joinpath(dir, "energy_balance.csv"), vcat(
    long_format(:qESupply_e_d, cells.supply, [:product, :activity, :year]),
    long_format(:qEUse_e_d, cells.use, [:product, :activity, :year]),
    long_format(:qEUse_e_m_d, cells.use_by_purpose, [:product, :purpose, :activity, :year]),
    long_format(:uEPurpose_e_m_d, cells.shares, [:product, :purpose, :activity, :year]),
    long_format(:qEDiscrepancy_d, discrepancy, [:activity, :year]),
  ))
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  EnergyBalanceData.refresh_energy_balance_data!()
end
