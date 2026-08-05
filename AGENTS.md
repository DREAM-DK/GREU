# GREU Julia Implementation - Agent Primer

GREU (Green Reform EU) is a dynamic general equilibrium model for fiscal sustainability and climate policy analysis, being implemented using SquareModels.

In this branch, we are working on a new version of the model implemented in Julia.

## Writing Conventions

- Use ASD-STE100 style for technical English.
- Never use a metaphor, simile, or other figure of speech which you are used to seeing in print.
- Never use a long word where a short one will do.
- If it is possible to cut a word out, always cut it out.
- Never use the passive where you can use the active.
- Never use a foreign phrase, a scientific word, or a jargon word if you can think of an everyday English equivalent.
- Break any of these rules sooner than say anything outright barbarous.

## Coding conventions

- Limit abstractions: do not add layers, configurations, or design patterns for
  hypothetical future needs.
- Prefer broadcasting (`.+`, `.*`, and similar operations) over loops. For
  arrays of arrays, use auxiliary functions instead.
- Prefer comprehensions over loops for data transformations.
- Prefer multiple dispatch and recursion over `isa` checks and branching-heavy
  control flow.
- Avoid nested loops and `if` statements by using smaller functions,
  broadcasting, and multiple dispatch.
- Inline simple expressions; avoid unnecessary auxiliary variables.
- Assert invariants at mutation sites. When possible, validate constraints such
  as finiteness where a value is set, not where it is later consumed.
- Do not silently clamp. Do not use `clamp`, `max`, or `min` to force invalid
  values into range; assert and fix the upstream bug.
- Fail fast. Do not catch or suppress repository-owned errors; let them fail
  with clear messages.
- Avoid redundant input guards. Fix bad repository-owned inputs upstream.
- Before adding `isnothing`, `haskey`, bounds, or type guards, check whether a
  typed assignment, direct index, method signature, constructor, or mutation
  assertion already enforces the invariant.
- Remove unused options and workflows. Do not preserve compatibility for them.
  
- Use consumer-shaped data directly. Do not add one-use constants or helpers
  merely to rename, merge, or reshape repository-owned values.
- Group equations by mechanism. Prefer one `SquareModels.@block` for a coherent
  component. Split blocks only when independently reused, replaced, or
  conditionally composed.

## Repository Structure

```
model_julia/
├── Model.jl                 # Shared container: settings, modules, base_model()
├── Calibrate.jl             # Baseline solve, tests, export to Output/
├── Shock.jl                 # Load baseline, apply scenario, plot
├── RefreshData.jl           # Refresh Eurostat-sourced CSV data
├── Settings.jl              # Country, years, enabled_modules, solver backend
├── Time.jl                  # t, t1, T, at_year, variable_year
├── Tags.jl                  # ForecastConstant, ForecastZero
├── Logging.jl               # Timing and error logging helpers
├── GrowthInflationAdjustment.jl
└── modules/
    ├── SubmodelTemplate.jl  # Template for new modules
    ├── InputOutput.jl       # Example of a full module
    ├── SectorAccounts.jl    # Accounting identities (layer 1)
    ├── Households.jl, Government.jl, Corporations.jl, RestOfWorld.jl
    ├── *Settings.jl         # Module-local constants / mappings
    ├── *Data.jl             # Eurostat fetch + write checked-in CSV
    ├── EurostatClient.jl
    └── DataRefreshUtils.jl
```

Entry points:

- `Calibrate.jl` — assemble via `Model.jl`, calibrate static then dynamic, run tests, write `Output/baseline.parquet`
- `Shock.jl` — load that baseline, shock, solve `base_model()`, plot
- `RefreshData.jl` — rebuild checked-in input-output and sector-accounts CSV from Eurostat

`Settings.enabled_modules` selects which files under `modules/` are included. Copy `SubmodelTemplate.jl` when adding a module, then add its symbol to `enabled_modules`.

