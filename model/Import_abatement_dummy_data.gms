# 3.1 Data Loading
$GROUP abatement_data_variables_new
  sqTPotential_new[l,es,d,t] ""
  uTE_load_new[l,e]  "Auxiliary variable to load uTE"
  vTI_new[l,es,d,t] ""
  vTC_new[l,es,d,t] ""
  LifeSpan_new[l,es,d,t] ""
;

# Load new data variables from Abatement_dummy_data.gdx
execute_load "../data/Abatement_data/Abatement_dummy_data.gdx" sqTPotential_new.l=sqTPotential;
execute_load "../data/Abatement_data/Abatement_dummy_data.gdx" uTE_load_new.l=uTE_load;
execute_load "../data/Abatement_data/Abatement_dummy_data.gdx" vTI_new.l=vTI;
execute_load "../data/Abatement_data/Abatement_dummy_data.gdx" vTC_new.l=vTC;
execute_load "../data/Abatement_data/Abatement_dummy_data.gdx" LifeSpan_new.l=LifeSpan;

# Create dummies for new data variables
Parameter 
  d1sqTPotential_new[l,es,d,t]
;

d1sqTPotential_new[l,es,d,t] = yes$(sqTPotential_new.l[l,es,d,t]);

# 3.2 Initial Values
# Assign new values to existing variables
sqTPotential.l[l,es,d,t]$(d1sqTPotential_new[l,es,d,t]) = sqTPotential_new.l[l,es,d,t];
uTE.l[l,es,e,d,t]$(d1sqTPotential_new[l,es,d,t] and uTE_load_new.l[l,e]) = uTE_load_new.l[l,e];
vTI.l[l,es,d,t]$(d1sqTPotential_new[l,es,d,t]) = vTI_new.l[l,es,d,t];
vTC.l[l,es,d,t]$(d1sqTPotential_new[l,es,d,t]) = vTC_new.l[l,es,d,t];
LifeSpan[l,es,d,t]$(d1sqTPotential_new[l,es,d,t]) = LifeSpan_new.l[l,es,d,t];

# Set discount rate
DiscountRate[l,es,d]$(sum(t, sqTPotential.l[l,es,d,t])) = 0.05;

# Set smoothing parameters
eP.l[l,es,d,t]$(sqTPotential.l[l,es,d,t]) = 0.03;

# Set share parameter
uES.l[es,i,t]$(qES.l[es,i,t] and qREes.l[es,i,t]) = qES.l[es,i,t]/qREes.l[es,i,t];
jpTK.l[i,t]$(d1pTK[i,t] and d1K_k_i['iM',i,t]) = pTK.l[i,t]/pK_k_i.l['iM',i,t];

# 3.3 Dummy Variable Setup
# Set dummy determining the existence of technology potentials
d1sqTPotential[l,es,d,t] = yes$(sqTPotential.l[l,es,d,t]);
d1uTE[l,es,e,d,t] = yes$(uTE.l[l,es,e,d,t]);
d1pTK[d,t] = yes$(sum((l,es), d1sqTPotential[l,es,d,t]));
d1qES_e[es,e,d,t] = yes$(sum(l, d1uTE[l,es,e,d,t]));
d1qES[es,d,t] = yes$(qES.l[es,d,t]);

# 4.4 Starting values for Levelized Cost of Energy (LCOE)
uTKexp.l[l,es,d,t]$(t.val <= tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
   (vTI.l[l,es,d,t] # Investment costs
    + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt])) # Discounted variable costs
      / @Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Dicounted denominator
      ;

  # Levelized cost of energy (LCOE) in technology l per PJ output at full potential
  uTKexp.l[l,es,d,t]$(t.val > tend.val-LifeSpan[l,es,d,t]+1 and d1sqTPotential[l,es,d,t]) =
     (vTI.l[l,es,d,t] # Investment costs
      + @Discount2t(vTC.l[l,es,d,tt], DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discounted variable costs until tEnd
      + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({vTC.l[l,es,d,tEnd]}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted variable costs after tEnd (Assuming constant costs after tEnd)
      / (@Discount2t(1, DiscountRate[l,es,d], LifeSpan[l,es,d,t], d1sqTPotential[l,es,d,tt]) # Discount denominator until tEnd
       + (1/(1+DiscountRate[l,es,d]))**(1+tEnd.val-t.val)*@FiniteGeometricSeries({1}, {DiscountRate[l,es,d]}, {LifeSpan[l,es,d,t]-1+t.val-tEnd.val})) # Discounted denominator after tEnd
       ; 

pTPotential.l[l,es,d,t] = 
  sum(e, uTE.l[l,es,e,d,t]*pEpj_marg.l[es,e,d,t]) + uTKexp.l[l,es,d,t]*pTK.l[d,t];
