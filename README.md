# Green REFORM Finland

This is the Finnish branch of the Green REFORM EU model, originally created by the Danish DREAM Insitute. For the upstream repository, check out https://github.com/DREAM-DK/GREU.

This is a joint model repository by Natural Resources Institute Finland (Luonnonvarakeskus - LUKE), Finnish Environment Institute (Suomen Ympäristökeskus - SYKE), VTT Technical Research Centre of Finland Ltd and Finnish Ministry of Finance (Valtionvarainministeriö). The technical administration is (currently) done by Natural Resources Institure Finland (LUKE) in collaboration with other organizations. 

The codes are open source and free for download and use by others. For more information, see LICENSE. If you want to become a collaborator, please contact the administration (currently: lauri.saaskilahti@luke.fi).

The upstream repository's (DREAM-DK/GREU) README-file:

## Model source code
The source code defining all the model equations can be found in the [model subdirectory](gamY_src/).
The run.py shows the order in which the files are usually run.

### Variable names - in code and in documentation
For naming variables, we try to strike a balance between short-hand notation that makes dense equations easier to read, and longer names that are explicit and self-explaning (as is usually good practice in code).
For short hand notation, we defer to standard economic litterature notation, e.g. Y is output, C is consumption, and so forth.
In addition, to the roots of names, we use the following system of prefixes and suffixes:

Prefix naming system:
- j - additive residual term
- f - factor, unspecified multiplicative parameter or variable.
- jf - multiplicative residual term (or equivalently, the combination of two prefixes, j and f = a residual added to a muliplicative factor)
- E - Expectations operator, rarely used, as leaded variables are used implicitly as model consistent expectations
- d - derivative, e.g. dY2dX = ∂Y/∂X
- s - structural version of variable
- m - marginal - used when marginal and average rates differ, e.g. mt = marginal tax rate
- u - scale parameters (μ in documentation)
- t - tax rate
- r - unspecified rate or ratio
- e - exponent, typically an elasticity
- p - price, adjusted by steady state rate of inflation
- q - quantity, adjusted by steady state rate of productivity growth
- v - value (= p*q), adjusted by product of steady state rate of inflation and productivity growth
- nv - present value (adjusted by product of steady state rate of inflation and productivity growth)
- n - number of persons
- h - hours

Suffixes and aggregation:
To allow for varying levels of aggregation, depending on the number of submodules included, we start with the shortest names for them most aggregate variables and add suffixes denoting disaggregate versions of the same variable. E.g. pC[t] is the price index of aggregate pricate consumption in year $t$. In the documentation, this appears as $p^C_{t}$ The price index of a specific type of consumption, $c$, is written as pC_c[c,t] in the GAMS source code. In the documentation, this appears as $p^C_{c,t}$, as we ommit the suffix. qC_c[c,t] is the equivalent real quantity of consumption in the source code. In the documentation we ommit the $q$ prefix and simply write $C_{c,t}$.

Multi-word identifiers are written in CamelCase.

## GAMS and gamY
MAKRO is written in GAMS but uses a pre-processor, *gamY*, that implements additional features convenient for working with large models.

An installation of [GAMS](https://www.gams.com/) is needed to run MAKRO (GAMS 46 or higher) as well as a license for both GAMS and the included Conopt4 solver. Note that students and academics may have access to a license through their university.
The [paths.py](gamY_src/paths.py) file should be adjusted with the path to your local GAMS installation. We generally assume that users use Windows, but both GAMS and MAKRO should be compatible with unix operating systems.

## Python packages
The packages needed to run GREU can be installed in python using pip and the command
```
pip install gams dream-tools numpy pandas scipy statsmodels
```

We recommend using the python installation that comes with your GAMS installation.
For reporting, and other purposes, we make use of several python packages in addition to the ones listed above.
To install pip and all the packages that we use, simply run the code in [install.py](gamY_src/install.py).
