# Refresh checked-in Eurostat-sourced data.
#
# Each section is self-contained (include + refresh call), so it can be selected
# and sent to an interactive terminal on its own.

# ==============================================================================
# Common Eurostat industry and product resolution
# ==============================================================================
include(joinpath(@__DIR__, "modules", "IndustryResolutionData.jl"))

IndustryResolutionData.refresh_industry_resolution!()

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
# Gross value added data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "GrossValueAddedData.jl"))

GrossValueAddedData.refresh_gross_value_added_data!()

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

# ==============================================================================
# Government data
# ==============================================================================
include(joinpath(@__DIR__, "modules", "GovernmentData.jl"))

GovernmentData.refresh_government_data!()

# ============================================================================
# Cross-source data consistency diagnostics (read-only; before reconciliation)
# ============================================================================
include(joinpath(@__DIR__, "modules", "DataConsistencyTests.jl"))

DataConsistencyTests.run_all_tests()

# ============================================================================
# Reconcile detailed production taxes/subsidies before industry-sector shares
# ============================================================================
include(joinpath(@__DIR__, "modules", "TaxesData.jl"))

TaxesData.reconcile_net_production_taxes!()

# ============================================================================
# Industry-sector share data
# ============================================================================
include(joinpath(@__DIR__, "modules", "IndustrySectorsData.jl"))

IndustrySectorsData.refresh_industry_sector_shares!()
