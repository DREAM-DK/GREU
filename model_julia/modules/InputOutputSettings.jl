# Static input-output sets and source mappings.
module InputOutputSettings

const input_output_data_dir = joinpath(@__DIR__, "..", "data", "input_output")

const eurostat_dataset = "naio_10_fcp_ii3"
const eurostat_margin_dataset = "naio_10_cp1620"
const eurostat_unit = "MIO_EUR"
const national_accounts_dataset = "nama_10_gdp"
const national_accounts_unit = "CP_MEUR"
const cell_tolerance = 1e-6

const model_sections = [
  :A, :B, :C, :D, :E, :F, :G, :H, :I, :J, :K,
  :L, :M, :N, :O, :P, :Q, :R, :S, :T, :U,
]

# Products use CPA section labels. Industry labels need a prefix because final
# uses use scalar national-account symbols such as :C and :G.
const P = copy(model_sections)
const section_to_industry = Dict(section => Symbol("i$section") for section in model_sections)
const I = [section_to_industry[section] for section in model_sections]

# Wholesale and retail trade, and transport, supply the margin services.
const margin_services = [:G, :H]
@assert margin_services ⊆ P "Margin services must be products"

const final_uses = [
  :C,
  :G,
  :X,
  :K,
  :INV,
]
const O = [:domestic, :import]

const U = [I; final_uses]
@assert allunique(U) "Industry and final-use labels must be distinct"
# Inventory changes are signed and exogenous, so they bypass the fixed shares.
const ordinary_uses = setdiff(U, [:INV])

const demand_rename = Dict(
  "P3_S14" => :C,
  "P3_S15" => :C,
  "P3_S13" => :G,
  "P51G" => :K,
  "P52" => :INV,
  "P5M" => :INV,
)

# Eurostat's standard SUT detail is A*64 for NACE industries and P*64 for CPA
# products. National SUT codes split real estate into L68A and L68B. FIGARO
# uses section L and full division codes for some other sections.
const sut_detail_codes = [
  "A01", "A02", "A03", "B", "C10-12", "C13-15", "C16", "C17", "C18", "C19",
  "C20", "C21", "C22", "C23", "C24", "C25", "C26", "C27", "C28", "C29",
  "C30", "C31_32", "C33", "D", "E36", "E37-39", "F", "G45", "G46", "G47",
  "H49", "H50", "H51", "H52", "H53", "I", "J58", "J59_60", "J61", "J62_63",
  "K64", "K65", "K66", "L68A", "L68B", "M69_70", "M71", "M72", "M73",
  "M74_75", "N77", "N78", "N79", "N80-82", "O", "P", "Q86", "Q87_88",
  "R90-92", "R93", "S94", "S95", "S96", "T", "U",
]
const figaro_a64_aliases = Dict("D35" => :D, "L" => :L, "O84" => :O, "P85" => :P)
const nace_a64_to_p21 = merge(
  Dict(code => Symbol(first(code)) for code in sut_detail_codes),
  figaro_a64_aliases,
)
const nace_a64_to_a21 = Dict(
  code => section_to_industry[section]
  for (code, section) in nace_a64_to_p21
)
const cpa_p64_to_p21 = Dict(
  "CPA_$code" => Symbol(first(code))
  for code in sut_detail_codes
)
@assert Set(values(nace_a64_to_p21)) == Set(P) "NACE map must cover each model product"
@assert Set(values(nace_a64_to_a21)) == Set(I) "NACE map must cover each model industry"
@assert Set(values(cpa_p64_to_p21)) == Set(P) "CPA map must cover each model product"

const margin_final_use_rename = Dict(
  "P3_S14" => :C,
  "P3_S15" => :C,
  "P3_S13" => :G,
  "P51G" => :K,
  "P52" => :INV,
  "P6" => :X,
)

const accounting_rename = Dict(
  "D21X31" => :vProductTax_u,
  "D29X39" => :vOtherProductionTax_i,
  "D1" => :vWage_i,
  "B2A3G" => :vOperatingSurplus_i,
)

const accounting_rows = collect(values(accounting_rename))

end # module
