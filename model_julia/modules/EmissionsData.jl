# Fetch the air emissions account from Eurostat and the burned fuel from PEFA.
# Split CO2 into a part from fuel and a rest, check the result, and write emissions.csv.
# Keep the source settings in EmissionsSettings.jl and the model equations in Emissions.jl.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("EnergyBalanceSettings.jl")
include("EmissionsSettings.jl")
include("EurostatClient.jl")
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module EmissionsData

using CSV
using DataFrames
using DataFramesMeta

import ..DataUtils: long_format, sum_by
import ..EurostatClient
import ..Settings: calibration_year, country_code, first_data_year
import ..InputOutputSettings: industry_members, source_industry
import ..EnergyBalanceSettings:
  canonical_activity_code,
  eurostat_pefa_dataset,
  household_purpose,
  households,
  industry_source,
  pj_per_source_unit,
  source_household,
  source_product,
  source_unit,
  unspecified,
  use_flow
import ..EmissionsSettings:
  abroad_mode,
  biogenic_co2,
  bridge_item,
  co2_equivalent_gas,
  co2_kg_per_tj,
  economy_total,
  emissions_data_dir,
  emission_relevant_flow,
  emission_unit,
  eurostat_air_dataset,
  eurostat_bridge_dataset,
  fossil_co2,
  inventory_total,
  kt_per_pj_per_kg_per_tj,
  lulucf_total,
  max_negative_rest_share,
  no_co2_product,
  reported_total,
  residence_total,
  resident_abroad_total,
  source_gas,
  sum_atol,
  warming_potential,
  warming_potential_rtol,
  waste_product



const data_year = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_year]


# ==========================================
# Source
# ==========================================

""" Stop the build when the country omits a code the account needs."""
function assert_published(name, wanted, reported)
  unpublished = setdiff(wanted, reported)
  @assert isempty(unpublished) "$country_code publishes no $name: $unpublished"
end

"""
Fetch the air emissions account in kilotonnes.

Filter only what every row must share. 
A server-side `airpol` (gas) or `nace_r2` (activity) filter returns an empty response
for a code the country omits, which is then indistinguishable from a zero.
"""
function fetch_air()
  df = EurostatClient.fetch_table(
    eurostat_air_dataset,
    "unit" => emission_unit,
    "geo" => country_code,
    year_params...,
  )
  assert_published("air emissions gas", source_gas, df.airpol)
  assert_published("air emissions household purpose", source_household, df.nace_r2)
  assert_published("air emissions year", string.(data_year), df.time)
  return df
end

"""
Fetch the burned fuel from PEFA in petajoules.

Most fuel counts as burned through emission-relevant use. Waste counts through all of its use,
because incineration plants can book it as transformation use. As for the air account,
filter only what every row must share.
"""
function fetch_burned_fuel()
  df = EurostatClient.fetch_table(
    eurostat_pefa_dataset,
    "unit" => source_unit,
    "geo" => country_code,
    "stk_flow" => emission_relevant_flow,
    "stk_flow" => use_flow,
    year_params...,
  )
  assert_published("PEFA year", string.(data_year), df.time)
  burned = @rsubset(df, :stk_flow == burned_flow(:prod_nrg))
  assert_published("PEFA burned fuel", [r.product for r in co2_kg_per_tj], burned.prod_nrg)
  burned.value .*= pj_per_source_unit
  return burned
end

# The PEFA flow that counts as burned for a product.
burned_flow(product) = product in waste_product ? use_flow : emission_relevant_flow


# ==========================================
# Model labels
# ==========================================

# Emissions come from industries and households only.
const model_account = [source_industry; households]


# Map source activity codes to model accounts. Households appear once per purpose, and every industry takes the purpose `unspecified`.
# Totals and the boundary accounts are not in the lookup, so they drop out.
function account_purpose(published, source)
  industry = Dict(code => (activity = label, purpose = unspecified) for (code, label) in industry_source(published, source))
  household = Dict(code => (activity = households, purpose = p) for (code, p) in household_purpose)
  lookup = merge(industry, household)
  @assert length(lookup) == length(industry) + length(household) "each source account needs one label"
  return lookup
