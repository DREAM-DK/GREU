# GREU - Agent Primer

Green REFORM EU is an extensible dynamic general equilibrium model for fiscal and environmental policy analysis. It is implemented in GAMS and uses the in-house gamY preprocessor through Python.

## Writing Conventions

- Use clear technical English.
- Prefer short, direct sentences.
- Keep explanations close to the model mechanism or data source they describe.
- Do not add abstractions, switches, or compatibility layers for hypothetical future uses.

## Coding Conventions

- Prefer set-based GAMS code over scalar loops when the domain is clear.
- Keep domain filters close to the variable or equation they restrict.
- Use `$GROUP`, `$SetGroup`, `$BLOCK`, and `$MODEL` instead of ad hoc lists in solve code.
- Keep modules staged by `variables`, `equations`, `exogenous_values`, `starting_values`, `calibration`, and `tests`.
- Add assertions or tests where data, dummies, or calibration swaps can silently become invalid.
- Do not force bad values into range without understanding the data, dummy, or equation that caused them.
- Keep generated artifacts such as `model/Expanded/`, `model/LST/`, `model/Output/`, and `model/saved/` out of hand-written edits unless the task is explicitly about run output.

## Repository Structure

```text
GREU/
|-- run.py                  # Main run script: data build, baseline models, shocks, reports
|-- run_report.py           # Reporting entry point
|-- data/                   # Input data and Python/GAMS data builders
|   |-- data_from_GR.gms    # Builds data.gdx from GreenREFORM-DK inputs
|   `-- Energy_technology_data/
`-- model/
    |-- settings.gms        # Global years, growth rates, solver settings, switches
    |-- base_model.gms      # Core CGE model assembly, calibration, optional tests
    |-- base_model_energy_technology.gms
    |-- calibration.gms     # Static and dynamic calibration sequence
    |-- growth_adjustments.gms
    |-- variable_groups.gms
    |-- modules/            # Staged model modules
    |-- sets/               # Set definitions
    |-- Report/             # GAMS report files
    |-- Expanded/           # gamY-expanded files
    |-- LST/                # GAMS listing files
    |-- Output/             # GDX outputs
    `-- saved/              # Saved GDX states between runs
```

## Entry Points

- `run.py` is the main script. It sets the local GAMS path, changes into `model/`, builds `data.gdx`, runs the base CGE model, runs `base_model_energy_technology.gms`, runs shocks, and opens reporting.
- To run only the energy technology baseline from Python, mirror the `run.py` setup and call `dt.gamY.run("base_model_energy_technology.gms", s="saved/base_model_energy_technology", test_CGE="0", test_energy_technology="1")`.
- `model/base_model.gms` imports settings, functions, sets, module variables, equations, data, starting values, and calibration.
- `model/base_model_energy_technology.gms` imports `base_model.gms`, solves partial energy price and technology models, then solves the integrated calibration and optional zero-shock test.
- Read `model/LST/*.lst` for solver status, iteration count, resource usage, and detailed CONOPT output after a run.

## Module Pattern

Modules live in `model/modules/*.gms` and are imported by `@import_from_modules(stage)` in `base_model.gms`.

- `variables`: define variables, parameters, dummies, and base groups.
- `equations`: define `$BLOCK`s and add them to `main`; add each block's endogenous group to `main_endogenous`.
- `exogenous_values`: load or assign data and add observed variables to `data_covered_variables`.
- `starting_values`: set non-default starting values before calibration.
- `calibration`: add calibration equations and endo/exo swaps to `calibration_endogenous`.
- `tests`: add model or data checks.

Start from `model/modules/submodel_template.gms` for new modules.

## Endogenous and Exogenous Grouping

This version has a smarter endo/exo pattern than older GreenREFORM model versions. A `$BLOCK` declares both equations and the matching endogenous group. Modules then add those block groups to `main_endogenous` or `calibration_endogenous`.

For calibration, prefer cumulative edits to `calibration_endogenous`:

```gams
$GROUP calibration_endogenous
  module_endogenous
  module_calibration_endogenous
  -observed_variable[i,t1], calibration_parameter[i,t1]
  calibration_endogenous
;
```

The solve files usually fix everything and unfix the active endogenous group:

```gams
$FIX all_variables; $UNFIX calibration_endogenous;
solve calibration using CNS;

$FIX all_variables; $UNFIX main_endogenous;
solve main using CNS;
```

## Data, Dummies, and Time

- `settings.gms` defines `first_data_year`, `calibration_year`, `terminal_year`, `gp`, and `gq`.
- `set_time_periods(...)` controls active model years such as `t0`, `t1`, and `tEnd`.
- Dummies such as `d1...`, `tData`, `tDataEnd`, and switch parameters control domains and module activation.
- `@update_exist_dummies()` and the configured dummy suffix keep variables and equations limited to existing elements.
- `data_covered_variables` records values that should remain tied to data; preserve its checks when changing calibration.

## Naming Conventions

- `p*`: prices.
- `q*`: quantities or real values.
- `v*`: nominal values.
- `r*`: rates or ratios.
- `s*`: shares.
- `u*`: calibrated coefficients or unit values.
- `j*` and `jf*`: additive or multiplicative residual terms.
- `d1*`: dummies for existence or domain logic.
- `G_*`: groups.
- `B_*`: blocks, where used.
- `M_*`: models.
- `E_*`: generated equation prefixes.

## Git and Generated Files

- Do not commit or revert user changes unless asked.
- Check the working tree before edits because data files and generated run folders can be dirty after model runs.
- Avoid hand edits in generated listing, expanded, output, and saved files. If a task needs run evidence, summarize the listing output instead of editing it.
