#!/usr/bin/env julia

using TOML

const PROJECT_ROOT = normpath(joinpath(@__DIR__, ".."))
const PROJECT_FILE = joinpath(PROJECT_ROOT, "Project.toml")

Base.@kwdef mutable struct ReleaseOptions
    version::Union{Nothing, String} = nothing
    bump::Union{Nothing, String} = nothing
    tag_prefix::String = "v"
    tag::Bool = true
    push::Bool = false
    github_release::Bool = false
    commit_version::Bool = false
    allow_dirty::Bool = false
    execute::Bool = false
    remote::String = "origin"
    branch::Union{Nothing, String} = nothing
    message::Union{Nothing, String} = nothing
    notes::Union{Nothing, String} = nothing
end

function print_usage()
    return println("""
           Usage:
             julia --project=. scripts/release_project.jl [OPTIONS]

           Common workflows:
             # Preview a patch release: bump Project.toml, commit, tag, and push
             julia --project=. scripts/release_project.jl --bump patch --commit-version --push

             # Execute the same release
             julia --project=. scripts/release_project.jl --bump patch --commit-version --push --execute

             # Release an explicit version and create a GitHub release through gh
             julia --project=. scripts/release_project.jl --version 1.6.0 --commit-version --push --github-release --execute

           Version:
             --version X.Y.Z       Release this exact version.
             --release-version X.Y.Z
                                   Alias for --version.
             --bump patch|minor|major
                                   Compute the next version from Project.toml.

           Git:
             --commit-version      Commit the Project.toml version bump.
             --tag / --no-tag      Create an annotated release tag. Default: --tag.
             --push                Push the branch and tag to the remote.
             --remote NAME         Git remote used for push. Default: origin.
             --branch NAME         Branch to push. Default: current branch.
             --tag-prefix PREFIX   Tag prefix. Default: v.
             --message TEXT        Commit and tag message. Default: Release vX.Y.Z.
             --allow-dirty         Permit running with unrelated local changes.

           Release:
             --github-release      Run: gh release create TAG --title TAG --notes ...
             --notes TEXT          Notes used for GitHub release.

           Safety:
             --execute             Actually write files and run git/gh commands.
                                   Without this flag the script is a dry-run.
             -h, --help            Show this help.
           """)
end

function parse_args(args)
    options = ReleaseOptions()
    i = 1
    while i <= length(args)
        arg = args[i]
        if arg == "--version" || arg == "--release-version"
            i += 1
            i > length(args) && die("--version requires a value")
            options.version = args[i]
        elseif arg == "--bump"
            i += 1
            i > length(args) && die("--bump requires patch, minor, or major")
            options.bump = args[i]
        elseif arg == "--tag-prefix"
            i += 1
            i > length(args) && die("--tag-prefix requires a value")
            options.tag_prefix = args[i]
        elseif arg == "--message"
            i += 1
            i > length(args) && die("--message requires a value")
            options.message = args[i]
        elseif arg == "--notes"
            i += 1
            i > length(args) && die("--notes requires a value")
            options.notes = args[i]
        elseif arg == "--remote"
            i += 1
            i > length(args) && die("--remote requires a value")
            options.remote = args[i]
        elseif arg == "--branch"
            i += 1
            i > length(args) && die("--branch requires a value")
            options.branch = args[i]
        elseif arg == "--commit-version"
            options.commit_version = true
        elseif arg == "--tag"
            options.tag = true
        elseif arg == "--no-tag"
            options.tag = false
        elseif arg == "--push"
            options.push = true
        elseif arg == "--github-release"
            options.github_release = true
            options.push = true
        elseif arg == "--allow-dirty"
            options.allow_dirty = true
        elseif arg == "--execute"
            options.execute = true
        elseif arg == "--help" || arg == "-h"
            print_usage()
            exit(0)
        else
            die("Unknown option: $arg")
        end
        i += 1
    end
    return options
end

function die(message::AbstractString, code::Int = 2)
    println(stderr, message)
    return exit(code)
end

function run_capture(cmd::Cmd)
    return readchomp(pipeline(cmd; stderr = devnull))
end

function command_text(cmd::Cmd)
    return join(cmd.exec, " ")
end

function run_step(cmd::Cmd, options::ReleaseOptions)
    if options.execute
        println("RUN  ", command_text(cmd))
        run(cmd)
    else
        println("DRY  ", command_text(cmd))
    end
end