end


"""Map the air emissions account to model labels, and keep the gases the module reads."""
function map_air(df)
  df = @rtransform(df, :nace_r2 = canonical_activity_code(:nace_r2))
  lookup = account_purpose(Set(df.nace_r2), "air emissions")
  mapped = @chain df begin
    @rsubset(haskey(lookup, :nace_r2) && :airpol in source_gas)
    @rtransform begin
      :gas = Symbol(:airpol)
      :activity = lookup[:nace_r2].activity
      :purpose = lookup[:nace_r2].purpose
      :year = parse(Int, :time)
    end
    @select(:gas, :activity, :purpose, :year, :value)
  end
  assert_published("mapped air emissions account", model_account, mapped.activity)
  return mapped
end

"""Map the burned fuel to model labels, and keep the products, not the product totals."""
function map_burned(df)
  df = @rtransform(df, :nace_r2 = canonical_activity_code(:nace_r2))
  lookup = account_purpose(Set(df.nace_r2), "PEFA")
  @chain df begin
    @rsubset(haskey(lookup, :nace_r2) && :prod_nrg in source_product)
    @rtransform begin
      :product = Symbol(:prod_nrg)
      :activity = lookup[:nace_r2].activity
      :purpose = lookup[:nace_r2].purpose
      :year = parse(Int, :time)
    end
    @select(:product, :activity, :purpose, :year, :value)
  end
end


# ==========================================
# Check on the air emissions account
# ==========================================

"""The source's own economy total, per gas and year."""
function economy_by_gas(raw)
  @chain raw begin
    @rsubset(:nace_r2 == economy_total && :airpol in source_gas)
    @rtransform(:gas = Symbol(:airpol), :year = parse(Int, :time))
    @select(:gas, :year, :economy = :value)
  end
end

"""
Assert that the model accounts add up to the source's economy total, gas by gas.

If they do, the mapping has lost no emissions and counted none twice.
"""
function assert_accounts_add_up(raw, mapped)
  economy = economy_by_gas(raw)
  accounts = rename(sum_by(mapped, [:gas, :year]), :value => :accounts)
  joined = innerjoin(economy, accounts, on = [:gas, :year])
  @assert nrow(joined) == nrow(economy) "each gas and year needs an economy total and model accounts"
  gaps = @rsubset(joined, !isapprox(:accounts, :economy; atol = sum_atol))
  @assert isempty(gaps) "The model accounts do not add up to the economy total: \n$gaps"
  return nothing
end

"""
Assert that the reported greenhouse gas total equals its six parts, in every account and year.

The total is read beside its parts, so a gap between them must be seen, not hidden.
"""
function assert_reported_total(mapped)
  parts = @chain mapped begin
    @rsubset(string(:gas) in co2_equivalent_gas)
    sum_by([:activity, :purpose, :year])
    rename(:value => :parts)
  end
  total = @chain mapped begin
    @rsubset(:gas == Symbol(reported_total))
    @select(:activity, :purpose, :year, :total = :value)
  end
  joined = innerjoin(total, parts, on = [:activity, :purpose, :year])
  @assert nrow(joined) == nrow(total) "each account needs a reported total and its parts"
  gaps = @rsubset(joined, !isapprox(:total, :parts; atol = sum_atol))
  @assert isempty(gaps) "The reported greenhouse gas total differs from its parts:\n$gaps"
  return nothing
end

