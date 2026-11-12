# Run guide: GREU in Julia

## 1. Install

Do these steps once on a new computer. Each step ends with a test.

### 1.1 VS Code and the Julia extension

1. Install [VS Code](https://code.visualstudio.com/). Cursor also works.
2. In VS Code, open Extensions (`Ctrl+Shift+X`). Search for `Julia` and install the extension from *Julia Language Support* (`julialang.language-julia`).

**Test:** the Julia extension shows in the list of installed extensions.

### 1.2 Julia

1. When the Julia extension finds no Julia, it offers to install Julia through juliaup. Accept the offer.
2. If you closed the offer, install Julia from a terminal instead, and then restart VS Code:
   ```
   winget install --name Julia --id 9NJNWW8PVKMN -e -s msstore
   ```

**Test:** press `Ctrl+Shift+P` and run `Julia: Start REPL`. At the `julia>` prompt, enter `VERSION`.

## 2. Get the code

In a terminal, go to the folder where you keep your code, and run:

```
git clone https://github.com/DREAM-DK/GREU.git
cd GREU
git checkout julia-implementation
```

The default branch, `main`, holds the GAMS model. The Julia model is on `julia-implementation`.

**Test:** `git branch` shows `* julia-implementation`.

## 3. Set the GAMS path

The model solves its equations with CONOPT through GAMS. `model_julia/Settings.jl` finds GAMS with this line:

```julia
gams_system_dir() = dirname(something(Sys.which("gams"), "C:/GAMS/51/gams.exe"))
```

It uses the `gams` on your PATH. If there is none, it uses the path in quotes. If GAMS is not on your PATH, change that path to your own `gams.exe`, for example:

```julia
gams_system_dir() = dirname(something(Sys.which("gams"), "C:/GAMS/54/gams.exe"))
```

Use forward slashes.

## 4. Run first time

1. Open `GREU.code-workspace` in VS Code or Cursor.
2. Start a Julia REPL:
   - Press `Ctrl+Shift+P`.
   - Search for `Julia: Start REPL`.
   - Press `Enter`.
   - Wait until the Julia REPL appears.

   Do not type `julia` in a plain terminal instead. The REPL from the extension uses the settings in the workspace file, and `Shift+Enter` sends code only to that REPL.
3. Activate the GREU project:
   - Click inside the Julia REPL.
   - Press `]` to enter package mode (`AltGr+9` on a Danish keyboard).
   - Enter `activate .` (with a space before the dot).

   The prompt now shows `(GREU) pkg>`. If it already shows this, skip this step.
4. Install the Julia packages:
   ```julia
   instantiate
   ```
   This can take a while the first time. If it fails with a 404 error for `DREAMMakieTheme`, you do not have access to the DREAM-DK organisation on GitHub, where this package is private. Comment out the two `DREAMMakieTheme` lines in `Project.toml` and run `instantiate` again. Without the package, `Calibrate.jl` stops with an error in the report, after it has written the baseline.
5. Press `Backspace` to go back to the normal Julia prompt:
   ```julia
   julia>
   ```
6. Get the data. The data files (`*.csv`) are not in git. Open `RefreshData.jl`, select the entire file with `Ctrl+A` and run it with `Shift+Enter`. You need to do this only once, and again only when you change the data.
7. Open `Calibrate.jl`. Select the entire file with `Ctrl+A` and run it with `Shift+Enter`. The first run is slow, because Julia compiles the packages and the model. The file:
   - loads the data;
   - runs the static calibration, then the dynamic calibration;
   - runs the zero-shock test;
   - writes `Output/baseline.parquet`;
   - writes a report.

   The run succeeded if `Output/baseline.parquet` has a new timestamp. To skip the report, run only up to and including the `baseline = @log_time "dynamic calibration" dynamic_calibration(...)` call.

   For a quicker first run, set `terminal_year` in `Settings.jl` to 2030. The smallest value that works is 2028.

## 5. Run afterwards

After the model has been loaded and calibrated once, it is normally unnecessary to rerun the entire `Calibrate.jl` file after every change. This is a short guide on what parts need to be run, depending on what changes you have made.

### After changing an equation or function

In `Calibrate.jl`, highlight everything from:

```julia
model_modules = [loaded_module_by_name[name] for name in Settings.model_modules]
```

down to and including the complete:

```julia
baseline = @log_time "dynamic calibration" dynamic_calibration(
  data, static_solution, static_calibrated_parameters; base_blocks)
```

Press `Shift+Enter`.

This rebuilds the equation blocks and reruns the static and dynamic calibration with the updated code.

### After changing data assignment

If a function such as `assign_data!` or `adjust_growth_inflation!` has been changed, the data must also be recreated.

Highlight everything from:

```julia
data = assign_data!(ModelDictionary(model))
```

down to and including the complete `baseline = @log_time "dynamic calibration" dynamic_calibration(...)` call.

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

Do not run a data file (`*Data.jl`) in the same session as `Calibrate.jl`. It fails on `module Settings`. Use a new REPL, or run the data file from a terminal (see below).

### Run a shock

Run `Calibrate.jl` once, then run `Shock.jl`. `Shock.jl` loads `Output/baseline.parquet`, applies a shock and writes `Output/shock_report.html`. You do not need to calibrate again before each new shock, if the equations and data have not changed. To make a new shock, copy `Shock.jl` and change the shock definition.

### Run from a terminal

You can also run the model without the VS Code extension. In the GREU folder:

```
julia --project=. -t 8
```

Then run `include("model_julia/Calibrate.jl")`. To run one data file alone:

```
julia --project=. model_julia/modules/EmissionsData.jl
```

### Before sharing changes

During development, it is sufficient to run only the sections needed to test the current change.

Before committing or sharing the changes, select the entire `Calibrate.jl` file with `Ctrl+A` and run it with `Shift+Enter`. This checks the complete calibration, residual tests, zero-shock test, baseline export and reports. Use `Output/save_solution_as_previous.cmd` to keep the local previous solution. Use `Output/copy_previous_to_pdrive.cmd` to share it on `P:\GREU`, and `Output/copy_previous_from_pdrive.cmd` to copy the shared file back.