**SquareModels.jl** is an external dependency ([GitHub](https://github.com/MartinBonde/SquareModels)) that provides the modeling framework (Blocks, ModelDictionary, solve, etc.). We maintain it and can modify it freely.

## Core Concepts

### 1. Blocks

A `Block` pairs constraints with their endogenous variables:

```julia
block = @block db begin
    vGDP[t = t1:T],  vGDP[t] == vC[t] + vI[t] + vG[t] + vX[t] - vM[t]
    pGDP[t = t1:T],  pGDP[t] * qGDP[t] == vGDP[t]
end
```

Each line: `endogenous_var[indices], equation`

**Residuals**: Each equation `endo == RHS` is transformed to `endo + endo_J == RHS`. The residual `endo_J` (suffix `_J`) is auto-created and initialized to 0. Blocks can be combined with `+`.

### 2. ModelDictionary

Maps variable names to values. `nothing` means "no data".

```julia
db = ModelDictionary(Settings.square_model())
db[vGDP] .= 2000.0
```

### 3. Endo-Exo Swapping

`@endo_exo!` changes which variables are solved for:

```julia
@endo_exo! block begin
    μ, L[t1]    # Make μ endogenous (solved), L[t1] exogenous (fixed)
end
```

Calibration uses `endo_exo_data_residuals!` in `Calibrate.jl`: for endogenous variables that have data (up through `t1`), it swaps so the residual is endogenous and the data variable stays fixed.

### 4. Solving

```julia
solution = solve(block, data; replace_nothing=1.0)  # Returns new dict
solve!(block, data)  # Updates in-place
```

Baselines are persisted with `unload` / `load` (parquet).

## GREU Architecture

### Submodule Pattern

Each model component under `modules/` is a Julia module. See `SubmodelTemplate.jl`. Typical API:

- **Variables**: Declared with `@variables` (optionally `@growth_adjusted` / `@inflation_adjusted`, or tags like `ForecastConstant`)
- **`set_data!(db)`**: Initialize data values
- **`define_equations()`**: Return a Block with the model equations
- **`define_calibration()`**: Return a Block used only for calibration (often `define_equations()` plus calibration equations)
- **`run_tests(db)`** (optional): Return a `Vector{String}` of failure messages
- **`set_starting_values!(db)`** (optional): Starting values before solve
- **`set_residual_tolerances!(tolerances)`** (optional): Per-residual `atol` overrides

`Model.jl` builds `db`, includes enabled modules, calls each `set_data!`, and defines:

```julia
base_model() = sum(m.define_equations() for m in submodels)
```

### Calibration (`Calibrate.jl`)

**Concept**: Variables with data are exogenized; their residuals absorb equation imbalances.

- Variables **with data**: stay at data values; residuals adjust
- Variables **without data**: solved by model equations

Flow:

1. Sum `define_calibration()` from all submodels
2. `forecast_constants!` — `ForecastConstant` vars: equations `var[t] == var[t1]` if endogenous at `t1`, else copy data forward
3. `endo_exo_data_residuals!` — swap data-backed endos for their residuals
4. `exogenous_constant_forecast!` — fill missing future exogenous values from `t1`
5. Optional `set_starting_values!`
6. `solve`

Runs twice: static (`T = calibration_year`), then dynamic (`T = max_terminal_year`) using the static solution as start. Then zero-shock test (`solve(base_model(), baseline)` must match), module `run_tests`, and export `Output/baseline.parquet`.

After calibration, residual values indicate data-model discrepancies.

### Shocks (`Shock.jl`)

Loads the calibrated baseline into a copy, applies scenario changes, then `solve!(base_model(), scenario)`.

## Key Functions

| Function | Purpose |
|----------|---------|
| `@block db begin ... end` | Create equation block |
| `@endo_exo!(block, ...)` | Swap variable roles |
| `endogenous(block)` | Get endogenous variables vector |
| `residuals(block)` | Get matching residuals vector |
| `solve(block, data)` / `solve!(...)` | Solve; return new dict or update in place |
| `load` / `unload` | Read/write parquet ModelDictionary |
| `assert_no_diff(a, b; atol)` | Compare two solutions |
| `assert_residuals_small(data; atol, tolerances)` | Check residual magnitudes |
| `at_year(var, year)` / `variable_year(var)` | Time-index helpers (`Time.jl`) |

## Naming Conventions

- `v*` — Nominal values (adjusted for growth+inflation)
- `q*` — Real quantities (adjusted for growth only)
- `p*` — Prices (adjusted for inflation only)
- `r*` — Rates/shares (no adjustment)
- `*_J` — Residual variables (auto-created)

### Git Workflow
**Never commit untracked files without asking the user first.** Untracked files may be intentionally excluded, contain sensitive data, or be work-in-progress. Always confirm before staging new files.