"""
Assert that the source uses the warming potentials the module expects.

The source reports methane and nitrous oxide both in tonnes of gas and in CO2 equivalents,
so their ratio at the economy total is the warming potential it used.
"""
function assert_warming_potential(raw)
  economy = economy_by_gas(raw)
  value = Dict((r.gas, r.year) => r.economy for r in eachrow(economy))
  implied(w, year) = value[(Symbol(w.co2_equivalent), year)] / value[(Symbol(w.gas), year)]
  wrong = [(w.gas, year, implied(w, year)) for w in warming_potential for year in data_year
           if !isapprox(implied(w, year), w.factor; rtol = warming_potential_rtol)]
  @assert isempty(wrong) "The source implies other warming potentials (gas, year, ratio): $wrong"
  return nothing
end

# ==========================================
# CO2 from fuel
# ==========================================

# The CO2 factor of each product in kt/PJ, and the gas it gives. The table is converted here, once.
const co2_factor = Dict(
  Symbol(r.product) => (gas = Symbol(r.gas), kt_per_pj = r.kg_per_tj * kt_per_pj_per_kg_per_tj)
  for r in co2_kg_per_tj
)

"""
CO2 from burned fuel, per gas, product, account and year.

Every burned product needs a factor or must give no CO2. A burned fuel with neither
would drop out here, and its CO2 would land in the rest without a sign.
"""
function fuel_co2(burned)
  used = Set(burned.product[burned.value .!= 0])
  unfactored = setdiff(used, keys(co2_factor), Symbol.(no_co2_product))
  @assert isempty(unfactored) "burned fuel without a CO2 factor: $unfactored"
  @chain burned begin
    @rsubset(haskey(co2_factor, :product) && !iszero(:value))
    @rtransform begin
      :gas = co2_factor[:product].gas
      :value = :value * co2_factor[:product].kt_per_pj
    end
    @select(:gas, :product, :activity, :purpose, :year, :value)
  end
end


# ==========================================
# Fossil CO2 not from fuel
# ==========================================

# The deepest lag in the model is two periods, so an equation at t1 reads back to
# calibration_year - 2. Earlier years are loaded, but not checked.
const first_checked_year = calibration_year - 2

"""
Fossil CO2 not from fuel, per account and year: the reported CO2 minus the CO2 from burned fuel.
"""
function fossil_rest(mapped, fuel)
  reported = @chain mapped begin
    @rsubset(:gas == Symbol(fossil_co2))
    @select(:activity, :purpose, :year, :reported = :value)
  end
  from_fuel = @chain fuel begin
    @rsubset(:gas == Symbol(fossil_co2))
    sum_by([:activity, :purpose, :year])
    rename(:value => :fuel)
  end
  rest = outerjoin(reported, from_fuel, on = [:activity, :purpose, :year])
  @assert !any(ismissing, rest.reported) "fuel CO2 in an account with no reported CO2"
  rest.fuel = coalesce.(rest.fuel, 0.0)
  @rtransform!(rest, :value = :reported - :fuel)
  return rest
end

"""
Assert that no fossil rest is below the limit, and report the negative rests that are kept.

Years before first_checked_year are not checked.
"""
function assert_rest_limit(rest)
  checked = @rsubset(rest, :year >= first_checked_year)
  national = Dict(r.year => r.value for r in eachrow(sum_by(@select(checked, :year, :value = :reported), [:year])))
  too_low = @rsubset(checked, :value < -max_negative_rest_share * national[:year])
  @assert isempty(too_low) "A fossil rest is below the limit, so a factor or a mapping is wrong:\n$too_low"
  negative = @rsubset(checked, :value < 0)
  @info "Negative fossil rests, kept as they are:"
  show(negative; allrows = true)
  println()
  return nothing
end

