# Green REFORM Finland

This is the Finnish branch of the Green REFORM EU model, originally created by the Danish DREAM Insitute. For the upstream repository, check out https://github.com/DREAM-DK/GREU.

This is a joint model repository by Natural Resources Institute Finland (Luonnonvarakeskus), Finnish Environment Institute (Suomen Ympäristökeskus), VTT Technical Research Centre of Finland Ltd and Finnish Ministry of Finance (Valtionvarainministeriö). The technical administration is (currently) done by Natural Resources Institure Finland (Luonnonvarakeskus) in collaboration with other organizations. 

The codes are open source and free for download and use by others. For more information, see LICENSE. If you want to become a collaborator, please contact the administration (currently: lauri.saaskilahti@luke.fi).

The upstream repository's (DREAM-DK/GREU) README-file:

## Model source code
The source code defining all the model equations can be found in the [model subdirectory](model).
The run.py shows the order in which the files are usually run.

## Module structure
The entire code base can be thought of as a matrix structure, with phases as rows and submodels as columns.
The phases are:
* Set definitions
* Variable definitions
* Equation definitions
* Data imports and exogenous parameters
* Calibration
* Tests

In each phase, each module does its own thing. E.g. in the variable definitions phase, each modules defines variables specific to that module. Variables used across modules should generally be defined in a *core module*.

A template for structuring a module is included in the core modules [module_template.gms](model/modules/module_template.gms). To write a new module, start by copying the template and renaming the module. 

### Set definitions
<TODO: Add details about set definitions>


### Variable definitions
We define the term *group* as a collection of variables, which may be indexed over different indices (sets), along with a logical condition for each variable, which controls which combination of index elements the variable is actually defined for[^1].

[^1]: In gamY, a group is created with the $GROUP command. Future implementations may do things differently, but should retain the core concept of a bundle of variables with logical conditions controlling indices. This concept is a key innovation from the *MAKRO* model, utilizing the fact that logical conditions can be evaluated in different contexts, making inclusion of variable element combinations dynamically controlled. 

We first define a global group called *all_variables*. We also define a number of other  groups (subsets of *all_variables*) that are shared across modules, for example groups specifying how an exogenous variable should be treated in the forecast[^2].

[^2]: A better implementation would replace these "groups" with specific "tags" on each variable, which can then be used to dynamically control inclusion of variables in different contexts. Tags are more convenient, as combinatorics can create an explosion in the number of groups needed to fully characterize all possible combinations of tags.

Each module defines its own variables and add these to the *all_variables* group along with optional logical conditions controlling which index element combinations the variables are defined for. Modules can also add variable to other global groups, for example a group of variables that should be kept constant after a calibration year (if exogenous).

### Growth and inflation adjustment
Having defined all variables, we use the names of variables to further define a number of groups according to the naming conventions described below.

For example, groups of all variables that are *prices* and need to be adjusted for inflation to make the model stationary, *quantities* that need to be adjusted for productivity growth, and *values* that need to be adjusted for both inflation and productivity growth.

<TODO: Add details about growth and inflation adjustment>

### Equation definitions
We start by defining an empty collection of equations called *main* and an empty group of variables called *main_endogenous*.

Each module then defines its own model which is subsequently added to the *main* model.
For each equation added, the module must also add a corresponding endogenous variable to the *main_endogenous* group.

In practice, this is done easily with gamY command "$BLOCK", which takes three "arguments" in the header: a name of the model, a name of the group of associated endogenous variables, and a logical condition applied to all the equations and endogenous variables.
Inside the $BLOCK-$ENDBLOCK pair, we define equations.
Example:

    $BLOCK template_equations template_endogenous $(t1.val <= t.val and t.val <= tEnd.val)
    .. module_template_test_variable[t] =E= 1;
    $ENDBLOCK

An equations defined with no variable specified before the ".." uses the first variable on the left hand side of the equation as the endogenous variable.
We can also manually specify a specific endogenous variable for the equation. For example, we may want to define an equilibrium condition which has a price as the endogenous variable, despite the price not actually appearing in the equation:

    p[t].. D[t] =E= S[t];

