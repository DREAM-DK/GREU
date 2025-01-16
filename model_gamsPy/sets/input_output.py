import gamspy as gp
from global_container import Set, container

d = Set(name="d", description="Demand components.")

re = Set(name="re", domain=d, description="Intermediate energy-input", domain_forwarding=True)
rx = Set(name="rx", domain=d, description="Intermediate input types other than energy.", domain_forwarding=True)
k = Set(name="k", domain=d, description="Capital types.", domain_forwarding=True)
c = Set(name="c", domain=d, description="Private consumption types.", domain_forwarding=True)
g = Set(name="g", domain=d, description="Government consumption types.", domain_forwarding=True)
x = Set(name="x", domain=d, description="Export types.", domain_forwarding=True)
invt = Set(name="invt", domain=d, description="Inventories", domain_forwarding=True, records=["invt"])
tl = Set(name="tl", domain=d, description="Transmission losses", domain_forwarding=True, records=["tl"])

i = Set(name="i", description="Production industries.", domain_forwarding=True)
m = Set(name="m", domain=i, description="Industries with imports.")

data_gdx = gp.Container()
data_gdx.read("../data/data.gdx")

container.loadRecordsFromGdx(data_gdx, [
  "d",
  "re", "rx",
  "k", "c", "g", "x",
  "i", "m",
  "rx2re"
])

rx2re = container["rx2re"]
i2re = Set(name="i2re", domain=[i, re])
i2rx = Set(name="i2rx", domain=[i, rx])
i2rx[i,rx] = i.sameAs(rx)
i2re[i,re].where[gp.Sum(rx, rx2re[rx,re])] = True

# # set energy[d]/energy/;

# Set i_public[i] "Public industries." / off /;
# Set i_private[i] "Private industries.";
# i_private[i] = not i_public[i];

# Set i_refineries[i] / 19000 /;
# Set i_gasdistribution[i] / 35002 /;
# Set i_cardealers[i] / 45000 /;
# Set i_wholesale[i] / 46000 /;
# Set i_retail[i] / 47000 /;
# Set i_service_for_industries[i] / 71000 /;
# Set i_international_aviation[i] / 51009 /;

