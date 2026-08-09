const PROJECT_ROOT = normpath(@__DIR__)
const FORMATTER_MODULE = Ref{Module}()
const DEFAULT_EXCLUDED_DIRS = Set([".git", ".julia", ".pkg", ".codegraph", ".reasonix", ".kilo", "output"])

struct HostPlatform
    name::String
    case_insensitive_paths::Bool
end

"""
识别当前宿主平台；未知类 Unix 系统使用 POSIX 路径规则。
"""
function detect_host_platform()
    Sys.iswindows() && return HostPlatform("Windows", true)
    Sys.isapple() && return HostPlatform("macOS", false)
    Sys.islinux() && return HostPlatform("Linux", false)
    Sys.isfreebsd() && return HostPlatform("FreeBSD", false)
    return HostPlatform("$(Sys.KERNEL)-$(Sys.ARCH)", false)
end

const HOST_PLATFORM = detect_host_platform()

function print_usage()
    return println("""
           Usage:
             julia --project=. format_project.jl [--check] [--verbose] [--all] [PATH...]

           Modes:
             default     Format Julia files in place.
             --check     Check formatting without writing files. Exits 1 if changes are needed.

           Options:
             -v, --verbose   Print every formatted or checked file.
             --all           Include normally skipped generated/cache directories.
             -h, --help      Show this help.

           Paths:
             PATH... defaults to the project root. Files and directories are both accepted.
           """)
end

function load_formatter!()
    try
        FORMATTER_MODULE[] = Base.require(Main, :JuliaFormatter)
    catch err
        if err isa ArgumentError || err isa LoadError
            println(stderr, "JuliaFormatter is not available in this Julia environment.")
            println(stderr, "Install it once with:")
            println(stderr, "  julia --project=. -e 'import Pkg; Pkg.add(\"JuliaFormatter\")'")
            exit(2)
        end
        rethrow()
    end
    return nothing
end

function parse_args(args)
    check = false
    verbose = false
    include_all = false
    paths = String[]

    for arg ∈ args
        if arg == "--check"
            check = true
        elseif arg == "--verbose" || arg == "-v"
            verbose = true
        elseif arg == "--all"
            include_all = true
        elseif arg == "--help" || arg == "-h"
            print_usage()
            exit(0)
        elseif startswith(arg, "-")
            println(stderr, "Unknown option: $arg")
            print_usage()
            exit(2)
        else
            push!(paths, arg)
        end
    end

    isempty(paths) && push!(paths, PROJECT_ROOT)
    return (; check, verbose, include_all, paths)
end

function should_skip_dir(dir::AbstractString, include_all::Bool)
    include_all && return false
    dir_name = basename(normpath(dir))
    return startswith(dir_name, ".") || dir_name in DEFAULT_EXCLUDED_DIRS
end

function resolve_input_path(raw_path::AbstractString)
    expanded_path = expanduser(raw_path)
    return normpath(isabspath(expanded_path) ? expanded_path : joinpath(PROJECT_ROOT, expanded_path))
end

is_julia_file(path::AbstractString) = lowercase(splitext(path)[2]) == ".jl"

function normalize_file_list!(files::Vector{String})
    sort!(files; by = path -> HOST_PLATFORM.case_insensitive_paths ? lowercase(path) : path)
    unique!(path -> HOST_PLATFORM.case_insensitive_paths ? lowercase(path) : path, files)
    return files
end

function collect_julia_files(paths::Vector{String}, include_all::Bool)
    files = String[]

    for raw_path ∈ paths
        path = resolve_input_path(raw_path)
        if isfile(path)
            is_julia_file(path) && push!(files, path)
        elseif isdir(path)
            for (root, dirs, names) ∈ walkdir(path)
                filter!(dir -> !should_skip_dir(joinpath(root, dir), include_all), dirs)
                for name ∈ names
                    is_julia_file(name) && push!(files, normpath(joinpath(root, name)))
                end
            end
        else
            println(stderr, "Path does not exist: $raw_path")
            exit(2)
        end
    end

    return normalize_file_list!(files)
end

function format_files(files::Vector{String}; check::Bool, verbose::Bool)
    changed = String[]
    failed = Pair{String, Any}[]
    formatter = getfield(FORMATTER_MODULE[], :format)

    for file ∈ files
        verbose && println(if check
            "Checking $(relpath(file, PROJECT_ROOT))"
        else
            "Formatting $(relpath(file, PROJECT_ROOT))"
        end)
        try
            already_formatted = Base.invokelatest(formatter, file; overwrite = !check, throw_on_error = true)
            already_formatted || push!(changed, file)
        catch err
            push!(failed, file => err)
        end
    end

    return (; changed, failed)
end

function print_summary(files, changed, failed; check::Bool)
    println()
    println("JuliaFormatter summary")
    println("  Platform: $(HOST_PLATFORM.name) ($(Sys.ARCH))")
    println("  Project: $(PROJECT_ROOT)")
    println("  Mode:    $(check ? "check" : "format")")
    println("  Files:   $(length(files))")
    println("  Changed: $(length(changed))")
    println("  Failed:  $(length(failed))")

    if !isempty(changed)
        println()
        println(check ? "Files that need formatting:" : "Files formatted:")
        for file ∈ changed
            println("  ", relpath(file, PROJECT_ROOT))
        end
    end

    if !isempty(failed)
        println()
        println("Files that failed:")
        for (file, err) ∈ failed
            # 解析异常可能携带整份源码；限制单条诊断长度，保持终端和 CI 日志可读。
            message = first(split(sprint(showerror, err), '\n'))
            compact_message = length(message) > 240 ? first(message, 237) * "..." : message
            println("  ", relpath(file, PROJECT_ROOT), " :: ", nameof(typeof(err)), " :: ", compact_message)
        end
    end
end

function main(args)
    options = parse_args(args)
    load_formatter!()

    files = collect_julia_files(options.paths, options.include_all)
    isempty(files) && println("No Julia files found.")

    result = format_files(files; check = options.check, verbose = options.verbose)
    print_summary(files, result.changed, result.failed; check = options.check)

    if !isempty(result.failed)
        exit(2)
    elseif options.check && !isempty(result.changed)
        exit(1)
    end
    return nothing
end

main(ARGS)
