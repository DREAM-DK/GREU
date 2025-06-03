from global_container import Set, Alias

sector = Set(
  name="sector",
  description="Sectors of the economy as defined in national accounts.",
  records=[
    ("Corp", "Financial and non-financial corporations including subsectors."),
    ("Gov", "Geral government including subsectors."),
    ("Hh", "Households and non-profit institutions serving households."),
    ("RoW", "Rest of the world including subsectors.")
  ]
)

Corp = Set(name="Corp", domain=sector, description="Corporations", records=["Corp"])
Gov = Set(name="Gov", domain=sector, description="Government", records=["Gov"])
Hh = Set(name="Hh", domain=sector, description="Households", records=["Hh"])
RoW = Set(name="RoW", domain=sector, description="Rest of the world", records=["RoW"])

from_sector = Alias("from_sector", sector)
to_sector = Alias("to_sector", sector)