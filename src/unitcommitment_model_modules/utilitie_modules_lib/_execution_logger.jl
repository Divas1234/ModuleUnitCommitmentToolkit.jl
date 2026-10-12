# ============================================================================
# Execution Logger Module
#
# Provides automatic tee-logging of both Julia stdout/stderr and C-level
# solver output (e.g., Gurobi) to timestamped log files under `output/log/`.
# ============================================================================

if !isdefined(@__MODULE__, :_EXECUTION_LOGGER_INCLUDED)
const _EXECUTION_LOGGER_INCLUDED = true

using Dates

mutable struct ExecutionLoggerState
	active::Bool
	log_filepath::String
	log_io::Union{IOStream, Nothing}
	orig_stdout::Any
	orig_stderr::Any
	stdout_wr::Any
	stderr_wr::Any
	stdout_task::Union{Task, Nothing}
	stderr_task::Union{Task, Nothing}
	start_time::DateTime
end

const _LOGGER_STATE = ExecutionLoggerState(
	false, "", nothing, nothing, nothing, nothing, nothing, nothing, nothing, Dates.now()
)

"""
    start_execution_log!(is_record_log=1; log_dir=joinpath(pwd(), "output", "log"), prefix="mf")

Start recording all console output (Julia `stdout`/`stderr` and C library output
such as Gurobi solver logs) to an automatically named timestamped `.log` file
in `output/log/`, while simultaneously displaying output in the terminal.

# Arguments
- `is_record_log::Union{Bool, Integer}`: Explicit flag to enable (`1` or `true`)
  or disable (`0` or `false`) log recording.

Returns the absolute path to the created log file, or `nothing` if disabled.
"""
function start_execution_log!(
	is_record_log::Union{Bool, Integer} = 1;
	log_dir::AbstractString = joinpath(pwd(), "output", "log"),
	prefix::AbstractString = "mf",
)
	enabled = (is_record_log isa Bool) ? is_record_log : (is_record_log != 0)
	if !enabled
		println("ℹ Execution log recording is disabled (is_record_log = $is_record_log).")
		return nothing
	end

	if _LOGGER_STATE.active
		return _LOGGER_STATE.log_filepath
	end

	mkpath(log_dir)
	timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
	log_filename = "$(prefix)_$(timestamp).log"
	log_filepath = abspath(joinpath(log_dir, log_filename))

	log_io = open(log_filepath, "w")
	start_dt = Dates.now()

	# Write log file header
	println(log_io, "="^80)
	println(log_io, "Execution Log Started : $(Dates.format(start_dt, "yyyy-mm-dd HH:MM:SS"))")
	println(log_io, "Log File              : $log_filepath")
	println(log_io, "Working Directory     : $(pwd())")
	println(log_io, "Julia Version         : $(VERSION)")
	println(log_io, "="^80)
	flush(log_io)

	orig_out = stdout
	orig_err = stderr

	out_rd, out_wr = redirect_stdout()
	err_rd, err_wr = redirect_stderr()

	io_lock = ReentrantLock()

	out_task = @async begin
		try
			while !eof(out_rd)
				data = readavailable(out_rd)
				if !isempty(data)
					write(orig_out, data)
					flush(orig_out)
					lock(io_lock) do
						if isopen(log_io)
							write(log_io, data)
							flush(log_io)
						end
					end
				end
			end
		catch
			# Ignore pipe closure errors during shutdown
		end
	end

	err_task = @async begin
		try
			while !eof(err_rd)
				data = readavailable(err_rd)
				if !isempty(data)
					write(orig_err, data)
					flush(orig_err)
					lock(io_lock) do
						if isopen(log_io)
							write(log_io, data)
							flush(log_io)
						end
					end
				end
			end
		catch
			# Ignore pipe closure errors during shutdown
		end
	end

	_LOGGER_STATE.active = true
	_LOGGER_STATE.log_filepath = log_filepath
	_LOGGER_STATE.log_io = log_io
	_LOGGER_STATE.orig_stdout = orig_out
	_LOGGER_STATE.orig_stderr = orig_err
	_LOGGER_STATE.stdout_wr = out_wr
	_LOGGER_STATE.stderr_wr = err_wr
	_LOGGER_STATE.stdout_task = out_task
	_LOGGER_STATE.stderr_task = err_task
	_LOGGER_STATE.start_time = start_dt

	println("📝 Execution log recording started: $log_filepath")
	return log_filepath
end

"""
    stop_execution_log!()

Flush all output streams, restore original `stdout`/`stderr`, and close the
current execution log file.
"""
function stop_execution_log!()
	if !_LOGGER_STATE.active
		return nothing
	end

	log_filepath = _LOGGER_STATE.log_filepath
	println("\n📝 Saving execution log to: $log_filepath")

	try
		Libc.flush_cstdio()
		flush(stdout)
		flush(stderr)
	catch
	end

	try
		redirect_stdout(_LOGGER_STATE.orig_stdout)
	catch
	end
	try
		redirect_stderr(_LOGGER_STATE.orig_stderr)
	catch
	end

	try
		close(_LOGGER_STATE.stdout_wr)
	catch
	end
	try
		close(_LOGGER_STATE.stderr_wr)
	catch
	end

	if _LOGGER_STATE.stdout_task !== nothing
		try
			wait(_LOGGER_STATE.stdout_task)
		catch
		end
	end
	if _LOGGER_STATE.stderr_task !== nothing
		try
			wait(_LOGGER_STATE.stderr_task)
		catch
		end
	end

	end_dt = Dates.now()
	elapsed_sec = round((end_dt - _LOGGER_STATE.start_time).value / 1000.0; digits = 2)

	if _LOGGER_STATE.log_io !== nothing && isopen(_LOGGER_STATE.log_io)
		println(_LOGGER_STATE.log_io, "\n" * "="^80)
		println(_LOGGER_STATE.log_io, "Execution Log Finished: $(Dates.format(end_dt, "yyyy-mm-dd HH:MM:SS"))")
		println(_LOGGER_STATE.log_io, "Total Elapsed Time    : $(elapsed_sec) seconds")
		println(_LOGGER_STATE.log_io, "="^80)
		flush(_LOGGER_STATE.log_io)
		close(_LOGGER_STATE.log_io)
	end

	_LOGGER_STATE.active = false
	_LOGGER_STATE.log_io = nothing
	_LOGGER_STATE.stdout_task = nothing
	_LOGGER_STATE.stderr_task = nothing

	return log_filepath
end

# Ensure log is properly flushed and closed on normal or abnormal exit
atexit(() -> begin
	if _LOGGER_STATE.active
		stop_execution_log!()
	end
end)

export start_execution_log!, stop_execution_log!

end # if !isdefined(@__MODULE__, :_EXECUTION_LOGGER_INCLUDED)
