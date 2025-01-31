import gamspy as gp
from global_container import Set

d = Set(name="d", description="Demand components.")

re = Set(name="re", domain=d, description="Intermediate energy-input", domain_forwarding=True)
rx = Set(name="rx", domain=d, description="Intermediate input types other than energy.", domain_forwarding=True)
k = Set(name="k", domain=d, description="Capital types.", domain_forwarding=True)
c = Set(name="c", domain=d, description="Private consumption types.", domain_forwarding=True)
g = Set(name="g", domain=d, description="Government consumption types.", domain_forwarding=True)
x = Set(name="x", domain=d, description="Export types.", domain_forwarding=True)
invt = Set(name="invt", domain=d, description="Inventories", domain_forwarding=True, records=["invt"])
tl = Set(name="tl", domain=d, description="Transmission losses", domain_forwarding=True, records=["tl"])

i = Set(name="i", domain=d, description="Production industries.", domain_forwarding=True)
m = Set(name="m", domain=i, description="Industries with imports.")
y = Set(name="y", domain=i, description="Industries with domestic production.")

rx2re = Set(name="rx2re", domain=[rx,re])

data_gdx = gp.Container()
data_gdx.read("../data/data.gdx")

for s in [
  re, rx, k, c, g, x, i
]:
  s.setRecords(data_gdx[s.name].records)

# Work around for bugs in gamspy
try:
  rx2re.setRecords(data_gdx["rx2re"].records)
except gp.exceptions.GamspyException:
  pass
d.setRecords(d.records)

i2re = Set(name="i2re", domain=[i, re])
i2rx = Set(name="i2rx", domain=[i, rx])
i2rx[i,rx] = i.sameAs(rx)
i2re[i,re].where[gp.Sum(rx, rx2re[rx,re])] = True

i_public = Set(name="i_public", domain=i, description="Public industries.")
i_private = Set(name="i_private", domain=i, description="Private industries.")
i_public["off"] = True
i_private[i].where[~i_public[i]] = True

# # set energy[d]/energy/;

# Set i_refineries[i] / 19000 /;
# Set i_gasdistribution[i] / 35002 /;
# Set i_cardealers[i] / 45000 /;
# Set i_wholesale[i] / 46000 /;
# Set i_retail[i] / 47000 /;
# Set i_service_for_industries[i] / 71000 /;
# Set i_international_aviation[i] / 51009 /;
