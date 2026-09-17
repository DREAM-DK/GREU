# Find the finest common industry and product partition in Eurostat data.
# Test the source cells used by the model for every model data year.
# Write the selected groups and source coverage before other data refreshes.
include(joinpath(@__DIR__, "..", "Settings.jl"))
include("InputOutputSettings.jl")
include("ProductionSettings.jl")
include("EurostatClient.jl")

module IndustryResolutionData

using CSV
using DataFrames
import ..EurostatClient
import ..InputOutputSettings:
  eurostat_margin_dataset,
  eurostat_net_product_tax_dataset,
  eurostat_supply_dataset,
  eurostat_unit,
  eurostat_use_dataset,
  sut_detail_codes
import ..ProductionSettings:
  capital_flow_dataset,
  capital_stock_dataset,
  flow_asset_to_capital_type,
  flow_unit,
  gva_dataset,
  gva_deflator_unit,
  gva_na_item,
  gva_unit,
  production_tax_na_item,
  stock_asset_to_capital_type,
  stock_deflator_unit,
  stock_unit
import ..Settings: calibration_year, country_code, first_data_year

const data_years = first_data_year:calibration_year
const year_params = ["time" => string(year) for year in data_years]
const output_dir = joinpath(@__DIR__, "..", "data", "industry_resolution")
const resolution_file = joinpath(output_dir, "industry_resolution.csv")
const coverage_file = joinpath(output_dir, "industry_resolution_coverage.csv")

const sections = collect('A':'U')
const leaf_codes = replace.(sut_detail_codes, "_" => "-")
const leaf_index = Dict(code => i for (i, code) in enumerate(leaf_codes))

const eurostat_dataset_names = Dict(
  "naio_10_cp15" => "Supply table at basic prices incl. transformation into purchasers' prices",
  "naio_10_cp1610" => "Use table at purchasers' prices",
  "naio_10_cp1620" => "Trade and transport margins",
  "naio_10_cp1630" => "Taxes less subsidies on products",
  "nama_10_a64_e" => "Employment by A*64 industry",
  "nama_10_a64" => "National accounts aggregates by A*64 industry",
  "nama_10_nfa_st" => "Fixed assets by activity and asset (stocks)",
  "nama_10_a64_p5" => "Gross capital formation by A*64 industry and asset",
)

function dataset_name(code::String)
  return get(eurostat_dataset_names, code, "Eurostat dataset")
end

function print_dataset_report(specs, n_industries)
  # A dataset can occur in several source slices (e.g. both industry and product axes).
  # Print each Eurostat dataset only once, but show every slice tested from it.
  by_dataset = Dict{String,Vector{String}}()
  order = String[]
  for spec in specs
    if !haskey(by_dataset, spec.dataset)
      by_dataset[spec.dataset] = String[]
      push!(order, spec.dataset)
    end
    push!(by_dataset[spec.dataset], spec.name)
  end

  println("EUROSTAT DATASETS SUPPORTING THE COMMON RESOLUTION ($n_industries industries/products):")
  println()
  for code in order
    println("  ", code, " — ", dataset_name(code))
    println("      Tested slices: ", join(by_dataset[code], ", "))
  end
  println()
  println("Number of unique Eurostat datasets tested: ", length(order))
end

# ============================================================================
# Eurostat source slices
# ============================================================================

struct SourceSlice
  name::String
  dataset::String
  dimension::Symbol
  params::Vector{Pair{String,String}}
  required::Dict{Symbol,Vector{String}}
  product_dimension::Bool
end

