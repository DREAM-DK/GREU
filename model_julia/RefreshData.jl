# Refresh checked-in Eurostat-sourced data.
#
# Each section is self-contained (include + refresh call), so it can be selected
# and sent to an interactive terminal on its own.

# ==============================================================================
# Input-output data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "InputOutputData.jl"))

InputOutputData.refresh_input_output_data!()

# ==============================================================================
# Production data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "ProductionData.jl"))

ProductionData.refresh_production_data!()

# ==============================================================================
# Sector accounts data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "SectorAccountsData.jl"))

SectorAccountsData.refresh_sector_accounts_data!()
