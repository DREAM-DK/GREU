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

## Julia Formatting

- Start each file with two to six short comment lines that state its purpose,
  scope, and key exclusions.
- Use this form for main section headers:

  ```julia
  # ============================================================================
  # Variables
  # ============================================================================
  const ModelTag = Tag(:Model)
  ```

- Use short sentences with a final period for group comments, such as
  `# Government.`
- Do not align assignment operators across lines. Use one space on each side of
  `=`.
- Use compact spacing in model indices. Put one space after a comma between
  index assignments, such as `[a=aaa, b=bbb]`. Use whitespace around operators,
  except for plus/minus 1 and multiplication or division by fq, fp or fv.
  Write `x[s,t-1]/fv * y`, not `x[s, t - 1] / fv * y`.
- In a `SquareModels.@block`, put the endogenous variable and its equation on
  one line when they fit. Split them when the row is long.
- In a multiline `SquareModels.@block` equation, put `+` and `-` at the start of
  continuation lines and align them with the first term on the right-hand side.
  `SquareModels.@block` joins these lines to the prior equation. Do not use this
  form outside `@block`, where Julia treats them as separate expressions.
- Keep short equations on one line. For a long equation, put each main term on its own line.
- Write short but complete variable descriptions. End each description with a period.
- Put a long comment above the code that it explains. A short, local comment can
  follow the code on the same line.
- Do not add a blank line just after `begin` or just before `end`. Use blank
  lines between logical groups. Add a short comment after `end` when its matching
  opening line is far away, for example `end # module`.
- Group imports by their project source or layer. Preserve a useful order within
  each group; do not sort imports only for style.
- Use one line-ending form in each file. Do not mix line endings or leave
  trailing spaces.

## Repository Structure

```
model_julia/
├── Model.jl                 # Shared container: settings, modules, base_model()
├── Calibrate.jl             # Baseline solve, tests, export to Output/
├── Calibration.jl           # Calibration rules and one-horizon solve
├── DataUtils.jl             # Model data and data-table helpers
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
    └── EurostatClient.jl
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

`@endo_exo_swap!` changes which variables are solved for:

```julia
@endo_exo_swap! block begin
    μ, L[t1]    # Make μ endogenous (solved), L[t1] exogenous (fixed)
end
```

Calibration has two swap steps:

1. In `define_calibration`, swap each parameter for the data that identifies it. The data variable stays at its loaded value. The solver finds the parameter (`r*`, `t*`, and similar).
2. `endo_exo_data_residuals!` in `Calibration.jl` then swaps any remaining endogenous variable that has data (up through `t1`) for its residual. The data value stays fixed. The residual absorbs the gap.

Load every series the source reports. Also load model totals that those series imply, such as `qD_p_u` from `∑ qD_p_u_o`. Do not compute parameters in `set_data!`. Exogenizing the data hits the data exactly when the solver has rounding error, and puts inconsistent source totals on residuals.

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
- **`set_data!(db)`**: Load source series and the model totals they imply. Do not compute parameters from data.
- **`define_equations()`**: Return a Block with the model equations
- **`define_calibration()`**: Return a Block used only for calibration. Start from `define_equations()`, then `@endo_exo_swap!` each parameter for the data that identifies it.
- **`run_tests(db)`** (optional): Return a `Vector{String}` of failure messages
- **`set_starting_values!(db)`** (optional): Starting values before solve
- **`set_residual_tolerances!(tolerances)`** (optional): Per-residual `atol` overrides

`Model.jl` builds `db`, includes enabled modules, calls each `set_data!`, and defines:

```julia
base_model() = sum(m.define_equations() for m in submodels)
```

### Calibration (`Calibrate.jl` and `Calibration.jl`)

**Concept**: Exogenize data. Endogenize parameters. Residuals absorb equation imbalances.

- **Parameters** (`r*`, `t*`, and similar): endogenous in calibration. Identify each one by swapping it for the data it is fitted to. Do not set the parameter in `set_data!`.
- **Variables the source reports**, and **totals the model identities imply from that source** (for example `qD_p_u == ∑ qD_p_u_o`): load them in `set_data!` and keep them exogenous. This includes cells that an equation also determines. The residual then records inconsistent source totals, and the solver hits the data exactly when there is rounding error.
- **Variables with no data**: solved by model equations.

Do not skip a data series because an equation can infer it. Inference belongs in the equations. The loaded value belongs in the dictionary.

Flow:

1. Sum `define_calibration()` from all submodels (includes parameter-for-data swaps)
2. `forecast_constants!` — `ForecastConstant` vars: equations `var[t] == var[t1]` if endogenous at `t1`, else copy data forward
3. `endo_exo_data_residuals!` — swap remaining data-backed endos for their residuals
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
| `@endo_exo_swap!(block, ...)` | Swap variable roles: first argument becomes endogenous, second becomes exogenous |
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