function source_slices()
  stock_assets = collect(keys(stock_asset_to_capital_type))
  flow_assets = collect(keys(flow_asset_to_capital_type))
  years = string.(data_years)
  return [
    SourceSlice(
      "supply_industry", eurostat_supply_dataset, :ind_impv,
      ["unit" => eurostat_unit, "stk_flow" => "TOTAL"],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "supply_product", eurostat_supply_dataset, :prd_amo,
      ["unit" => eurostat_unit, "stk_flow" => "TOTAL"],
      Dict(:time => years), true,
    ),
    SourceSlice(
      "use_industry", eurostat_use_dataset, :ind_use,
      ["unit" => eurostat_unit],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "use_product", eurostat_use_dataset, :prd_ava,
      ["unit" => eurostat_unit],
      Dict(:time => years), true,
    ),
    SourceSlice(
      "margin_industry", eurostat_margin_dataset, :ind_use,
      ["unit" => eurostat_unit, "stk_flow" => "TOTAL"],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "margin_product", eurostat_margin_dataset, :cpa2_1,
      ["unit" => eurostat_unit, "stk_flow" => "TOTAL"],
      Dict(:time => years), true,
    ),
    SourceSlice(
      "net_product_tax_industry", eurostat_net_product_tax_dataset, :ind_use,
      ["unit" => eurostat_unit, "stk_flow" => "TOTAL"],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "net_product_tax_product", eurostat_net_product_tax_dataset, :cpa2_1,
      ["unit" => eurostat_unit, "stk_flow" => "TOTAL"],
      Dict(:time => years), true,
    ),
    SourceSlice(
      "payroll", eurostat_use_dataset, :ind_use,
      ["unit" => eurostat_unit, "stk_flow" => "TOTAL", "prd_ava" => "D1"],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "employment", "nama_10_a64_e", :nace_r2,
      ["unit" => "THS_PER", "na_item" => "SAL_DC"],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "gva_current", gva_dataset, :nace_r2,
      ["unit" => gva_unit, "na_item" => gva_na_item],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "gva_previous_prices", gva_dataset, :nace_r2,
      ["unit" => gva_deflator_unit, "na_item" => gva_na_item],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "production_taxes", gva_dataset, :nace_r2,
      ["unit" => gva_unit, "na_item" => production_tax_na_item],
      Dict(:time => years), false,
    ),
    SourceSlice(
      "capital_stock_current", capital_stock_dataset, :nace_r2,
      vcat(["unit" => stock_unit], ["asset10" => asset for asset in stock_assets]),
      Dict(:time => years, :asset10 => stock_assets), false,
    ),
    SourceSlice(
      "capital_stock_previous_prices", capital_stock_dataset, :nace_r2,
      vcat(["unit" => stock_deflator_unit], ["asset10" => asset for asset in stock_assets]),
      Dict(:time => years, :asset10 => stock_assets), false,
    ),
    SourceSlice(
      "capital_investment", capital_flow_dataset, :nace_r2,
      vcat(["unit" => flow_unit, "na_item" => "P51G"], ["asset10" => asset for asset in flow_assets]),
      Dict(:time => years, :asset10 => flow_assets), false,
    ),
  ]
end

function fetch_slice(spec::SourceSlice)
  return EurostatClient.fetch_table(
    spec.dataset,
    spec.params...,
    "geo" => country_code,
    year_params...,
  )
end

function required_cells(required::Dict{Symbol,Vector{String}})
  dims = collect(keys(required))
  values = [required[dim] for dim in dims]
  return dims, Set(Tuple(string.(cell)) for cell in Iterators.product(values...))
end

function complete_codes(df::DataFrame, spec::SourceSlice)
  @assert spec.dimension in propertynames(df) "$(spec.name) has no $(spec.dimension) dimension"
  dims, target = required_cells(spec.required)
  @assert all(dim in propertynames(df) for dim in dims) "$(spec.name) misses a required dimension"

  cells = Dict{String,Set{Tuple}}()
  for row in eachrow(df)
    code = string(row[spec.dimension])
    code == "TOTAL" && continue
    cell = Tuple(string(row[dim]) for dim in dims)
    push!(get!(cells, code, Set{Tuple}()), cell)
  end
  return Set(code for (code, observed) in cells if target ⊆ observed)
end

# ============================================================================
# NACE and CPA coverage
# ============================================================================

normalize_code(code::String, product_dimension::Bool=false) = begin
  value = uppercase(strip(code))
  value = product_dimension && startswith(value, "CPA_") ? value[5:end] : value
  replace(value, "_" => "-", " " => "")
end

function leaf_numeric_range(code::String)
  m = match(r"^([A-U])(\d{2})(?:-(\d{2}))?([AB])?$", code)
  isnothing(m) && return nothing
  section, first_number, last_number, suffix = m.captures
  return (
    section = only(section),
    first = parse(Int, first_number),
    last = isnothing(last_number) ? parse(Int, first_number) : parse(Int, last_number),
    suffix = isnothing(suffix) ? "" : suffix,
  )
end

