# Static input-output sets and source mappings.
module InputOutputSettings

const input_output_data_dir = joinpath(@__DIR__, "..", "data", "input_output")

const eurostat_dataset = "naio_10_fcp_ii3"
const eurostat_margin_dataset = "naio_10_cp1620"
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
const margin_services = [:G, :H]
@assert margin_services ⊆ P "Margin services must be products"

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

const demand_rename = Dict(
  "P3_S14" => :cHh,
  "P3_S15" => :cHh,
  "P3_S13" => :g,
  "P51G" => :k,
  "P52" => :inv,
  "P5M" => :inv,
)

# Standard 64-industry ESA supply-use rows. The national margin table also
# contains wider totals and optional 88-industry rows, which would double count.
const sut_industry_codes = [
  "A01", "A02", "A03", "B", "C10-12", "C13-15", "C16", "C17", "C18", "C19",
  "C20", "C21", "C22", "C23", "C24", "C25", "C26", "C27", "C28", "C29",
  "C30", "C31_32", "C33", "D", "E36", "E37-39", "F", "G45", "G46", "G47",
  "H49", "H50", "H51", "H52", "H53", "I", "J58", "J59_60", "J61", "J62_63",
  "K64", "K65", "K66", "L68A", "L68B", "M69_70", "M71", "M72", "M73",
  "M74_75", "N77", "N78", "N79", "N80-82", "O", "P", "Q86", "Q87_88",
  "R90-92", "R93", "S94", "S95", "S96", "T", "U",
]

const margin_final_use_rename = Dict(
  "P3_S14" => :cHh,
  "P3_S15" => :cHh,
  "P3_S13" => :g,
  "P51G" => :k,
  "P52" => :inv,
  "P6" => :x,
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
