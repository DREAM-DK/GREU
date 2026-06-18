module Log

import Logging
import Dates

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
	buf = IOBuffer()
	print(buf, prefix, msg)
	for (k, v) in kwargs
		# Render exceptions like the console: real newlines + a readable
		# Stacktrace, rather than an escaped "$v" dump of the backtrace.
		if k === :exception && v isa Tuple{Any, Any}
			print(buf, "\n")
			showerror(buf, v[1], v[2])
		elseif k === :exception
			print(buf, "\n")
			showerror(buf, v)
		else
			print(buf, " ", k, "=", v)
		end
	end
	out = String(take!(buf))
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

# Write an exception + backtrace to the log file only. The console is left
# untouched so Julia's normal red stacktrace still prints on rethrow.
function log_exception(e, bt)
	io = _file_io[]
	io === nothing && return
	println(io, "="^70)
	println(io, "EXCEPTION at ", Dates.now())
	showerror(io, e, bt)
	println(io)
	println(io, "="^70)
	flush(io)
end

# Write any exception thrown by `expr` to the log file, then rethrow so the
# console behaves normally (works at top level and in the REPL).
macro log_errors(expr)
	quote
		try
			$(esc(expr))
		catch e
			log_exception(e, catch_backtrace())
			rethrow()
		end
	end
end

macro log_time(expr)
	label = string(expr)
	quote
		local _result, _elapsed = @timed $(esc(expr))
		@info $label * " ($(round(_elapsed, digits=2))s)"
		_result
	end
end

setup!(file=joinpath(@__DIR__, "..", "greu.log"))

end # module Log