function numeric_code_range(code::String)
  m = match(r"^([A-U])(\d{2})(?:-([A-U])?(\d{2}))?([AB])?$", code)
  isnothing(m) && return nothing
  first_section, first_number, last_section, last_number, suffix = m.captures
  !isnothing(last_section) && last_section != first_section && return nothing
  return (
    section = only(first_section),
    first = parse(Int, first_number),
    last = isnothing(last_number) ? parse(Int, first_number) : parse(Int, last_number),
    suffix = isnothing(suffix) ? "" : suffix,
  )
end

function code_leaf_indices(raw_code::String, product_dimension::Bool=false)
  code = normalize_code(raw_code, product_dimension)
  code in ("TOTAL", "") && return Int[]
  haskey(leaf_index, code) && return [leaf_index[code]]

  if occursin(r"^[A-U]$", code)
    section = only(code)
    return findall(startswith.(leaf_codes, string(section)))
  end

  section_range = match(r"^([A-U])-([A-U])$", code)
  if !isnothing(section_range)
    first_section, last_section = only.(section_range.captures)
    return findall(code -> first(code) in first_section:last_section, leaf_codes)
  end

  source_range = numeric_code_range(code)
  isnothing(source_range) && return Int[]
  return [
    i for (i, leaf) in enumerate(leaf_codes)
    if begin
      leaf_range = leaf_numeric_range(leaf)
      !isnothing(leaf_range) &&
        leaf_range.section == source_range.section &&
        source_range.first <= leaf_range.first &&
        leaf_range.last <= source_range.last &&
        (isempty(source_range.suffix) || source_range.suffix == leaf_range.suffix)
    end
  ]
end

function contiguous_interval(indices::Vector{Int})
  isempty(indices) && return nothing
  values = sort(unique(indices))
  values == collect(first(values):last(values)) || return nothing
  return first(values):last(values)
end

function source_intervals(codes::Set{String}, product_dimension::Bool)
  intervals = Set{Tuple{Int,Int}}()
  for code in codes
    interval = contiguous_interval(code_leaf_indices(code, product_dimension))
    isnothing(interval) || push!(intervals, (first(interval), last(interval)))
  end
  return intervals
end

"""Return true when non-overlapping source rows can exactly build leaves first:last."""
function can_tile(first_leaf::Int, last_leaf::Int, intervals::Set{Tuple{Int,Int}})
  reachable = falses(last_leaf + 1)
  reachable[first_leaf] = true
  for position in first_leaf:last_leaf
    reachable[position] || continue
    for (first_source, last_source) in intervals
      first_source == position || continue
      last_source <= last_leaf || continue
      reachable[last_source + 1] = true
    end
  end
  return reachable[last_leaf + 1]
end

function common_intervals(source_coverage)
  n = length(leaf_codes)
  intervals = Set{Tuple{Int,Int}}()

  for first_leaf in 1:n
    for last_leaf in first_leaf:n
      if all(can_tile(first_leaf, last_leaf, source.intervals) for source in source_coverage)
        push!(intervals, (first_leaf, last_leaf))
      end
    end
  end

  return intervals
end

"""Choose the partition with the largest number of common groups."""
function finest_partition(valid_intervals::Set{Tuple{Int,Int}})
  n = length(leaf_codes)
  unreachable = typemin(Int)
  best = fill(unreachable, n + 2)
  next_leaf = fill(0, n + 1)
  best[n + 1] = 0

  # A leaf does not have to be a valid *starting point* on its own. For example,
  # Eurostat may only expose L68 while the SUT leaves are L68A and L68B. In that
  # case L68B is intentionally unreachable as a partition start, because the
  # valid common group starts at L68A and spans both leaves.
  for first_leaf in n:-1:1
    choices = [
      last_leaf
      for last_leaf in first_leaf:n
      if (first_leaf, last_leaf) in valid_intervals && best[last_leaf + 1] != unreachable
    ]
    isempty(choices) && continue

    scores = [1 + best[last_leaf + 1] for last_leaf in choices]
    score, choice = findmax(scores)
    best[first_leaf] = score
    next_leaf[first_leaf] = choices[choice]
  end

  @assert best[1] != unreachable begin
    uncovered = [
      leaf_codes[i]
      for i in 1:n
      if next_leaf[i] == 0
    ]
    "No common Eurostat partition covers the full SUT classification. " *
    "Unreachable partition starts include: $(join(uncovered, ", "))"
  end

  groups = UnitRange{Int}[]
  first_leaf = 1
  while first_leaf <= n
    last_leaf = next_leaf[first_leaf]
    @assert last_leaf >= first_leaf "Internal partition error at $(leaf_codes[first_leaf])"
    push!(groups, first_leaf:last_leaf)
    first_leaf = last_leaf + 1
  end
  return groups
