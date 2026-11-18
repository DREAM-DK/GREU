# Build the partial energy technology data from Louis's dummy data (Abatement_dummy_data.xlsx).
# Read one CSV per Excel sheet and write the model's long format.
# Hold each series at its last data year until the terminal year. An energy input without a price costs 0.
# Write money in million EUR, as in the CGE model. Louis's data are in billion EUR.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include(joinpath(@__DIR__, "..", "DataUtils.jl"))

module EnergyTechnologyData

using CSV
using DataFrames
import ..DataUtils: long_format
import ..Settings: calibration_year, terminal_year

const energy_technology_data_dir = joinpath(@__DIR__, "..", "data", "energy_technology")
const years = calibration_year:terminal_year

# Discount rate in the levelized cost
const discount_rate = 0.05

# Million EUR per billion EUR. Converts money to million EUR instead of billion EUR
const money_unit = 1000

const technology_keys = [:TechID, :Energy_service, :Industry]
const price_keys = [:Energy_service, :Energy_input, :Industry, :Year]

"""
Read one sheet. Column names keep their Excel text, with spaces as underscores.
Industry codes get the prefix i, as in the model (10030 to i10030). A plain number as the last index reads as a year.
"""
function read_sheet(name, dir = energy_technology_data_dir)
  df = CSV.read(joinpath(dir, "$name.csv"), DataFrame; stringtype = String)
  rename!(x -> replace(x, " " => "_"), df)
  "Industry" in names(df) && (df.Industry = "i" .* string.(df.Industry))
  return df
end

"""Lowercase a name and replace spaces and signs with _, such as "Natural gas incl. biongas" to natural_gas_incl_biongas."""
label(x) = strip(replace(lowercase(string(x)), r"[^a-z0-9]+" => "_"), '_')

"""
Rows of one series, multiplied by `scale`. Each year after the last data year gets the value of that year.
"""
function series(variable, df, keys, value_column; scale = 1.0)
  last_data_year = maximum(df.Year)
  rows = [
    (index = join([label.(row[k] for k in keys)..., year], ","), value = scale * Float64(row[value_column]))
    for row in eachrow(df)
    for year in (row.Year == last_data_year ? (row.Year:terminal_year) : (row.Year:row.Year))
    if year in years
  ]
  return long_format(variable, DataFrame(rows), [:index])
end

"""Life of each technology. Life must not vary by year."""
function technology_life(technologies)
  life = combine(groupby(technologies, technology_keys), "Technical_lifespan_(years)" => (x -> only(unique(x))) => :value)
  life.index = [join(label.((row.TechID, row.Energy_service, row.Industry)), ",") for row in eachrow(life)]
  return long_format("nTLife_l_es_d", life, [:index])
end

"""Add a price or tax to each energy input in use. An input without a value, such as captured CO2, gets 0."""
function by_input_in_use(used, df, value_column)
  joined = leftjoin(used, select(df, price_keys..., value_column => :value), on = price_keys)
  joined.value = coalesce.(joined.value, 0.0)
  return joined
end

function refresh_energy_technology_data!(dir = energy_technology_data_dir)
  technologies = read_sheet("technologies")
  energy_input = read_sheet("energy_input")
  energy_price = read_sheet("energy_price")
  energy_tax = read_sheet("energy_tax")
  capital_cost = read_sheet("capital_cost_index")
  energy_service = read_sheet("energy_service")

  # Energy input per PJ of service, wherever the technology has a potential.
  uTE = innerjoin(select(technologies, technology_keys..., :Year), energy_input, on = :TechID)
  @assert Set(uTE.TechID) == Set(technologies.TechID) "Each technology needs an energy input"
  used = unique(select(uTE, price_keys))

  life = technology_life(technologies)
  mkpath(dir)
  CSV.write(
    joinpath(dir, "energy_technology.csv"),
    vcat(
      series("rTPotential_l_es_d", technologies, technology_keys, "Potential_(Share_of_energy_demand)"),
      series("uTI_l_es_d", technologies, technology_keys, "Investment_costs_(billion_EUR_per_PJ_out)"; scale = money_unit),
      series("uTC_l_es_d", technologies, technology_keys, "Variable_capital_costs_(billion_EUR_per_PJ_out)"; scale = money_unit),
      life,
      DataFrame(variable = "rTDiscount_l_es_d", indices = life.indices, value = discount_rate),
      series("uTE_l_es_e_d", uTE, [:TechID, :Energy_service, :Energy_input, :Industry], "Energy_intensity_(PJ_in_per_PJ_out)"),
      series("pEBase_es_e_d", by_input_in_use(used, energy_price, "Energy_price_(billion_EUR_per_PJ_in)"),
        [:Energy_service, :Energy_input, :Industry], :value; scale = money_unit),
      series("tqE_es_e_d", by_input_in_use(used, energy_tax, "Energy_tax_(billion_EUR_per_PJ_in)"),
        [:Energy_service, :Energy_input, :Industry], :value; scale = money_unit),
      series("pTK_d", capital_cost, [:Industry], "Capital_cost_index"),
      series("qES_es_d", energy_service, [:Energy_service, :Industry], "Energy_service_(PJ_out)"),
    ),
  )
  return nothing
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  EnergyTechnologyData.refresh_energy_technology_data!()
end