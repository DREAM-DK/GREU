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

const solver = :Ipopt # :CONOPT or :Ipopt

const pkg_root = abspath(joinpath(@__DIR__, ".."))
const conopt_lib_dir = joinpath(pkg_root, "conopt-win-x86_64", "lib")
const conopt_lib = joinpath(conopt_lib_dir, "conopt4.dll")

end
