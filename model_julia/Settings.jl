module Settings

const country_code = "DK"
const currency_code = "MIO_NAC"
const input_output_dataset = "naio_10_cp1750"

const first_data_year = 2015
const base_year = 2020
const calibration_year = 2020
const terminal_year = 2035

const enabled_modules = [
  :SubmodelTemplate,
  :InputOutput,
]

const gams_dir = raw"C:\GAMS\51"
const gams_solver = "CONOPT"

end
