# ====================================================================
# Run All Julia Scripts - PowerShell Script
# ====================================================================
# This script runs all Julia analysis and benchmarking scripts
# sequentially with clear output messages.
#
# Usage:
#   .\run_all_scripts.ps1
#   powershell -ExecutionPolicy Bypass -File .\run_all_scripts.ps1
# ====================================================================

# Set error action to stop on first error
$ErrorActionPreference = "Stop"

# Get project root
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Julia Scripts Execution Suite" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Project Root: $projectRoot" -ForegroundColor White
Write-Host "Starting execution at: $(Get-Date)" -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan

# Array of scripts to run
$scripts = @(
    @{
        name = "Main_function.jl"
        description = "SFR Curve Analysis and Visualization"
    },
    @{
        name = "check_DiffProbTypeAndFCRBindings.jl"
        description = "Analysis of Different Probability Types and FCR Bindings"
    },
    @{
        name = "eval_BFSFRMemoryAndCalTime.jl"
        description = "Performance Analysis and Benchmarking"
    },
    @{
        name = "eval_benchmark_performance.jl"
        description = "Comprehensive Benchmark Analysis"
    }
)

$scriptIndex = 1
$totalScripts = $scripts.Count

foreach ($script in $scripts) {
    Write-Host ""
    Write-Host ("------" * 11) -ForegroundColor DarkCyan
    Write-Host "[$scriptIndex/$totalScripts] Running $($script.name)" -ForegroundColor Yellow
    Write-Host "      Description: $($script.description)" -ForegroundColor White
    Write-Host ("------" * 11) -ForegroundColor DarkCyan

    $scriptPath = Join-Path $projectRoot $script.name

    if (Test-Path $scriptPath) {
        try {
            & julia $scriptPath
            Write-Host "[OK] $($script.name) completed successfully" -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] Error executing $($script.name): $_" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "[ERROR] Error: $($script.name) not found at $scriptPath" -ForegroundColor Red
        exit 1
    }

    $scriptIndex++
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "All scripts completed successfully!" -ForegroundColor Green
Write-Host "Completion time: $(Get-Date)" -ForegroundColor White
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Output Summary:" -ForegroundColor Yellow
Write-Host "  - Results saved to: ./out/" -ForegroundColor White
Write-Host "  - Data exported to: ./res/" -ForegroundColor White
Write-Host "  - Benchmark results saved to: ./out/benchmark/" -ForegroundColor White
Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
