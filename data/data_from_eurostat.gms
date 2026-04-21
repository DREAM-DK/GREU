### Overview
#
# This file processes Eurostat data (produced by load_eurostat_data.py) into derived parameters for the model.
#
# Structure:
#   1) Declare and load sets and raw parameters from data.gdx
#   2) Compute derived parameters
#   3) Export to GDX
#
# To add a new module:
#   - Add the Python data module in data/modules/{name}_data.py
#   - Register it in load_eurostat_data.py
#   - Add set declarations, raw parameter declarations, and $load statements in section 1
###

# =============================================================================
# 1) Declare and load sets and raw parameters from data.gdx
# =============================================================================

# --- Time ---
Set t;
Set t1(t);

# --- Input-output ---
Set d;
Set i(d); alias(i, i_a);
Set d_non_ene(d);
Set d_ene(d);
Set energy(d);
Set a_rows_;
Set k(d);
Set c(d);
Set x(d);
Set g(d);
Set rx(i);
Set re(i);
Set invt(d);
Set invt_ene(d);
Set m(i);

# --- Financial accounts ---
Set sector;
Set i_public(i);
Set i_private(i);
Set i_private_fin(i);
Set i_private_nonfin(i);

# --- Factors of production ---
Set factors_of_production;

Parameters # Parameters read from data_eurostat.gdx
  # --- Input-output ---
  vIO_y[i,d,t] "Production IO, domestic supply"
  vIO_m[i,d,t] "Production IO, imports"
  vIO_a[a_rows_,d,t] "Production IO, decomposition of GVA"
  # --- Labor market ---
  nEmployed[t] "Total labor supply data"
  hSalEmployed[t] "Total hours worked by salaried employees"
  hSelfEmployed[t] "Total hours worked by self-employed employees"
  # --- Factor demand ---
  qK_k_i[k,i,t] "Capital stock by capital type and industry."
  qI_k_i[k,i,t] "Capital investments by capital type and industry."
  # qInvt_i[i,t] "Inventory investments by industry." # Take a closer look at this...
  # --- Financial accounts ---
  vNetFinAssets[sector,t] "Net financial assets by sector."
  vNetDebtInstruments[sector,t] "Net debt instruments by sector."
  vNetEquity[sector,t] "Net equity instruments by sector."
  # --- Government ---
  vtIndirect[t] "Revenue from indirect taxes."
  vtDirect[t] "Total direct taxes"
  vtCorp[t] "Taxation of corporations"
  vCont[t] "Contributions to social security"
  vGovRevQuasi[t] "Revenue from quasi-corporations"
  vGovRent[t] "Revenue from rent"
  vtGovDepr[t] "Depreciation of public capital"
  vGovReceiveCorp[t] "Capital transfers from corporations"
  vGovReceiveCorpNonCap[t] "Other transfers from corporations"
  vGovReceiveF[t] "Transfers from foreign countries"
  vtCap[t] "Capital taxes"
  vGov2Corp[t] "Transfers to corporations"
  vGovSub[t] "Government subsidies to corporations"
  vHhTransfers[t] "Transfers to households and non-profits from government."
  vGov2Foreign[t] "Transfers from government to foreign countries"
  vGovNetAcquisitions[t] "Net acquisitions of non-produced non-financial assets"
;

$gdxin data_eurostat.gdx
#  --- Time ---
$load t, t1
#  --- Input-output sets ---
$load d, d_non_ene, d_ene, energy
$load i, m
$load k, c, x, g, rx, re, invt, invt_ene
$load a_rows_
#  --- Input-output parameters ---
$load vIO_y, vIO_m, vIO_a
#  --- Labor market --- 
$load nEmployed, hSalEmployed, hSelfEmployed
#  --- Factor demand ---
$load factors_of_production
$load qK_k_i, qI_k_i  #, qInvt_i
#  --- Financial accounts ---
$load sector, i_public, i_private, i_private_fin, i_private_nonfin
$load vNetFinAssets, vNetDebtInstruments, vNetEquity
#  --- Government ---
$load vtIndirect, vtDirect, vtCorp, vCont, vGovRevQuasi, vGovRent, vtGovDepr
$load vGovReceiveCorp, vGovReceiveCorpNonCap, vGovReceiveF, vtCap
$load vGov2Corp, vGovSub, vHhTransfers, vGov2Foreign, vGovNetAcquisitions
$gdxin

# =============================================================================
# 2) Derived parameters
# =============================================================================

