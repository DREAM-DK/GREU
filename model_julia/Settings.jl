module Settings

const country_code = "DK"

const first_data_year = 2015
const base_year = 2019
const calibration_year = 2019
const terminal_year = 2025

const enabled_modules = [
  :SubmodelTemplate,
  :InputOutput,
]

# Solver backend: :Ipopt, :CONOPT (CONOPT.jl), or :GAMS_CONOPT (CONOPT via GAMS)
const solver = :GAMS_CONOPT

const pkg_root = abspath(joinpath(@__DIR__, ".."))
const conopt_lib = joinpath(pkg_root, "conopt-win-x86_64", "lib", "conopt4.dll")
const gams_sysdir = dirname("C:/GAMS/53/gams.exe")

end