"""
Report how far biogenic CO2 from fuel is from the source's own figure.

Biogenic CO2 has no rest: the module uses fuel times factor. The source's figure is a check
only, so the gap is reported for the whole economy and for the accounts with the largest gaps.
"""
function report_biogenic_gap(mapped, fuel)
  reported = @chain mapped begin
    @rsubset(:gas == Symbol(biogenic_co2) && :year >= first_checked_year)
    sum_by([:activity, :year])
    rename(:value => :reported)
  end
  from_fuel = @chain fuel begin
    @rsubset(:gas == Symbol(biogenic_co2) && :year >= first_checked_year)
    sum_by([:activity, :year])
    rename(:value => :fuel)
  end
  gap = outerjoin(reported, from_fuel, on = [:activity, :year])
  gap.reported = coalesce.(gap.reported, 0.0)
  gap.fuel = coalesce.(gap.fuel, 0.0)
  @rtransform!(gap, :gap = :fuel - :reported)
  national = combine(groupby(gap, :year), :reported => sum => :reported, :fuel => sum => :fuel)
  @rtransform!(national, :percent = 100 * (:fuel - :reported) / :reported)
  @info "Biogenic CO2 from fuel against the source, whole economy:"
  show(national; allrows = true)
  println()
  largest = first(sort(@rsubset(gap, :year == calibration_year), :gap; by = abs, rev = true), 5)
  @info "Largest biogenic gaps in $calibration_year:"
  show(largest; allrows = true)
  println()
  return nothing
end


# ==========================================
# Variables
# ==========================================

"""
Build the variables the model reads.

Households are summed over purpose in every variable but `by_purpose`, which keeps the split.
Exact zeros go out, as in the energy account: a cell with no flow needs no variable.
Negative rests stay.
"""
function emission_variables(mapped, burned, fuel, rest)
  part = Symbol.(co2_equivalent_gas)
  by_purpose = @rsubset(mapped, (:gas in part || :gas == Symbol(biogenic_co2)) && !iszero(:value))
  reported = sum_by(by_purpose, [:gas, :activity, :year])
  co2e = @chain mapped begin
    @rsubset(:gas == Symbol(reported_total) && !iszero(:value))
    sum_by([:activity, :year])
  end
  from_fuel = sum_by(fuel, [:gas, :product, :activity, :year])
  co2_rest = @chain rest begin
    sum_by([:activity, :year])
    @rtransform(:gas = Symbol(fossil_co2))
    @select(:gas, :activity, :year, :value)
  end
  other_gas = @rsubset(reported, :gas in part && :gas != Symbol(fossil_co2))
  not_fuel = @rsubset(vcat(co2_rest, other_gas), !iszero(:value))
  burned_fuel = @rsubset(sum_by(burned, [:product, :activity, :year]), !iszero(:value))
  sort!(reported, [:activity, :gas, :year])
  sort!(by_purpose, [:activity, :gas, :purpose, :year])
  sort!(co2e, [:activity, :year])
  sort!(from_fuel, [:activity, :gas, :product, :year])
  sort!(not_fuel, [:activity, :gas, :year])
  sort!(burned_fuel, [:activity, :product, :year])
  return (; reported, by_purpose, co2e, from_fuel, not_fuel, burned_fuel)
end


# ==========================================
# Reconciliation to the inventory
# ==========================================

"""Fetch the bridge from the air emissions account to the inventory, in kilotonnes."""
function fetch_bridge()
  df = EurostatClient.fetch_table(
    eurostat_bridge_dataset,
    "unit" => emission_unit,
    "geo" => country_code,
    year_params...,
  )
  code = [residence_total; inventory_total; lulucf_total; resident_abroad_total; [c for r in bridge_item for c in r.code]]
  assert_published("bridge gas", [co2_equivalent_gas; reported_total], df.airpol)
  assert_published("bridge code", code, df.indic_env)
  assert_published("bridge year", string.(data_year), df.time)
  return df
end


"""A lookup in the bridge table: cell(gas, code, year) gives the value, or zero if the cell is absent."""
function bridge_lookup(bridge)
  value = Dict((r.airpol, r.indic_env, parse(Int, r.time)) => r.value for r in eachrow(bridge))
  return (gas, code, year) -> get(value, (gas, code, year), 0.0)
end



