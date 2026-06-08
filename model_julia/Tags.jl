module Tags

using SquareModels: Tag

"""Variables that are kept constant in the forecast"""
const ForecastConstant = Tag(:forecast_constant)

"""Variables that are set to zero in the forecast"""
const ForecastZero = Tag(:forecast_zero)

end
