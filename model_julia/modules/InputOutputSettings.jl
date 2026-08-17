# Static input-output sets and source mappings.
module InputOutputSettings

const input_output_data_dir = joinpath(@__DIR__, "..", "data", "input_output")

const eurostat_dataset = "naio_10_fcp_ii3"
const eurostat_unit = "MIO_EUR"
const national_accounts_dataset = "nama_10_gdp"
const national_accounts_unit = "CP_MEUR"
const cell_tolerance = 1e-6

const model_industries = [
  :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K,
  :L, :M, :N, :O, :P, :Q, :R, :S, :T, :U,
]

# Keep the two roles separate. The first data build uses the same codes for both.
const I = copy(model_industries)
const P = copy(model_industries)

# Wholesale and retail trade, and transport, supply the margin services.
const S = [:G, :H]
# The source reports margins by service and use, not by carried product, so
# calibration anchors every margin rate on this product.
const margin_rate_reference = :A
@assert S ⊆ P && margin_rate_reference in P "Margin services must be products"

# Lower-case data labels keep final uses distinct from NACE section labels.
const C = [:cHh]
const G = [:g]
const X = [:x]
const K = [:k]
const INV = [:inv]
const O = [:domestic, :import]

const U = [I; C; G; X; K; INV]
# Inventory changes are signed and exogenous, so they bypass the fixed shares.
const ordinary_uses = setdiff(U, INV)
# Exports and inventory changes carry no trade or transport margin.
const margin_uses = [I; C; G; K]

const demand_rename = Dict(
  "P3_S14" => :cHh,
  "P3_S15" => :cHh,
  "P3_S13" => :g,
  "P51G" => :k,
  "P52" => :inv,
  "P5M" => :inv,
)

const accounting_rename = Dict(
  "D21X31" => :vProductTax_u,
  "D29X39" => :vOtherProductionTax_i,
  "D1" => :vWage_i,
  "B2A3G" => :vOperatingSurplus_i,
)

# ind_ava labels in naio_10_fcp_ii3 that are not NACE industry rows.
const accounting_ind_ava_codes = collect(keys(accounting_rename)) ∪ ["OP_RES", "OP_NRES"]
const accounting_rows = collect(values(accounting_rename))

end # module
