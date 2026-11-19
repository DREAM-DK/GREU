# Map the partial energy technology model to the CGE model.
# Use these mappings to link CGE prices and energy demand to the partial model.
module EnergyTechnologySettings

# CGE industry of each user in the partial model. 10030 is dairies, inside C10-12.
const linked_industry = Dict(:i10030 => :iC10_12)

# CGE product of each energy input. Inputs not listed, such as waste and captured CO2, keep their data price.
const linked_product = Dict(
  :coal_and_coke => :B,
  :diesel_for_transport => :C19,
  :gasoline_for_transport => :C19,
  :electricity => :D,
  :district_heat => :D,
  :natural_gas_incl_biongas => :D,
)

# CGE capital type whose user cost drives the cost of machinery in energy technologies.
const linked_capital = :equipment

# Share of each linked industry's energy price that follows the energy service price.
# The rest follows the CGE product prices. Placeholder until real data give the cost share.
const energy_service_share = Dict(:iC10_12 => 0.1)

end # module