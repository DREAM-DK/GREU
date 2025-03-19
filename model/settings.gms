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

$SETLOCAL first_data_year 2015;
$SETLOCAL calibration_year 2020;
$SETLOCAL terminal_year 2030;

$SETLOCAL base_year 2020;

parameter gp "Steady state rate of inflation." /0.02/;
parameter gq "Steady state labor saving technical progress." /0.01/;

# ======================================================================================================================
# Solver options
# ======================================================================================================================
$ONECHO > conopt4.opt
  # See https://www.gams.com/latest/docs/S_CONOPT4.html
  # for available solver options

  #  Keep searching for a solution even if a bound is hit (due to non linearities)
  lmmxsf = 1

  # Limit on number of error messages related to infeasible pre-triangle
  # 25 is default but often not enough. 
  Lim_Pre_Msg = 400
$OFFECHO