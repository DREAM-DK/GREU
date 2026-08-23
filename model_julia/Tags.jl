module Tags

using SquareModels: Tag

"""Variables that are kept constant in the forecast"""
const ForecastConstant = Tag(:forecast_constant)

"""Variables that are set to zero in the forecast"""
const ForecastZero = Tag(:forecast_zero)

"""Parameters that stay endogenous in the dynamic calibration."""
const DynamicCalibration = Tag(:dynamic_calibration)

"""Variables that belong to capital adjustment costs."""
const CapitalAdjustmentCostsTag = Tag(:CapitalAdjustmentCosts)

end
