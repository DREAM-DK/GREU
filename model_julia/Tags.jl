module Tags

using SquareModels: Tag

"""Variables that are kept constant in the forecast"""
const ForecastConstant = Tag(:forecast_constant)

"""Variables that are set to zero in the forecast"""
const ForecastZero = Tag(:forecast_zero)

"""Parameters where the calibration year value changes when calibrated with model consistent expectations."""
const DynamicCalibration = Tag(:dynamic_calibration)

"""Equations that replace the equations other modules give for the same variables."""
const Override = Tag(:override)

end