"""
The five reconciliation items for one gas and year.

Other differences is what is left once the other items are subtracted,
so the territorial total meets the inventory exactly.
"""
function bridge_rows(cell, gas, year)
  residence = cell(gas, residence_total, year)
  direct = [(item = r.item, value = r.sign * sum(cell(gas, c, year) for c in r.code)) for r in bridge_item]
  lulucf = cell(gas, lulucf_total, year)
  inventory = cell(gas, inventory_total, year) - lulucf
  other = residence - sum(d.value for d in direct) - inventory
  return [direct; (item = :OtherDifferences, value = other); (item = :LULUCF, value = lulucf)]
end

"""The reconciliation items per gas and year, for the six parts of the greenhouse gas total."""
function reconciliation_items(bridge)
  cell = bridge_lookup(bridge)
  return DataFrame([(item = b.item, gas = Symbol(gas), year = year, value = b.value)
                    for gas in co2_equivalent_gas for year in data_year for b in bridge_rows(cell, gas, year)])
end


"""
Assert that the bridge starts from the air account's economy total, and that bunkering and
aviation hold every transport mode, so none can hide in other differences.
"""
function assert_bridge(bridge, raw)
  cell = bridge_lookup(bridge)
  start = [(r.gas, r.year) for r in eachrow(economy_by_gas(raw))
           if string(r.gas) in co2_equivalent_gas &&
              !isapprox(cell(string(r.gas), residence_total, r.year), r.economy; atol = sum_atol)]
  @assert isempty(start) "The bridge starts from another total than the air emissions account (gas, year): $start"
  mode = [c for r in bridge_item for c in r.code if startswith(c, resident_abroad_total)]
  lost = [(gas, year) for gas in co2_equivalent_gas for year in data_year
          if !isapprox(sum(cell(gas, c, year) for c in mode), cell(gas, resident_abroad_total, year); atol = sum_atol)]
  @assert isempty(lost) "Bunkering and aviation miss a transport mode (gas, year): $lost"
  return nothing
end



"""The model industry whose members hold a NACE code."""
function industry_holding(nace)
  holder = [i for (i, members) in industry_members if nace in members]
  @assert length(holder) == 1 "$nace must belong to one industry group, not $holder"
  return only(holder)
end

"""
Residents' emissions abroad per item, gas, industry and year.

Each transport mode goes to the industry that buys its fuel abroad.
The model can then let bunkering and aviation follow the emissions of their own industry.
"""
function abroad_items(bridge)
  cell = bridge_lookup(bridge)
  item_of = Dict(c => r.item for r in bridge_item for c in r.code)
  rows = DataFrame([
    (item = item_of[m.code], gas = Symbol(gas), activity = industry_holding(m.nace), year = year, value = cell(gas, m.code, year))
    for m in abroad_mode for gas in co2_equivalent_gas for year in data_year
  ])
  return sum_by(rows, [:item, :gas, :activity, :year])
end

"""
Assert that no industry buys more emissions abroad than it emits, per gas and year.

The model subtracts them from that industry's emissions on the way to the inventory,
so more than all of them would give the industry a negative emission on the territory.
"""
function assert_abroad_share(abroad, mapped)
  own = rename(sum_by(mapped, [:gas, :activity, :year]), :value => :own)
  joined = leftjoin(sum_by(abroad, [:gas, :activity, :year]), own, on = [:gas, :activity, :year])
  too_high = @rsubset(joined, :value > coalesce(:own, 0.0) + sum_atol)
  @assert isempty(too_high) "An industry buys more emissions abroad than it emits:\n$too_high"
  return nothing
end


"""
The four economy totals for one gas and year, named as in the GAMS model.

GNA follows the residence principle, and UNFCCC is the inventory reported to the UN.
Each also comes with land use.
"""
function inventory_rows(cell, gas, year)
  residence = cell(gas, residence_total, year)
  lulucf = cell(gas, lulucf_total, year)
  inventory = cell(gas, inventory_total, year)
  return [
    (inventory = :GNA, value = residence),
    (inventory = :GNA_LULUCF, value = residence + lulucf),
    (inventory = :UNFCCC, value = inventory - lulucf),
    (inventory = :UNFCCC_LULUCF, value = inventory),
  ]
