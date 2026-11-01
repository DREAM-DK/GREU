# Labor types must match the names in production_labor_types.csv.
# The data generator is deliberately independent of these settings.
module LaborNestingSettings

const labor_types = [:low, :medium, :high]

# Same specification pattern as ProductionSettings.full_nesting.
# Each nest combines exactly two children; the root is inferred.
# For an additional type, add it to labor_types and extend full_nesting.
const full_nesting = Dict(
    :LM  => (children = [:low, :medium], elasticity = 1.5),
    :LMH => (children = [:LM, :high], elasticity = 1.5),
)

end # module LaborNestingSettings
