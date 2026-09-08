# Check report formulas and output with fixed synthetic values.
# Do not load a calibrated baseline or solve the model.
using Test, GREU, SquareModels, CairoMakie, DREAMMakieTheme
import GREU.FixedBasePriceAggregates: qGDP
import GREU.InputOutput: qM

include("../model_julia/BaselineReport.jl")
include("../model_julia/ShockReport.jl")

line_values(figure) = [Float64[p[2] for p in line[1][]]
  for line in content(figure[1, 1]).scene.plots if line isa Lines]

@testset "Baseline diagnostics" begin
  years = [2020, 2025, 2030, 2035]
  @test BaselineReport.late_change(years, [100, 110, 115, 121]) ≈ 10
  @test BaselineReport.late_change(years, [100, 110, 121, NaN]) ≈ 21
  @test BaselineReport.late_change(years, [0, 0, 0, 1]) === nothing
  @test BaselineReport.late_change(years, fill(NaN, 4)) === nothing
  @test BaselineReport.checked_values(nothing, "absent factor") === nothing
  @test isequal(BaselineReport.checked_values([1, nothing, 3], "gap"), [1, NaN, 3])
  @test_throws AssertionError BaselineReport.checked_values([1, Inf], "invalid")
  @test_throws AssertionError BaselineReport.checked_values([1, NaN], "invalid")
  @test_throws AssertionError BaselineReport.late_change(years, ones(4); window=0)
end

@testset "Report values and output" begin
  years = collect(GREU.Time.t1:GREU.Time.t1+2)
  baseline = ModelDictionary(GREU.model, 1.0)
  baseline[BaselineReport.vY_i] .= 3.0
  baseline[ShockReport.qGDP[years]] .= [2, 4, 8]
  scenario = copy(baseline)
  scenario[ShockReport.qGDP[years]] .= [3, 6, 12]
  k, i = first(ShockReport.capital_k_i)
  scenario[ShockReport.qK_k_i[k,i,years]] .= 100.0
  scenario[ShockReport.pK_k_i[k,i,years]] .= 1.2
  original = collect(values(baseline))
  output = mktempdir()

  BaselineReport.write_report(baseline; periods=years, path=joinpath(output, "baseline.html"))
  @test collect(@evalexpr(qGDP)) == [2, 4, 8]
  @test length(@evalexpr(qM)) == length(years)
  series = BaselineReport.industry_series(years)
  @test all(e.values === nothing || all(isfinite, e.values) for s in series for e in s.entries)
  html = read(joinpath(output, "baseline.html"), String)
  @test occursin("dream-table", html)
  @test count("<section>", html) == 16

  ShockReport.write_report(joinpath(output, "shock.html"), baseline, scenario;
    periods=years, shock_year=years[2], kind=:export)
  @test collect(@evalexpr(qGDP)) ≈ [50, 50, 50]
  levels = ShockReport.level_figures(:standard, baseline, years, years[2], "Scenario", colors().REFORM)
  @test first(line_values(last(first(levels)))) ≈ [150, 300, 600]
  @test last(line_values(last(first(levels)))) ≈ [100, 200, 400]
  responses = ShockReport.response_figures(baseline, years, years[2], colors().REFORM)
  user_cost = only(line_values(last(only(filter(p -> first(p) == "Capital — User cost", responses)))))
  @test user_cost ≈ fill(20 / length(ShockReport.capital_k_i), length(years)) atol=1e-6
  html = read(joinpath(output, "shock.html"), String)
  @test count("<article ", html) == 17
  @test occursin("data:image/svg+xml;base64,", html)
  @test collect(values(baseline)) == original
end

reset_print_defaults!()
