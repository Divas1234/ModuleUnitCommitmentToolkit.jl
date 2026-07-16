# ============================================================================
# Input data reading and processing module.
#
# This module provides functions for:
# - Reading data from Excel files
# - Formatting and processing input data for the optimization model
# - Displaying boundary conditions and system information
#
# Exported Functions:
# - `readxlssheet()`: Reads all input data from Excel file
# - `forminputdata(...)`: Formats and processes raw input data into model-ready structures
# - `boundrycondition(...)`: Displays boundary conditions and system information
# ============================================================================

include("_formatteddata.jl")
include("_readdatafromexcel.jl")
include("_showboundrycase.jl")
include("_get_totalboundarydata.jl")

export readxlssheet, forminputdata, boundrycondition

println("\t→ Input data module loaded and ready for UC modeling.")
