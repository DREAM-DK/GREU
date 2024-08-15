$IMPORT functions.gms;

OPTION
  SYSOUT=OFF
  SOLPRINT=OFF
  LIMROW=0
  LIMCOL=0
  DECIMALS=6
  PROFILE = 1
  PROFILETOL = 0.01

  CNS=CONOPT4  # Choose solver
;

$SETLOCAL first_data_year 1983;
$SETLOCAL terminal_year 2023;
$SETLOCAL base_year 2010;

$IMPORT sets.gms
set_time_periods(%first_data_year%, %terminal_year%);
