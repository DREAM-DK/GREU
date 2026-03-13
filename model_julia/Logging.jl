module Log

import Logging

const _file_io = Ref{Union{IOStream, Nothing}}(nothing)

struct GREULogger <: Logging.AbstractLogger
	level::Logging.LogLevel
end

Logging.min_enabled_level(l::GREULogger) = l.level
Logging.shouldlog(::GREULogger, args...) = true
Logging.catch_exceptions(::GREULogger) = false

function Logging.handle_message(::GREULogger, level, msg, _mod, group, id, file, line; kwargs...)
	prefix = level >= Logging.Warn ? "⚠ " :
	         level <= Logging.Debug ? "· " : ""
	kvs = isempty(kwargs) ? "" : " " * join(("$k=$v" for (k, v) in kwargs), " ")
	out = string(prefix, msg, kvs)
	println(out)
	io = _file_io[]
	if io !== nothing
		println(io, out)
		flush(io)
	end
end

function setup!(; level=Logging.Info, file=nothing)
	if file !== nothing
		_file_io[] !== nothing && close(_file_io[])
		_file_io[] = open(file, "w")
	end
	Logging.global_logger(GREULogger(level))
end

macro log_time(expr)
	label = string(expr)
	quote
		local _result, _elapsed = @timed $(esc(expr))
		@info $label * " ($(round(_elapsed, digits=2))s)"
		_result
	end
end

export @log_time

end # module Log
