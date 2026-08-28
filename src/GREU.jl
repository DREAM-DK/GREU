# Load the GREU model and its calibration tools.
# Keep solves, tests, and file output in run files.
# Revise methods and active module choices.
# Restart after changes to imports, model variables, or loaded modules.
module GREU

const __revise_mode__ = :evalmeth

include(joinpath(@__DIR__, "..", "model_julia", "Model.jl"))
include(joinpath(@__DIR__, "..", "model_julia", "Calibration.jl"))

function __init__()
  Settings.square_model(model)
  return nothing
end

end # module
