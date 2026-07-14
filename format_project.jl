#!/usr/bin/env julia

const PROJECT_ROOT = normpath(@__DIR__)
const FORMATTER_MODULE = Ref{Module}()
const DEFAULT_EXCLUDED_DIRS = Set([".git", ".julia", ".pkg", ".codegraph", ".reasonix", ".kilo", "output"])

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

    for arg in args
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

function collect_julia_files(paths::Vector{String}, include_all::Bool)
    files = String[]

    for raw_path in paths
        path = abspath(PROJECT_ROOT, raw_path)
        if isfile(path)
            endswith(path, ".jl") && push!(files, path)
        elseif isdir(path)
            for (root, dirs, names) in walkdir(path)
                filter!(dir -> !should_skip_dir(joinpath(root, dir), include_all), dirs)
                for name in names
                    endswith(name, ".jl") && push!(files, joinpath(root, name))
                end
            end
        else
            println(stderr, "Path does not exist: $raw_path")
            exit(2)
        end
    end

    unique!(sort!(files))
    return files
end

function format_files(files::Vector{String}; check::Bool, verbose::Bool)
    changed = String[]
    failed = Pair{String, Any}[]
    formatter = getfield(FORMATTER_MODULE[], :format)

    for file in files
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
    println("  Project: $(PROJECT_ROOT)")
    println("  Mode:    $(check ? "check" : "format")")
    println("  Files:   $(length(files))")
    println("  Changed: $(length(changed))")
    println("  Failed:  $(length(failed))")

    if !isempty(changed)
        println()
        println(check ? "Files that need formatting:" : "Files formatted:")
        for file in changed
            println("  ", relpath(file, PROJECT_ROOT))
        end
    end

    if !isempty(failed)
        println()
        println("Files that failed:")
        for (file, err) in failed
            println("  ", relpath(file, PROJECT_ROOT), " :: ", sprint(showerror, err))
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
