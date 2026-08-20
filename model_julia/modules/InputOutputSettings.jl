# Static input-output sets and source mappings.
module InputOutputSettings

const input_output_data_dir = joinpath(@__DIR__, "..", "data", "input_output")

const eurostat_supply_dataset = "naio_10_cp15"
const eurostat_use_dataset = "naio_10_cp1610"
const eurostat_margin_dataset = "naio_10_cp1620"
const eurostat_net_product_tax_dataset = "naio_10_cp1630"
const eurostat_unit = "MIO_EUR"
const cell_tolerance = 1e-6

const model_sections = [
  :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K,
  :L, :M, :N, :O, :P, :Q, :R, :S, :T, :U,
]

# Products use CPA section labels. Industry labels need a prefix because final
# uses use scalar national-account symbols such as :C and :G.
const product = copy(model_sections)
const section_to_industry = Dict(section => Symbol("i$section") for section in model_sections)
const industry = [section_to_industry[section] for section in model_sections]

# Wholesale and retail trade, and transport, supply the margin services.
const margin_services = [:G, :H]
@assert margin_services ⊆ product "Margin services must be products"

const final_uses = [
  :C,
  :G,
  :X,
  :K,
  :INV,
]
const origin = [:domestic, :import]

const use = [industry; final_uses]
@assert allunique(use) "Industry and final-use labels must be distinct"
# Inventory changes are signed and exogenous, so they bypass the fixed shares.
const ordinary_uses = setdiff(use, [:INV])

const final_use_rename = Dict(
  "P3_S14" => :C,
  "P3_S15" => :C,
  "P3_S13" => :G,
  "P51G" => :K,
  "P5M" => :INV,
  "P6" => :X,
)

# Eurostat's standard SUT detail is A*64 for NACE industries and P*64 for CPA
# products. The national tables split real estate into L68A and L68B.
const sut_detail_codes = [
  "A01", "A02", "A03", "B", "C10-12", "C13-15", "C16", "C17", "C18", "C19",
  "C20", "C21", "C22", "C23", "C24", "C25", "C26", "C27", "C28", "C29",
  "C30", "C31_32", "C33", "D", "E36", "E37-39", "F", "G45", "G46", "G47",
  "H49", "H50", "H51", "H52", "H53", "I", "J58", "J59_60", "J61", "J62_63",
  "K64", "K65", "K66", "L68A", "L68B", "M69_70", "M71", "M72", "M73",
  "M74_75", "N77", "N78", "N79", "N80-82", "O", "P", "Q86", "Q87_88",
  "R90-92", "R93", "S94", "S95", "S96", "T", "U",
]
const nace_a64_to_a21 = Dict(
  code => section_to_industry[Symbol(first(code))]
  for code in sut_detail_codes
)
const cpa_p64_to_p21 = Dict(
  "CPA_$code" => Symbol(first(code))
  for code in sut_detail_codes
)
@assert Set(values(nace_a64_to_a21)) == Set(industry) "NACE map must cover each model industry"
@assert Set(values(cpa_p64_to_p21)) == Set(product) "CPA map must cover each model product"

end # module
