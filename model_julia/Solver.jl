module Solver

using JuMP: Model, FEASIBILITY_SENSE, set_objective_sense, set_optimizer_attribute
import CONOPT
import GAMS
import Ipopt

using ..Settings: solver, conopt_lib, gams_sysdir

"""
    SquareModel()
Return a JuMP `Model` configured for solving as a square nonlinear system.
The optimizer is selected by `Settings.solver` (`:Ipopt`, `:CONOPT`, or `:GAMS_CONOPT`).
"""
SquareModel() = SquareModel(Val(solver))

function SquareModel(::Val{S}) where {S}
	error("Unknown solver $(repr(S)); set Settings.solver to one of :Ipopt, :CONOPT, :GAMS_CONOPT")
end

function _set_conopt_options!(model)
	set_optimizer_attribute(model, "lmmxsf", 1)
	set_optimizer_attribute(model, "lim_pre_msg", 400)
	return model
end

SquareModel(::Val{:Ipopt}) = Model(Ipopt.Optimizer)

function SquareModel(::Val{:CONOPT})
	@assert isfile(conopt_lib) "CONOPT library not found at $conopt_lib"
	model = Model(CONOPT.Optimizer)
	set_objective_sense(model, FEASIBILITY_SENSE)
	return _set_conopt_options!(model)
end

function SquareModel(::Val{:GAMS_CONOPT})
	gams_exe = joinpath(gams_sysdir, "gams.exe")
	@assert isfile(gams_exe) "GAMS not found at $gams_exe"
	model = Model(GAMS.Optimizer)
	set_objective_sense(model, FEASIBILITY_SENSE)
	set_optimizer_attribute(model, "SysDir", gams_sysdir)
	set_optimizer_attribute(model, GAMS.ModelType(), "CNS")
	set_optimizer_attribute(model, "CNS", "CONOPT4")
	set_optimizer_attribute(model, GAMS.Solver(), "CONOPT4")
	return _set_conopt_options!(model)
end

end