function current_branch()
    branch = run_capture(`git -C $PROJECT_ROOT branch --show-current`)
    isempty(branch) && die("Cannot determine the current git branch.")
    return branch
end

function git_status()
    return readchomp(`git -C $PROJECT_ROOT status --porcelain`)
end

function require_clean_worktree(options::ReleaseOptions)
    if options.allow_dirty
        return nothing
    end

    status = git_status()
    if !isempty(status)
        println(stderr, "Working tree has local changes. Commit/stash them, or rerun with --allow-dirty.")
        println(stderr, status)
        exit(2)
    end
    return nothing
end

function read_project_version()
    project = TOML.parsefile(PROJECT_FILE)
    version = get(project, "version", nothing)
    version === nothing && die("Project.toml does not define a version.")
    return String(version)
end

function parse_version(version::AbstractString)
    m = match(r"^(\d+)\.(\d+)\.(\d+)$", version)
    m === nothing && die("Version must use X.Y.Z semantic version form: $version")
    return parse.(Int, m.captures)
end

function bump_version(version::AbstractString, bump::AbstractString)
    major, minor, patch = parse_version(version)
    if bump == "major"
        return "$(major + 1).0.0"
    elseif bump == "minor"
        return "$major.$(minor + 1).0"
    elseif bump == "patch"
        return "$major.$minor.$(patch + 1)"
    end
    return die("--bump must be one of: patch, minor, major")
end

function replace_project_version!(new_version::AbstractString, options::ReleaseOptions)
    text = read(PROJECT_FILE, String)
    new_text = replace(text, r"(?m)^version\s*=\s*\"[^\"]+\"" => "version = \"$new_version\""; count = 1)
    new_text == text && die("Could not update version in Project.toml.")

    if options.execute
        write(PROJECT_FILE, new_text)
        println("Updated Project.toml version to $new_version")
    else
        println("DRY  update Project.toml version to $new_version")
    end
end

function tag_exists(tag_name::AbstractString)
    return success(`git -C $PROJECT_ROOT rev-parse --quiet --verify refs/tags/$tag_name`)
end

function validate_options(options::ReleaseOptions)
    options.version !== nothing && options.bump !== nothing && die("Use either --version or --bump, not both.")
    options.version === nothing && options.bump === nothing && die("Specify --version X.Y.Z or --bump patch|minor|major.")
    options.push && !options.tag && die("--push requires a tag; remove --no-tag or do not use --push.")
    options.github_release && !options.push && die("--github-release requires --push.")
    return nothing
end

function main(args)
    options = parse_args(args)
    validate_options(options)

    cd(PROJECT_ROOT)
    require_clean_worktree(options)

    old_version = read_project_version()
    new_version = options.version === nothing ? bump_version(old_version, options.bump) : options.version
    parse_version(new_version)

    tag_name = "$(options.tag_prefix)$(new_version)"
    release_message = something(options.message, "Release $tag_name")
    release_notes = something(options.notes, release_message)
    branch = something(options.branch, current_branch())

    tag_exists(tag_name) && die("Tag already exists locally: $tag_name")

    println("Release plan")
    println("  Project:  $PROJECT_ROOT")
    println("  Version:  $old_version -> $new_version")
    println("  Tag:      $(options.tag ? tag_name : "(disabled)")")
    println("  Branch:   $branch")
    println("  Remote:   $(options.remote)")
    println("  Mode:     $(options.execute ? "execute" : "dry-run")")
    println()

    version_changed = old_version != new_version
    version_changed && replace_project_version!(new_version, options)

    if options.commit_version && version_changed
        run_step(`git -C $PROJECT_ROOT add Project.toml`, options)
        run_step(`git -C $PROJECT_ROOT commit -m $release_message`, options)
    elseif options.commit_version
        println("NOTE Project.toml already has version $new_version; skipping version commit.")
    elseif version_changed
        println("NOTE Project.toml is not committed because --commit-version was not provided.")
    end

    if options.tag
        run_step(`git -C $PROJECT_ROOT tag -a $tag_name -m $release_message`, options)
    end

    if options.push
        run_step(`git -C $PROJECT_ROOT push $(options.remote) $branch`, options)
        run_step(`git -C $PROJECT_ROOT push $(options.remote) $tag_name`, options)
    end

    if options.github_release
        run_step(`gh release create $tag_name --title $tag_name --notes $release_notes`, options)
    end

    println()
    println(options.execute ? "Release workflow completed." : "Dry-run completed. Add --execute to apply these steps.")
    return nothing
end

main(ARGS)
