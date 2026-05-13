# ==============================================================================
# Input-Output Data Definitions
# ==============================================================================
# Shared codes and derivations for both the Eurostat refresh step and runtime
# loading of checked-in input-output data.
module InputOutputDefinitions

const IOValues = Dict{Tuple{Vararg{String}},Float64}

# Eurostat reports detailed CPA/NACE industries, while InputOutput.jl works with
# the model's one-letter industries and a small set of final-demand categories.
const raw_industry_codes = [
  "A01", "A02", "A03", "B", "C10-12", "C13-15", "C16", "C17", "C18", "C19",
  "C20", "C21", "C22", "C23", "C24", "C25", "C26", "C27", "C28", "C29",
  "C30", "C31_32", "C33", "D", "E36", "E37-39", "F", "G45", "G46", "G47",
  "H49", "H50", "H51", "H52", "H53", "I", "J58", "J59_60", "J61", "J62_63",
  "K64", "K65", "K66", "L68A", "L68B", "M69_70", "M71", "M72", "M73",
  "M74_75", "N77", "N78", "N79", "N80-82", "O", "P", "Q86", "Q87_88",
  "R90-92", "R93", "S94", "S95", "S96", "T", "U",
]

const industry_codes = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S"]
const investment_category_codes = ["iM", "iB"]
const raw_energy_industry_codes = ["B", "D"]
const household_consumption_codes = ["cHh"]
const government_consumption_codes = ["cGov"]
const other_export_codes = ["xOth"]
const energy_demand_code = "energy"
const demand_category_codes = [industry_codes; household_consumption_codes; government_consumption_codes; investment_category_codes; other_export_codes; energy_demand_code]
const energy_demand_category_codes = [raw_energy_industry_codes; energy_demand_code]
const non_energy_demand_category_codes = [d for d in demand_category_codes if !(d in energy_demand_category_codes)]
const accounting_rows = ["vNetProductTax", "vNetOtherProductionTax", "CompEmpl", "OpSurplus"]

const industry_rename = Dict(code => string(first(code)) for code in raw_industry_codes)
const demand_rename = Dict(
  "P3_S14" => "cHh",
  "P3_S15" => "cHh",
  "P3_S13" => "cGov",
  "P52" => "iM",
  "P6" => "xOth",
)
const accounting_rename = Dict(
  "D21X31" => "vNetProductTax",
  "D29X39" => "vNetOtherProductionTax",
  "D1" => "CompEmpl",
  "B2A3G" => "OpSurplus",
)

"""Map Eurostat industry or accounting row codes to model row names."""
rename_industry_code(code::String) = get(accounting_rename, code, get(industry_rename, code, code))

"""Map Eurostat use-side codes to model demand category names."""
rename_demand_code(code::String) = get(demand_rename, code, get(industry_rename, code, code))

"""Derive the model IO value tensors from raw domestic, import, and accounting tables."""
function derive_parameters(vIO_y, vIO_m, vIO_a, years)
  vY = copy(vIO_y)
  vM = copy(vIO_m)

  # The energy commodity aggregates domestic and imported flows from raw energy sectors.
  for year in years, industry in raw_energy_industry_codes
    domestic_energy = sum(get(vIO_y, (industry, demand, year), 0.0) for demand in industry_codes)
    imported_energy = sum(get(vIO_m, (industry, demand, year), 0.0) for demand in industry_codes)
    domestic_energy != 0.0 && (vY[(industry, energy_demand_code, year)] = domestic_energy)
    imported_energy != 0.0 && (vM[(industry, energy_demand_code, year)] = imported_energy)
  end

  vtY = IOValues()
  vtM = IOValues()
  for year in years, demand_category in demand_category_codes
    # Allocate net product taxes and subsidies across domestic and imported deliveries by use shares.
    base = sum(get(vY, (industry, demand_category, year), 0.0) + get(vM, (industry, demand_category, year), 0.0) for industry in industry_codes)
    base == 0.0 && continue
    net_product_tax = get(vIO_a, ("vNetProductTax", demand_category, year), 0.0)
    for industry in industry_codes
      y_value = get(vY, (industry, demand_category, year), 0.0)
      m_value = get(vM, (industry, demand_category, year), 0.0)
      y_value != 0.0 && (vtY[(industry, demand_category, year)] = y_value / base * net_product_tax)
      m_value != 0.0 && (vtM[(industry, demand_category, year)] = m_value / base * net_product_tax)
    end
  end

  vtY_tax = IOValues()
  for year in years, industry in industry_codes
    value = get(vIO_a, ("vNetOtherProductionTax", industry, year), 0.0)
    value != 0.0 && (vtY_tax[(industry, year)] = value)
  end

  qD = IOValues()
  for year in years, demand_category in demand_category_codes
    value = sum(
      get(vY, (industry, demand_category, year), 0.0) +
      get(vM, (industry, demand_category, year), 0.0) +
      get(vtY, (industry, demand_category, year), 0.0) +
      get(vtM, (industry, demand_category, year), 0.0)
      for industry in industry_codes
    )
    value != 0.0 && (qD[(demand_category, year)] = value)
  end

  return (
    vY_i_d = vY,
    vtY_i_d = vtY,
    vM_i_d = vM,
    vtM_i_d = vtM,
    vtY_i_Sub = IOValues(),
    vtY_i_Tax = vtY_tax,
    qD = qD,
  )
end

"""Return industries with non-negligible import deliveries in model IO data."""
function imported_industry_codes(vM)
  return [industry for industry in industry_codes if any(abs(get(vM, (industry, demand_category, year), 0.0)) > 1e-6 for demand_category in demand_category_codes for year in unique(last.(keys(vM))))]
end

end # module
