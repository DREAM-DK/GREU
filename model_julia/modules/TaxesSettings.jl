# Set production tax sources and factor links.
# Keep country and model-wide dates in Settings.jl.
# Keep tax equations and data reads in Taxes.jl.
module TaxesSettings

const tax_dataset = "gov_10a_taxag"
const tax_unit = "MIO_EUR"
const sector_accounts_dataset = "nasa_10_nf_tr"
const sector_accounts_unit = "CP_MEUR"
const resident_sector = ["S11", "S12", "S13", "S14", "S15"]
const reported_tax_class = [:D29A, :D29B, :D29C, :D29D, :D29E, :D29F, :D29G, :D29H]
const residual_tax_class = :D29R

# An empty list keeps the class at the top of the production tree.
const production_tax_input_map = Dict(
  :D29A => [:structures],
  :D29B => [:equipment, :structures],
  :D29C => [:labor],
  :D29D => Symbol[],
  :D29E => Symbol[],
  :D29F => Symbol[],
  :D29G => Symbol[],
  :D29H => Symbol[],
  :D29R => Symbol[],
)

# Eurostat reports only the total D39 subsidy with broad country coverage.
const production_subsidy_input_map = Dict(
  :D39 => Symbol[],
)

end # module
