#!/bin/bash
# ====================================================================
# Run All Julia Scripts - Bash Script
# ====================================================================
# This script runs all Julia analysis and benchmarking scripts
# sequentially with clear output messages.
#
# Usage:
#   ./run_all_scripts.sh
#   bash run_all_scripts.sh
# ====================================================================

set -e  # Exit on any error

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

echo "======================================================================"
echo "Julia Scripts Execution Suite"
echo "======================================================================"
echo "Project Root: $PROJECT_ROOT"
echo "Starting execution at: $(date)"
echo "======================================================================"

# Script 1: Main Function
echo ""
echo "----------------------------------------------------------------------"
echo "[1/4] Running Main_function.jl"
echo "      Description: SFR Curve Analysis and Visualization"
echo "----------------------------------------------------------------------"
if [ -f "Main_function.jl" ]; then
    julia Main_function.jl
    echo "[OK] Main_function.jl completed successfully"
else
    echo "[ERROR] Main_function.jl not found!"
    exit 1
fi

# Script 2: Check Different Probability Types and FCR Bindings
echo ""
echo "----------------------------------------------------------------------"
echo "[2/4] Running check_DiffProbTypeAndFCRBindings.jl"
echo "      Description: Analysis of Different Probability Types"
echo "----------------------------------------------------------------------"
if [ -f "check_DiffProbTypeAndFCRBindings.jl" ]; then
    julia check_DiffProbTypeAndFCRBindings.jl
    echo "[OK] check_DiffProbTypeAndFCRBindings.jl completed successfully"
else
    echo "[ERROR] check_DiffProbTypeAndFCRBindings.jl not found!"
    exit 1
fi

# Script 3: BF-SFR Memory and Calculation Time
echo ""
echo "----------------------------------------------------------------------"
echo "[3/4] Running eval_BFSFRMemoryAndCalTime.jl"
echo "      Description: Performance Analysis and Benchmarking"
echo "----------------------------------------------------------------------"
if [ -f "eval_BFSFRMemoryAndCalTime.jl" ]; then
    julia eval_BFSFRMemoryAndCalTime.jl
    echo "[OK] eval_BFSFRMemoryAndCalTime.jl completed successfully"
else
    echo "[ERROR] eval_BFSFRMemoryAndCalTime.jl not found!"
    exit 1
fi

# Script 4: Benchmark Performance
echo ""
echo "----------------------------------------------------------------------"
echo "[4/4] Running eval_benchmark_performance.jl"
echo "      Description: Comprehensive Benchmark Analysis"
echo "----------------------------------------------------------------------"
if [ -f "eval_benchmark_performance.jl" ]; then
    julia eval_benchmark_performance.jl
    echo "[OK] eval_benchmark_performance.jl completed successfully"
else
    echo "[ERROR] eval_benchmark_performance.jl not found!"
    exit 1
fi

echo ""
echo "======================================================================"
echo "All scripts completed successfully!"
echo "Completion time: $(date)"
echo "======================================================================"
echo ""
echo "Output Summary:"
echo "  - Results saved to: ./out/"
echo "  - Data exported to: ./res/"
echo "  - Benchmark results saved to: ./out/benchmark/"
echo ""
echo "======================================================================"
