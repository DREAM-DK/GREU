# Reports

`BaselineReport.jl` and `ShockReport.jl` select model series and define economic
diagnostics. They do not solve or change model values.

- SquareModels evaluates expressions, applies source and period settings, and
  builds plots. Use `layout=:trellis` to put each series in a separate panel.
- DREAMMakieTheme supplies fonts, colours, legends, HTML cards, and table styles.
  Its HTML reports embed figures and fonts. They work without an internet connection.
- GREU keeps the report sections, formulas, capital weights, and convergence checks.

Run the baseline report after calibration:

```julia
include("model_julia/BaselineReport.jl")
BaselineReport.write_report(baseline)
```

The default output is `Output/baseline_report.html`. Set `periods`, `path`,
`late_window`, or `color_scale` when needed. The default period range omits the
last ten model years. The report shows adjusted levels and ranks industries by
their percentage change over the closing window. It marks missing observations
as gaps and rejects nonfinite numeric input. The old `views`, `metric`, and
`industry_names` options have no callers and were removed.

`model_julia/Shock.jl` writes the shock report after solving the scenario. To write
one directly:

```julia
include("model_julia/ShockReport.jl")
ShockReport.write_report("Output/shock.html", baseline, scenario;
    periods=2023:2050, shock_year=2024, kind=:export)
```

Use a period range with solved values. `kind=:export` and `kind=:labor_supply`
select extra overview figures. Both level paths use the same opening baseline
value as 100. This preserves changes before the shock year. The capital user
cost response holds capital quantities at their baseline value in each year.

Each writer calls `set_default_source!`, `set_default_periods!`, and
`set_default_operator!`. These settings stay active after the report finishes.
Further `@plot` and `@evalexpr` calls use the same source and years. Call
`reset_print_defaults!()` to clear them.

Run the report tests from the repository root:

```sh
julia --project=. test/Reports.jl
```

The tests use synthetic model values. They need no calibrated baseline or solve.
