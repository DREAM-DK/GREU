# Green REFORM EU
is an extensible system of Dynamic General Equilibrium models. The model system is build and maintained by [the Danish Research Institute for Economic Analysis and Modelling (DREAM)](https://dreamgruppen.dk/), but welcome contributions from the community and is free to under an [MIT license](LICENSE).
The model system is designed to be used by policymakers and researchers to analyze the sustainability of policies, both fiscally and environmentally.

## Modularity
A key aim of the GREU project it is to maintain perfect modularity. In this section, we describe some of the principles and techniques used to maintain modularity. Many of the principles for modularity are inspired by software engineering best practices, which have been successfully applied in two large economic model project at the DREAM group, MAKRO and Green REFORM, but the techniques are further refined in this project.

Often, modularity comes with a real cost of increasing the level of abstraction in the system, e.g. by introducing intermediate variables that would always be eliminated in a typical academic paper. However, such intermediation between different components of the model system, can make the model easier to maintain and extend, as one can ideally work on changing one part of the system, without deeply understanding the rest of the model.

### Partial equilibrium
To do this, each submodel should aim to be solvable as a partial equilibrium model, taking endogenous variables from other submodels as exogenous inputs. In the few cases where this is not possible, the submodel should at least be solvable together with the simplest possible version of another part of the model. For example, a labor market submodel may be dependent on a downward sloping demand curve for labor, but should be robust to how this curve is generated.

### Aggregate approximation
A useful technique for achieving modularity, is to start with simple aggregate relations, where a single variable sums up all the behavior of a more complicated micro-founded submodel.

For example, we may write an expression for the usercost of labor as

$$
p^L_t = w_t + LaborMarketFrictions_t
$$

where $w_t$ is the wage and $LaborMarketFrictions_t$ is initially exogenous and set to zero. We can then switch on a submodule for a complicated search and matching model of the labor market, and endogenize the $LaborMarketFrictions_t$ term.
As another example, it is also useful to write a single sector production function for aggregate output, e.g.

$$
GrossValueAdded_t = A_t K_t^{\alpha} L_t^{1-\alpha}
$$

despite having a large multi-industry model of production using nested CES trees. In this case, $K_t$ is a somewhat arbitrary aggregate of all capital stocks across industries, $L_t$ an aggregate of labor, and $A_t$ a residual term which captures productivity as well differences stemming from the "real" production function being neither Cobb-Douglas nor single sector.

This sort of aggregate approximation is surprisingly useful for analyzing the model in addition to enabling modularity. In a model with rich heterogeneity in production or households, there may be many shocks for which the heterogeneity is not important for the aggregate behavior. When effects of heterogeneity can be summarized in one or few variables, users can quickly see whether heterogeneity matters for a particular shock of interest, or when it can be safely ignored in terms of understanding the aggregate response.

### Prefer explicit variables over inserting expressions
In short model papers, we tend to insert derivatives used in optimizing behavior into the model equations, to see what the most compact form of a economic behavior relation looks like. In GREU, we prefer to use intermediate variables where meaningful rather than inserting expressions.
For example, we prefer to write a simple expression for the user cost of capital with adjustment costs as

$$
p^k_t = p^I_t - \beta (1-\delta) p^I_{t+1} + \frac{\partial AC_t}{\partial K_t} + \beta \frac{\partial AC_{t+1}}{\partial K_t}
$$

rather than inserting the derivatives into the equation.
In the code, we write the derivatives as explicit variables, e.g. *dKAdjCosts2dK[t]* and *dKAdjCosts2dKlag[t]* (see [variable naming conventions](#variable-names---in-code-and-in-documentation) in a section below).
This makes it much easier, both on paper and in the code, to change the functional form of the adjustment cost function, without having to meticulously track down all the places where the derivatives are used.

In terms of modularity, this allows us to keep the formulation of the function form of the adjustment cost function in a submodel, which can be easily switched with a different submodel. Of course, if we may want to make changes which cannot be captured in the existing framework, e.g. adding an additional time lead $\frac{\partial AC_{t+2}}{\partial K_t}$ in the example above. In this case, we modify the code in the submodule above, as necessary, while being mindful that the change is general enough to not be inconsistent with other submodels.


### Core modules and dependencies
The core modules are a set of submodels that together form a very simple general equilibrium model of the economy.
These models are heavily interdependent, and should capture most of the interaction between different parts of the economy.

We use the terms module and submodel interchangeably. More strictly, a submodel is a set of variable definitions and equations, whereas the module also refers to the surrounding code and documentation. For example code for calibrating parameters in the submodel and assigning data to variables. A cookbook for structuring a module is found in section [Module structure](#module-structure).

Peripheral submodels can thus depend on the core modules always being included, and we should aim to keep interaction between submodels contained in the core modules as far as possible. A set of peripheral modules may be heavily intertwined and depend on one another, but we should aim to only depend on the core modules as far as possible. For example, we should avoid using a specific tax policy variable from a peripheral tax module in a labor supply module. Instead, we could for example add a *marginal labor income tax rate* in a core module. This marginal tax rate can then be augmented in a tax module with complicated policies, and used to transfer the effects of the complicated tax rules to a labor market module, keeping the labor market module ignorant of the complexities of the tax rules.

As far as possible, the core modules are free from economic behavior in terms of decision making, and should be thought of as pure book-keeping models.
This has the added benefit, that the core modules can be used to verify internal consistency of a data set, catching mistakes in the data or the application of the data.

E.g. instead of starting with a model of CES demand for a number of consumption goods, we can write an equation which simply sets the demand for each good as a fixed budget share of aggregate consumption. This can be calibrated to any set of data, and we can check that budget shares sum to one etc. For the purpose of testing the data, the budget shares are calibrated, and otherwise thought of as exogenous. To add a CES demand system, we keep the budget share equations and simply endogenize the budget share variables in a new submodel.
As in previous example, such a simple model of budget shares is actually quite useful, for example allowing a user in a statistical agency to note that budget shares have changed more than is usual in preliminary data and raising a flag for further investigation.
A budget share model is also useful for shock analysis, where we can note that demand for a good has changed due to aggregate consumption changes or goods-specific effects that affect the budget share (or a combination).

### Fiscal sustainability modules

### Green transition modules

## Documentation
Each module should have a corresponding documentation file in the [docs subdirectory](docs).
To keep the documentation maintainable, documents need to be self-contained and avoid referring to specific implementation details of other modules, which might change over time.

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

## Data
To be written