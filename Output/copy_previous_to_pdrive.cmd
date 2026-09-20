@echo off
set "SRC=%~dp0previous_baseline.parquet"
set "DEST=P:\GREU\previous_baseline.parquet"
if not exist "%SRC%" (
  echo Local previous solution not found: %SRC%
  exit /b 1
)
if exist "%DEST%" (
  for /f %%I in ('powershell -NoProfile -Command "Get-Date -Date (Get-Item -LiteralPath \"%DEST%\").LastWriteTime -Format yyyy-MM-dd"') do set STAMP=%%I
  copy /Y "%DEST%" "P:\GREU\previous_baseline_%STAMP%.parquet"
)
copy /Y "%SRC%" "%DEST%"
