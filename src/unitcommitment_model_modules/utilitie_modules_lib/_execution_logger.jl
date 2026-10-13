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
	orig_stdout::Any
	orig_stderr::Any
	stdout_wr::Any
	stderr_wr::Any
	tee_out_proc::Any
	tee_err_proc::Any
	start_time::DateTime
end

const _LOGGER_STATE = ExecutionLoggerState(
	false, "", nothing, nothing, nothing, nothing, nothing, nothing, Dates.now()
)

"""
    start_execution_log!(is_record_log=1; log_dir=joinpath(pwd(), "output", "log"), prefix="mf")

Start recording all console output (Julia `stdout`/`stderr` and C library output
such as Gurobi solver logs) to an automatically named timestamped `.log` file
in `output/log/`, while simultaneously displaying output in the terminal in real time.

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
		stop_execution_log!()
	end

	mkpath(log_dir)
	timestamp = Dates.format(Dates.now(), "yyyymmdd_HHMMSS")
	log_filename = "$(prefix)_$(timestamp).log"
	log_filepath = abspath(joinpath(log_dir, log_filename))

	start_dt = Dates.now()

	# Write log file header
	open(log_filepath, "w") do log_io
		println(log_io, "="^80)
		println(log_io, "Execution Log Started : $(Dates.format(start_dt, "yyyy-mm-dd HH:MM:SS"))")
		println(log_io, "Log File              : $log_filepath")
		println(log_io, "Working Directory     : $(pwd())")
		println(log_io, "Julia Version         : $(VERSION)")
		println(log_io, "="^80)
	end

	orig_out = stdout
	orig_err = stderr

	out_rd, out_wr = redirect_stdout()
	err_rd, err_wr = redirect_stderr()

	# Spawn OS-level `tee -a` processes so C-level solver output (Gurobi) streams
	# in real time even while Julia's main thread is inside a blocking ccall.
	tee_out_proc = run(pipeline(`tee -a $log_filepath`; stdin = out_rd, stdout = orig_out); wait = false)
	tee_err_proc = run(pipeline(`tee -a $log_filepath`; stdin = err_rd, stdout = orig_err); wait = false)
	close(out_rd)
	close(err_rd)

	_LOGGER_STATE.active = true
	_LOGGER_STATE.log_filepath = log_filepath
	_LOGGER_STATE.orig_stdout = orig_out
	_LOGGER_STATE.orig_stderr = orig_err
	_LOGGER_STATE.stdout_wr = out_wr
	_LOGGER_STATE.stderr_wr = err_wr
	_LOGGER_STATE.tee_out_proc = tee_out_proc
	_LOGGER_STATE.tee_err_proc = tee_err_proc
	_LOGGER_STATE.start_time = start_dt

	println("📝 Execution log recording started: $log_filepath")
	flush(stdout)
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

	if _LOGGER_STATE.tee_out_proc !== nothing
		try
			wait(_LOGGER_STATE.tee_out_proc)
		catch
		end
	end
	if _LOGGER_STATE.tee_err_proc !== nothing
		try
			wait(_LOGGER_STATE.tee_err_proc)
		catch
		end
	end

	end_dt = Dates.now()
	elapsed_sec = round((end_dt - _LOGGER_STATE.start_time).value / 1000.0; digits = 2)

	try
		open(log_filepath, "a") do log_io
			println(log_io, "\n" * "="^80)
			println(log_io, "Execution Log Finished: $(Dates.format(end_dt, "yyyy-mm-dd HH:MM:SS"))")
			println(log_io, "Total Elapsed Time    : $(elapsed_sec) seconds")
			println(log_io, "="^80)
		end
	catch
	end

	# Strip ANSI color codes and VS Code / terminal shell integration sequences (OSC 633, CSI, etc.)
	try
		_sanitize_log_file!(log_filepath)
	catch
	end

	_LOGGER_STATE.active = false
	_LOGGER_STATE.tee_out_proc = nothing
	_LOGGER_STATE.tee_err_proc = nothing

	return log_filepath
end

"""
    _sanitize_log_file!(filepath::AbstractString)

Strip terminal control characters such as ANSI escape codes and terminal OSC
sequences (e.g., VS Code Shell Integration `OSC 633`) so that saved logs remain
clean and human-readable in plain text viewers.
"""
function _sanitize_log_file!(filepath::AbstractString)
	if !isfile(filepath)
		return
	end
	raw = read(filepath, String)
	# Strip OSC sequences: \e\] ... (\a | \e\\)
	cleaned = replace(raw, r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)" => "")
	# Strip ANSI CSI sequences: \e\[ ... [@-~]
	cleaned = replace(cleaned, r"\x1b\[[0-?]*[ -/]*[@-~]" => "")
	# Strip other standard escape sequences: \e[@-Z\\-_]
	cleaned = replace(cleaned, r"\x1b[@-Z\\-_]" => "")
	# Write sanitized content back
	write(filepath, cleaned)
end


# Ensure log is properly flushed and closed on normal or abnormal exit
atexit(() -> begin
	if _LOGGER_STATE.active
		stop_execution_log!()
	end
end)

export start_execution_log!, stop_execution_log!

end # if !isdefined(@__MODULE__, :_EXECUTION_LOGGER_INCLUDED)
