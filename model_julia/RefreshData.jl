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
# Intermediate-input data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "IntermediatesData.jl"))

IntermediatesData.refresh_intermediates_data!()

# ==============================================================================
# Capital data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "CapitalData.jl"))

CapitalData.refresh_capital_data!()

# ==============================================================================
# Labor data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "LaborData.jl"))

LaborData.refresh_labor_data!()

# ==============================================================================
# Sector accounts data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "SectorAccountsData.jl"))

SectorAccountsData.refresh_sector_accounts_data!()