end

"""
    count_industries(partition)

Returnerer antallet af industrier/produkter i den fundne
fælles Eurostat-partition.
"""
function count_industries(partition)
    n = length(partition)
    println("Number of common industries/products: $n")
    return n
end

function group_code(group::UnitRange{Int})
  members = leaf_codes[group]
  length(members) == 1 && return only(members)

  member_sections = first.(members)
  if all(==(first(member_sections)), member_sections)
    section = first(member_sections)
    section_members = filter(code -> first(code) == section, leaf_codes)
    members == section_members && return string(section)
  end

  complete_sections = [
    section
    for section in sections
    if filter(code -> first(code) == section, leaf_codes) ⊆ members
  ]
  if !isempty(complete_sections) &&
      members == reduce(vcat, [filter(code -> first(code) == section, leaf_codes) for section in complete_sections]) &&
      complete_sections == collect(first(complete_sections):last(complete_sections))
    return length(complete_sections) == 1 ? string(only(complete_sections)) :
      "$(first(complete_sections))-$(last(complete_sections))"
  end

  return join(members, "+")
end

# ============================================================================
# Output
# ============================================================================

function coverage_table(source_coverage)
  return DataFrame([
    (
      source = source.name,
      source_code = code,
      mapped_members = join(leaf_codes[interval], ";"),
      first_leaf = first(interval),
      last_leaf = last(interval),
    )
    for source in source_coverage
    for code in sort(collect(source.codes))
    for interval in [contiguous_interval(code_leaf_indices(code, source.product_dimension))]
    if !isnothing(interval)
  ])
end

function resolution_table(groups, source_coverage)
  return DataFrame([
    (
      industry = Symbol("i" * replace(group_code(group), r"[^A-Z0-9]+" => "_")),
      product = Symbol(replace(group_code(group), r"[^A-Z0-9]+" => "_")),
      eurostat_group = group_code(group),
      members = join(leaf_codes[group], ";"),
      member_count = length(group),
      first_leaf = first(group),
      last_leaf = last(group),
      direct_source_count = count(
        source -> (first(group), last(group)) in source.intervals,
        source_coverage,
      ),
    )
    for group in groups
  ])
end

function refresh_industry_resolution!(dir=output_dir)
  mkpath(dir)
  specs = source_slices()
  coverage = [
    begin
      @info "Checking Eurostat industry detail" source=spec.name dataset=spec.dataset
      codes = complete_codes(fetch_slice(spec), spec)
      intervals = source_intervals(codes, spec.product_dimension)
      @assert !isempty(intervals) "$(spec.name) has no usable NACE/CPA coverage"
      (
        name = spec.name,
        codes = codes,
        intervals = intervals,
        product_dimension = spec.product_dimension,
      )
    end
    for spec in specs
  ]

  valid = common_intervals(coverage)
  groups = finest_partition(valid)
  n_industries = count_industries(groups)
  resolution = resolution_table(groups, coverage)

  println()
  println("==============================================")
  println(" COMMON EUROSTAT RESOLUTION")
  println("==============================================")
  println("Detailed SUT leaves: ", length(leaf_codes))
  println("Common industries/products: ", n_industries)
  println("Merged groups:")
  println()

  merged = filter(row -> row.member_count > 1, resolution)
  if nrow(merged) == 0
    println("  None")
  else
    for row in eachrow(merged)
      println(
        "  ",
        row.eurostat_group,
        " = ",
        row.members,
        "  (",
        row.member_count,
        " detailed leaves)",
      )
    end
  end
  println("==============================================")
  println()
  print_dataset_report(specs, n_industries)
  println("==============================================")
  println()

  CSV.write(joinpath(dir, basename(resolution_file)), resolution)
  CSV.write(joinpath(dir, basename(coverage_file)), coverage_table(coverage))

  @info "Selected common Eurostat classification" industries=nrow(resolution)
  foreach(row -> @info("Industry group", code=row.eurostat_group, members=row.members), eachrow(resolution))
  return resolution
end

end # module

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  IndustryResolutionData.refresh_industry_resolution!()
end
