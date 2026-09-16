## Run first time

1. Open `GREU.code-workspace` in Cursor.
2. Start a Julia REPL:
  - Press `Ctrl+Shift+P`.
  - Search for `Julia: Start REPL`.
  - Press `Enter`.
  - Wait until the Julia REPL appears at the bottom of Cursor (or side view if you have set cursor up for sideview like me)
3. Activate the GREU project:
  - Click inside the Julia REPL.
  - Press `]` to enter package mode.
  - Enter:
    ```julia
    activate .
    ```
  - Press `Enter`.
   The package prompt should now show that the GREU project is active.
4. Install the required Julia packages by entering:
  ```julia
   instantiate
  ```
   Wait until this has finished (can take a while if its first time or its been a while).
5. Press `Backspace` to leave package mode and return to the normal Julia prompt:
  ```julia
   julia>
  ```
6. Open `RefreshData.jl`.
7. Select the entire file with `Ctrl+A` and run it with `Shift+Enter`.
  Wait until the file has finished running without errors. `RefreshData.jl` only needs to be run once after cloning the repository. Closing Cursor or Julia does not require it to be run again (exception is if you are changing data then it needs to run again).
8. Open `Calibrate.jl`.
9. Select the entire file with `Ctrl+A` and run it with `Shift+Enter`.
  The model will now load the generated data, perform the calibration and produce the baseline output and reports, if you only want to run dynamic calibration and not get outputs you can just run up to and including
  ```julia
  baseline = dynamic_calibration(...)
  ```



## Run afterwards

After the model has been loaded and calibrated once, it is normally unnecessary to rerun the entire `Calibrate.jl` file after every change. This is a short guide on what parts needs to be run depending on what changes you have made:

### After changing an equation or function

In `Calibrate.jl`, highlight everything from:

```julia
model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]

```

down to and including the complete:

```julia
baseline = dynamic_calibration(
  data,
  static_solution,
  static_calibrated_parameters;
  previous_solution,
)

```

Press `Shift+Enter`.

This rebuilds the equation blocks and reruns the static and dynamic calibration with the updated code. 

### After changing data assignment

If a function such as `assign_data!` or `adjust_growth_inflation!` has been changed, the data must also be recreated.

Highlight everything from:

```julia
data = assign_data!(ModelDictionary(model))

```

down to and including the complete `baseline = dynamic_calibration(...)` call.

Press `Shift+Enter`.

### Changes that require restarting Julia

Restart Julia after changing:

- a variable definition;
- a set or index;
- the dimensions or indices of an existing variable;
- imports;
- loaded modules;
- `Settings.jl` or `Time.jl`; or
- other top-level definitions created when GREU is loaded.

These are structural parts of the shared model and cannot safely be replaced by `Revise`.

After restarting Julia, activate the GREU environment and run `Calibrate.jl` from the top. Do not rerun individual variable or set declarations in the existing session, as this can leave the model with outdated or duplicate definitions.

### Before sharing changes

During development, it is sufficient to run only the sections needed to test the current change.

Before committing or sharing the changes, select the entire `Calibrate.jl` file with `Ctrl+A` and run it with `Shift+Enter`. This checks the complete calibration, residual tests, zero-shock test, baseline export and reports. Before pushing a change to Julia-implementation please update the solution in shared folder using save_solution_as_previous.md in the data folder. 