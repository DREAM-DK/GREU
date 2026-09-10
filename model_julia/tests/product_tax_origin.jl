# Check import-tax source assignment and gross/net totals.
# Run without network access from the project environment.
# Model solve checks belong to Calibrate.jl.
using Test
include(joinpath(@__DIR__, "..", "modules", "TaxesData.jl"))
using .DataUtils: read_cells

@testset "Import tax origin assignment" begin
  q = Dict((:A, :C, 2019) => 100.0, (:A, :INV, 2019) => -10.0, (:A, :X, 2019) => 50.0)
  q_o = Dict(
    (:A, :C, :domestic, 2019) => 80.0, (:A, :C, :import, 2019) => 20.0,
    (:A, :INV, :domestic, 2019) => -8.0, (:A, :INV, :import, 2019) => -2.0,
    (:A, :X, :domestic, 2019) => 40.0, (:A, :X, :import, 2019) => 10.0,
  )
  gross = Dict((:A, :C, 2019) => 20.0, (:A, :INV, 2019) => -2.0, (:A, :X, 2019) => 10.0)
  subsidies = Dict(key => value/10 for (key, value) in gross)
  tax, subsidy = TaxesData.split_product_origins(gross, subsidies, q, q_o, Dict((2019,) => 4.0))
  @test tax[(:A, :C, :domestic, 2019)] ≈ 12.8
  @test tax[(:A, :C, :import, 2019)] ≈ 7.2
  @test subsidy[(:A, :C, :domestic, 2019)] ≈ 1.6
  @test subsidy[(:A, :C, :import, 2019)] ≈ 0.4
  @test tax[(:A, :INV, :import, 2019)] ≈ -0.4
  @test tax[(:A, :X, :import, 2019)] ≈ 2.0
  @test all(tax[key]/q_o[key] >= 0 for key in keys(tax))
  @test all(subsidy[key]/q_o[key] >= 0 for key in keys(subsidy))
  @test_throws AssertionError TaxesData.split_product_origins(gross, subsidies, q, q_o, Dict((2019,) => 5.0))
  no_import_tax, _ = TaxesData.split_product_origins(gross, subsidies, q, q_o, Dict((2019,) => 0.0))
  @test no_import_tax[(:A, :C, :domestic, 2019)] ≈ 16.0
  @test no_import_tax[(:A, :C, :import, 2019)] ≈ 4.0
end

@testset "Prepared product tax sources" begin
  data = TaxesData.product_tax_tables()
  tax = Dict((row.product, row.use, row.origin, row.year) => row.value for row in eachrow(data.gross_tax_origin_table))
  subsidy = Dict((row.product, row.use, row.origin, row.year) => row.value for row in eachrow(data.gross_subsidy_origin_table))
  saved_tax = read_cells(TaxesData.product_taxes_file, "vtProduct_p_u_o")
  saved_subsidy = read_cells(TaxesData.product_taxes_file, "vsProduct_p_u_o")
  @test keys(tax) == keys(saved_tax)
  @test keys(subsidy) == keys(saved_subsidy)
  @test all(isapprox(value, saved_tax[key]; atol=1e-8, rtol=0) for (key, value) in tax)
  @test all(isapprox(value, saved_subsidy[key]; atol=1e-8, rtol=0) for (key, value) in subsidy)
  net = read_cells(TaxesData.net_product_tax_file, "vntProduct_p_u")
  @test all(
    isapprox(sum(get(tax, (p, u, o, year), 0.0) - get(subsidy, (p, u, o, year), 0.0)
      for o in (:domestic, :import)), value; atol=1e-6, rtol=0)
    for ((p, u, year), value) in net if year in data.product_tax.year
  )
  q_o = read_cells(TaxesData.purchaser_use_file, "qPurchaserUse_p_u_o")
  @test all(isfinite(tax[key]) && tax[key]/q_o[key] >= -1e-6 for key in keys(tax) if !iszero(q_o[key]))
  @test all(isfinite(subsidy[key]) && subsidy[key]/q_o[key] >= -1e-6 for key in keys(subsidy) if !iszero(q_o[key]))
  @test any(
    tax[(p, u, :import, year)]/value > tax[(p, u, :domestic, year)]/q_o[(p, u, :domestic, year)] + 1e-6
    for ((p, u, o, year), value) in q_o
    if o == :import && u ∉ (:INV, :X) && value > 0 &&
      get(q_o, (p, u, :domestic, year), 0.0) > 0 && haskey(tax, (p, u, o, year))
  )
end
