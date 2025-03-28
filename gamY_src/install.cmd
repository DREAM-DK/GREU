:: Set path to GAMS
set GAMSDIR=C:/GAMS/49
set python=%GAMSDIR%/GMSPython/python.exe
set pip=%GAMSDIR%/GMSPython/Scripts/pip

:: Install pip (as python that ships with GAMS does not have pip)
curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
%python% get-pip.py

:: Install python modules
%pip% install ipykernel
%pip% install numpy scipy statsmodels
%pip% install gamsapi[all]==46.5.0 dream-tools==3.0.0 plotly 
%pip% install xlwings
%pip% install dataframe_image pyhtml2pdf PyPDF2
%pip% install kaleido==0.1.0.post1
%pip% install gamspy

:: Installing svglib (needed for xhtml2pdf) fails as the installer looks for .pyd files in the wrong directory
:: Workaround: create a symlink to the correct directory
mklink /J "%GAMSDIR%\GMSPython\DLLs\." "%GAMSDIR%\GMSPython"
%pip% install svglib

%pip% install xhtml2pdf

:: Set path to R
set R_HOME=C:/Program" "Files/R/R-4.4.0
cd model/R
:: Install R packages - run cmd as administrator to avoid permission issues
%R_HOME%/bin/Rscript.exe --no-save --no-restore --vanilla "install_packages.R"
