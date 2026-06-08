module Solver

using JuMP: Model, FEASIBILITY_SENSE, set_objective_sense, set_optimizer_attribute
import CONOPT
import Ipopt

using ..Settings: solver, conopt_lib

"""
    SquareModel()
Return a JuMP `Model` configured for solving as a square nonlinear system.
The optimizer is selected by `Settings.solver` (`:CONOPT` or `:Ipopt`).
"""
SquareModel() = SquareModel(Val(solver))

function SquareModel(::Val{S}) where {S}
	error("Unknown solver $(repr(S)); set Settings.solver to :CONOPT or :Ipopt")
end

function SquareModel(::Val{:CONOPT})
	@assert isfile(conopt_lib) "CONOPT library not found at $conopt_lib"
	model = Model(CONOPT.Optimizer)
	set_objective_sense(model, FEASIBILITY_SENSE)
	set_optimizer_attribute(model, "lmmxsf", 1)
	set_optimizer_attribute(model, "lim_pre_msg", 400)
	return model
end

SquareModel(::Val{:Ipopt}) = Model(Ipopt.Optimizer)

end