end

"""The four economy totals per gas and year, for the six parts and the reported greenhouse gas total."""
function economy_totals(bridge)
  cell = bridge_lookup(bridge)
  return DataFrame([(gas = Symbol(gas), inventory = r.inventory, year = year, value = r.value)
                    for gas in [co2_equivalent_gas; reported_total] for year in data_year for r in inventory_rows(cell, gas, year)])
end



# ==========================================
# Refresh
# ==========================================

"""
Fetch both sources, check them, and split CO2 into a part from fuel and a rest.
"""
function refresh_emissions_data!(dir = emissions_data_dir)
  mkpath(dir)
  raw = fetch_air()
  mapped = map_air(raw)
  assert_accounts_add_up(raw, mapped)
  assert_reported_total(mapped)
  assert_warming_potential(raw)
  burned = map_burned(fetch_burned_fuel())
  fuel = fuel_co2(burned)
  rest = fossil_rest(mapped, fuel)
  assert_rest_limit(rest)
  report_biogenic_gap(mapped, fuel)
  bridge = fetch_bridge()
  assert_bridge(bridge, raw)
  items = reconciliation_items(bridge)
  abroad = abroad_items(bridge)
  assert_abroad_share(abroad, mapped)
  totals = economy_totals(bridge)
  bridge_variable(item) = sort!(@rsubset(items, :item == item && !iszero(:value)), [:gas, :year])
  abroad_variable(item) = sort!(@rsubset(abroad, :item == item && !iszero(:value)), [:gas, :activity, :year])
  gas_total = sort!(@rsubset(totals, :gas != Symbol(reported_total) && !iszero(:value)), [:gas, :inventory, :year])
  co2e_total = sort!(@rsubset(totals, :gas == Symbol(reported_total) && !iszero(:value)), [:inventory, :year])
  cells = emission_variables(mapped, burned, fuel, rest)
  # Index letters: `g` is the gas, `e` the fuel, `m` the purpose, `d` the account and `b` the inventory,
  # as in the energy account. The names follow the GAMS model: `qEmmE` is CO2 from fuel,
  # and `qEmmxE` holds the emissions not from fuel.
  CSV.write(joinpath(dir, "emissions.csv"), vcat(
    long_format(:qEmm_g_d, cells.reported, [:gas, :activity, :year]),
    long_format(:qEmm_g_m_d, cells.by_purpose, [:gas, :purpose, :activity, :year]),
    long_format(:qEmmCO2e_d, cells.co2e, [:activity, :year]),
    long_format(:qEmmE_g_e_d, cells.from_fuel, [:gas, :product, :activity, :year]),
    long_format(:qEmmxE_g_d, cells.not_fuel, [:gas, :activity, :year]),
    long_format(:qEBurned_e_d, cells.burned_fuel, [:product, :activity, :year]),
    long_format(:qEmmBunkering_g_d, abroad_variable(:Bunkering), [:gas, :activity, :year]),
    long_format(:qEmmInternationalAviation_g_d, abroad_variable(:InternationalAviation), [:gas, :activity, :year]),
    long_format(:qEmmBorderTrade_g, bridge_variable(:BorderTrade), [:gas, :year]),
    long_format(:qEmmOtherDifferences_g, bridge_variable(:OtherDifferences), [:gas, :year]),
    long_format(:qEmmLULUCF_g, bridge_variable(:LULUCF), [:gas, :year]),
    long_format(:qEmmTot_g_b, gas_total, [:gas, :inventory, :year]),
    long_format(:qEmmTotCO2e_b, co2e_total, [:inventory, :year]),
  ))
  return nothing
end






end # module EmissionsData


if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  EmissionsData.refresh_emissions_data!()
end

