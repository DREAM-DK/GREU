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
- Inline simple expressions; avoid unnecessary auxiliary variables. Keep
  economic derivatives and similar terms as named variables.
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
- Do not add a blank line just after `begin` or just before `end`. Use blank
  lines between logical groups. Add a short comment after `end` when its matching
  opening line is far away, for example `end # module`.
- Group imports by their project source or layer. Preserve a useful order within
  each group; do not sort imports only for style.

## Repository Structure

Entry points:

- `Calibrate.jl` — assemble via `Model.jl`, calibrate static then dynamic, run tests, write `Output/baseline.parquet`
- `Shock.jl` — load that baseline, shock, solve `base_model(model_modules)`, plot
- `RefreshData.jl` — rebuild checked-in CSV from Eurostat

`Settings.module_names` selects which files under `modules/` are included. Copy `ModuleTemplate.jl` when adding a module, then add its symbol to `module_names`.

**SquareModels.jl** is an external dependency ([GitHub](https://github.com/MartinBonde/SquareModels)). It supplies Blocks, ModelDictionary, and solve. We maintain it and can change it.

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

### 4. Solving

```julia
solution = solve(block, data; replace_nothing=1.0)  # Returns new dict
solve!(block, data)  # Updates in-place
```

Baselines are persisted with `unload` / `load` (parquet). `assert_no_diff` and `assert_residuals_small` check a solve. `at_year` and `variable_year` in `Time.jl` read or shift the year index.

### 5. Tags

`@variables` can carry tags. `ForecastConstant` holds a variable flat after `t1`. `ForecastZero` sets it to zero when no module claims it. `DynamicCalibration` keeps a parameter endogenous in the dynamic solve. `GrowthAdjusted` and `InflationAdjusted` mark stationarity.

## GREU Architecture

### Modularity

A module should solve as a partial equilibrium. Treat endogenous variables from other modules as given.

Link modules through a named hook that starts at zero or as a fixed share. Another module can then make that hook endogenous. `pKAdjCost_k_i` and `qProductionLoss` are the live pattern.

Keep derivatives as named variables, such as `dKAdjCost2dK`. Do not fold them into the user-cost equation. A second module can then change the functional form.

Core equations are identities and fixed shares. A behavior module endogenizes the share or rate. Do not read a tax or friction from another peripheral module. Put a marginal rate or hook in the core.

### Submodule Pattern

Each model component under `modules/` is a Julia module. See `ModuleTemplate.jl`.

Use these sections in this order:

1. **Read data** — read files once. Do not build indices or assign model values here.
2. **Indices** — build sets and live-cell masks from the loaded data.
3. **Variables** — declare variables after all indices exist.
4. **Assign data** — `assign_data!` copies source series into `db`.

Required functions: `define_equations()` and `define_calibration()`. Start calibration from `define_equations()`, then `@endo_exo_swap!` each parameter for the data that identifies it. Optional: `run_tests`, `set_starting_values!`, `set_residual_tolerances!`.

Data refresh files (`*Data.jl`) have no required section layout. Group the code by the structure of that source. A small file needs no section headings.

`Model.jl` includes enabled modules and calls each `assign_data!`. `base_model(modules)` sums `define_equations()` from those modules.

### Calibration (`Calibrate.jl` and `Calibration.jl`)

Exogenize data. Endogenize parameters. Residuals absorb equation imbalances.

Load every series the source reports. Load a total only when the source reports that total and it can disagree with the bottom-up sum. Do not compute aggregates from their parts, except when a lag of that aggregate is needed, such as `pI_k`. Do not compute parameters in `assign_data!`.

Calibration has two swap steps:

1. In `define_calibration`, swap each parameter for the data that identifies it. The data variable stays at its loaded value.
2. `endo_exo_residuals!` then swaps any remaining endogenous variable that has data (up through `t1`) for its residual.

Variables with no data are solved by model equations.

`Calibrate.jl` lists the modules next to the solve. It runs a static calibration, then a dynamic calibration from that result, then a zero-shock test, then writes `Output/baseline.parquet`.

### Shocks (`Shock.jl`)

Loads the calibrated baseline into a copy, applies scenario changes, then `solve!(base_model(model_modules), scenario)`.

## Naming Conventions

The most aggregate variable gets the shortest name. Add a suffix for each extra index: `vI`, then `vI_k`, then `vI_k_i`. Use `2` in a ratio or derivative: `qTop2qY`, `dKAdjCost2dK`. Multi-word names use CamelCase. Index letters must be unique across the model. In use: `i` industry, `k` capital type, `p` product, `t` time.

- `v*` — value (growth and inflation)
- `q*` — quantity (growth)
- `p*` — price (inflation)
- `r*` — rate or ratio
- `t*` — tax rate
- `e*` — elasticity
- `u*` — calibrated share
- `d*` — derivative
- `f*` — factor
- `j*` / `*_J` — residual
