#Test that distribution profits are zero in dat-year
  Loop(e, 
  ABORT$(abs(vDistributionProfits.l[e,tDataEnd])> 1e-6)  "Should hold in data-year"; 
  );

#Test that calibration has gone well
  # ABORT$(abs(sum((i,t),  jqREmachine.l[i,t]))> 1e-6)  "Calibration of qREmachine failed";
  # ABORT$(abs(sum((es,i,t), jqREes.l[es,i,t]))> 1e-6)  "Calibration of qREes failed";
