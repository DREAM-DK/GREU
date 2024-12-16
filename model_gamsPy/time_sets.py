from main import container
Set = container.addSet

t = Set("t", "Year", records=range(first_data_year, terminal_year + 1))

t0 = Set(name="t0", domain=t, is_singleton=True, description="Year before first main_endogenous year")
t1 = Set(name="t1", domain=t, is_singleton=True, description="First main_endogenous year")
t2 = Set(name="t2", domain=t, is_singleton=True, description="Second main_endogenous year")
tEnd = Set(name="tEnd", domain=t, is_singleton=True, description="Final year modeled (terminal year)")
tBase = Set(name="tBase", domain=t, is_singleton=True, records=[first_data_year], description="Base year where prices are set to 1")
tDataEnd = Set(name="tDataEnd", domain=t, is_singleton=True, records=[calibration_year], description="Last data year")

def set_time_periods(start, end):
  t0.setRecords([start - 1])
  t1.setRecords([start])
  t2.setRecords([start + 1])
  tEnd.setRecords([end])

set_time_periods(calibration_year, terminal_year)
