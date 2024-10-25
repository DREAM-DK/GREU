set t "Year." / %first_data_year% * %terminal_year% /;

singleton set t0[t] "Year before first main_endogenous year.";
singleton set t1[t] "First main_endogenous year.";
singleton set t2[t] "Second main_endogenous year.";
singleton set tEnd[t] "Final year modeled (terminal year).";
singleton set tBase[t] "Base year where prices are set to 1." / %base_year% /;

$MACRO set_time_periods(start, end) \
  t0[t]   = yes$(t.val=&start-1);\
  t1[t]   = yes$(t.val=&start);\
  t2[t]   = yes$(t.val=(&start+1));\
  tEnd[t] = yes$(t.val=&end);