In the previous section, we noted that variables are defined with an optional condition defining which elements they exist for. The same logical conditions is automatically applied to any equation which is defined with that variable as the endogenous variable.

After defining a submodel in the module with a matching group of endogenous variables, we add the model to the *main* model and add the group of endogenous variables to the *main_endogenous* group:

    model main / template_equations /;
    $Group+ main_endogenous template_endogenous;


### Data and exogenous parameters
<TODO: Add details about data and exogenous parameters>

### Calibration
<TODO: Add details about calibration>

### Tests
<TODO: Add details about tests>


### GAMS and gamY
MAKRO is written in GAMS but uses a pre-processor, *gamY*, that implements additional features convenient for working with large models.

An installation of [GAMS](https://www.gams.com/) is needed to run MAKRO (GAMS 46 or higher) as well as a license for both GAMS and the included Conopt4 solver. Note that students and academics may have access to a license through their university.
The [paths.py](gamY_src/paths.py) file should be adjusted with the path to your local GAMS installation. GREU is compatible with both Windows and Unix operating systems (always use forward slashes for paths, to maintain Unix compatibility).

### Python packages
The packages needed to run GREU can be installed in python using pip and the command
```
pip install gams dream-tools numpy pandas scipy statsmodels
```

We recommend using the python installation that comes with your GAMS installation.
For reporting, and other purposes, we make use of several python packages in addition to the ones listed above.
To install pip and all the packages that we use, simply run the code in [install.py](install.py).


## Variable names - in code and in documentation
For naming variables, we try to strike a balance between short-hand notation that makes dense equations easier to read, and longer names that are explicit and self-explanatory (as is usually good practice in code). Note that Greek letters written with Latin characters are neither short nor self-explanatory!

For short-hand notation, we defer to standard economic literature notation, e.g. Y is output, C is consumption, and so forth.
Variables which are naturally described as fractions are written using the numeral 2 as divider between the numerator and denominator, e.g. qX2qGDP = $X/GDP$.
In addition, to the roots of names, we use a system of prefixes and suffixes described in the subsections below.

In the GAMS implementation, all variables are contained in a global namespace, which does not allow for using the same name for different variables in different modules. Using longer, self-explanatory names, helps avoid name collisions.
While inconvenient for writing a single module, unique names improve the overall user experience.

### Prefix naming system:
- j - additive residual term
- f - factor, unspecified multiplicative parameter or variable.
- jf - multiplicative residual term (or equivalently, the combination of two prefixes, j and f = a residual added to a muliplicative factor)
- E - Expectations operator, rarely used, as leaded variables are used implicitly as model consistent expectations
- d - derivative, e.g. dY2dX = ∂Y/∂X
- s - structural version of variable
- m - marginal - used when marginal and average rates differ, e.g. mt = marginal tax rate. Usually it is better to use an explicit derivative.
- u - calibrated scale parameters (μ in documentation)
- t - tax rate
- r - unspecified rate or ratio
- e - exponent, typically an elasticity
- p - price, any variable adjusted by steady state rate of inflation (see [growth and inflation adjustment](#growth-and-inflation-adjustment))
- q - quantity, any variable adjusted by steady state rate of productivity growth
- v - value (= p*q), any variable adjusted by the product of steady state factors of inflation and productivity growth
- nv - present value (also adjusted by product of steady state rate of inflation and productivity growth)
- n - number of persons
- h - hours

### Suffixes and aggregation
To allow for varying levels of aggregation, depending on the number of submodules included, we start with the shortest names for them most aggregate variables and add suffixes denoting dis-aggregate versions of the same variable. E.g. pC[t] is the price index of aggregate private consumption in year $t$. In the documentation, this appears as $p^C_{t}$ The price index of a specific type of consumption, $c$, is written as pC_c[c,t] in the source code. In the documentation, this appears as $p^C_{c,t}$, as we ommit the suffix. qC_c[c,t] is the equivalent real quantity of consumption in the source code. In the documentation we ommit the $q$ prefix and simply write $C_{c,t}$.

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


## Data handling

All data ONLY IN CSV FILES!!! No exceptions!!! This means no .xls, .xlsx or others rubbish
