# Static index definitions shared by InputOutput.jl and InputOutputData.jl
module InputOutputSettings

const input_output_data_dir = joinpath(@__DIR__, "..", "data", "input_output")

const eurostat_dataset = "naio_10_fcp_ii3"
const eurostat_unit = "MIO_EUR"
const national_accounts_dataset = "nama_10_gdp"
const gfcf_asset_dataset = "nama_10_an6"
const national_accounts_unit = "CP_MEUR"

const demand_rename = Dict(
  "P3_S14" => :cHh,
  "P3_S15" => :cHh,
  "P3_S13" => :g,
  "P52" => :equipment,
  "P5M" => :equipment,
  "P6" => :x,
)

const accounting_rename = Dict(
  "D21X31" => :vtYM_d,
  "D29X39" => :vtYOther_i,
  "D1" => :vW_i,
  "B2A3G" => :vOpSurplus_i,
)

# ind_ava labels in naio_10_fcp_ii3 that are not NACE industry rows
const accounting_ind_ava_codes = collect(keys(accounting_rename)) ∪ ["OP_RES", "OP_NRES"]

const accounting_rows = collect(values(accounting_rename))

const energy_types = [:energy]
const energy_type_by_supply_industry = Dict(:B => :energy, :D => :energy)
const capital_types = [:equipment, :structures]
const private_consumption_types = [:cHh]
const government_consumption_types = [:g]
const export_types = [:x]
const model_industries = [:A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K, :L, :M, :N, :O, :P, :Q, :R, :S, :T, :U]

all_demand_components(industries) = sort(unique(vcat(
  industries,
  private_consumption_types,
  government_consumption_types,
  capital_types,
  export_types,
  energy_types,
)))

end # module