$PGROUP PG_data # Initialize intermediate parameters for computations below
  # --- Input-output ---
  vY_i_d[i,d,t] "Output by industry and demand component."
  vY_i_d_base[i,d,t] "Output by industry and demand component in base prices."
  vM_i_d[i,d,t] "Imports by industry and demand component."
  vM_i_d_base[i,d,t] "Imports by industry and demand component in base prices."
  vtY_i_d[i,d,t] "Net duties on domestic production by industry and demand component."
  vtM_i_d[i,d,t] "Net duties on imports by industry and demand component."
  vtY_i_Sub[i,t] "Production subsidies by industry."
  vtY_i_Tax[i,t] "Production taxes by industry."
  vtY_i_NetTaxSub[i,t] "Net production taxes and subsidies by industry."
  vD_base[d,t] "Demand components in base-prices"
  vtYM_d[d,t] "Net product taxes by demand component"
  vD[d,t] "Demand components in purchasing prices."
  qD[d,t] "Real demand by demand component."
  qInvt_i[i,t] "Inventory investments by industry."
  qInvt_ene_i[i,t] "Inventory investments by industry."
  qE_re_i[energy,i,t] "Energy demand from industry i, split on energy-types re"
  # --- Labor market ---
  vWages_i[i,t] "Compensation of employees by industry."
  nL[t] "Total employment."
  vW[t] "Compensation pr. employee."
  # --- Production ---
  qL_i[i,t] "Labor in efficiency units by industry."
  qProd[factors_of_production,i,t] "Factors of production, value"
  pProd[factors_of_production,i,t] "Factors of production, price"
;

# -----------------------------------------------------------------------------
# Compute parameters
# -----------------------------------------------------------------------------
# --- Input-output ---
vY_i_d_base[i,d,t] = vIO_y[i,d,t]; # Base prices from raw IO
vM_i_d_base[i,d,t] = vIO_m[i,d,t]; # Base prices from raw IO

vY_i_d_base[re,'energy',t] = sum(i,vIO_y[re,i,t]);
vM_i_d_base[re,'energy',t] = sum(i,vIO_m[re,i,t]);

vD_base[d,t] = sum(i, vY_i_d_base[i,d,t] + vM_i_d_base[i,d,t]); # Total demand in base prices

vtYM_d[d,t] = vIO_a["vNetProductTax",d,t]; # Net product taxes (Eurostat D21X31 = "Taxes less subsidies on products")

vtY_i_d[i,d,t]$(vD_base[d,t]) = vY_i_d_base[i,d,t] / vD_base[d,t] * vtYM_d[d,t]; # Distribute product taxes across IO cells proportional to base values
vtM_i_d[i,d,t]$(vD_base[d,t]) = vM_i_d_base[i,d,t] / vD_base[d,t] * vtYM_d[d,t]; # Distribute product taxes across IO cells proportional to base values

# Production taxes and subsidies. NOTE: Only net taxes are available in the eurostat dataset.
# Both variables are kept such that the user can populate both if data is available.
vtY_i_Tax[i,t] = vIO_a['vNetOtherProductionTax',i,t]; # Other production taxes and subsidies (Eurostat D29X39 - only net available)
vtY_i_Sub[i,t] = 0; # Only net taxes are available, so we set subsidies to zero. 
vtY_i_NetTaxSub[i,t] = vtY_i_Tax[i,t] - vtY_i_Sub[i,t];

vY_i_d[i,d,t] = vY_i_d_base[i,d,t] + vtY_i_d[i,d,t]; # IO including taxes
vM_i_d[i,d,t] = vM_i_d_base[i,d,t] + vtM_i_d[i,d,t]; # IO including taxes

vD[d,t] = sum(i, vY_i_d[i,d,t] + vM_i_d[i,d,t]); # Compute demand components in purchasing prices
qD[d,t] = vD[d,t]; # Normalize prices to 1 and load quantities into model

qInvt_i[i,t] = vY_i_d[i,'invt',t] + vM_i_d[i,'invt',t];  
qInvt_ene_i[i,t] = vY_i_d[i,'invt_ene',t] + vM_i_d[i,'invt_ene',t];

# --- Labor market ---
vWages_i[i,t] = vIO_a['CompEmpl',i,t];
nL[t] = nEmployed[t];
vW[t]$(nL[t]) = sum(i, vWages_i[i,t]) / nL[t];

# --- Production ---
qK_k_i[k,i,t] = qK_k_i[k,i,'2022']; # To avoid problems in capital accumulation equation.

qL_i[i,t] = vWages_i[i,t]*(1 + hSelfEmployed[t]/hSalEmployed[t]);

qProd['RxE',i,t]       = sum(rx,vY_i_d[rx,i,t] + vM_i_d[rx,i,t]); 
qProd['labor',i,t]     = qL_i[i,t];
qProd['iM',i,t]        = qK_k_i['iM',i,t]; 
qProd['iB',i,t]        = qK_k_i['iB',i,t];
qProd['energy',i,t]    = sum(re,vY_i_d[re,i,t] + vM_i_d[re,i,t]);
pProd[factors_of_production,i,t] = 1;

qE_re_i[energy,i,t] = qProd['energy',i,t];

# =============================================================================
# 3) Export to GDX
# =============================================================================
execute_unload 'data'
