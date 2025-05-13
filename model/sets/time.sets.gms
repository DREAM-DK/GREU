set t "Year." / %first_data_year% * %terminal_year% /;
set t_dummies[t] "Selection of years for dummy-extension";
set t_endoyrs[t]

singleton set t0[t] "Year before first main_endogenous year.";
singleton set t1[t] "First main_endogenous year.";
singleton set t2[t] "Second main_endogenous year.";
singleton set tEnd[t] "Final year modeled (terminal year).";
singleton set tBase[t] "Base year where prices are set to 1." / %base_year% /;
singleton set tDataEnd[t] "Last data year" /%calibration_year%/; 

$MACRO set_time_periods(start, end) \
  t0[t]   = yes$(t.val=&start-1);\
  t1[t]   = yes$(t.val=&start);\
  t2[t]   = yes$(t.val=(&start+1));\
  tEnd[t] = yes$(t.val=&end);\
  t_dummies[t] = yes$(t.val>=&start and t.val<=&end);\
  t_endoyrs[t] = yes$(t.val>=&start and t.val<=&end);\

