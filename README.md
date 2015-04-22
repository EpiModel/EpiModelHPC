EpiModel.hpc 
================
<a href='https://travis-ci.org/statnet/EpiModel.hpc' target="_blank"><img src='https://travis-ci.org/statnet/EpiModel.hpc.svg?branch=master' alt='Build Status' /></a>
<a href='https://coveralls.io/r/statnet/EpiModel.hpc?branch=master' target="_blank"><img src='https://coveralls.io/repos/statnet/EpiModel.hpc/badge.svg?branch=master' alt='Coverage Status' /></a>


### Purpose
EpiModel.hpc is an R software package that provides extensions for simulating stochastic network models in EpiModel on high-performance computing (HPC) systems. Functionality provided to simulate models in parallel, with checkpointing functions to save and restore simulation work.

While there are many potential HPCs systems, this software is developed with the standard within large-scale scientific computing: linux-based clusters that operate Torque/Moab job scheduling. However, this type of system is not a necessity for running EpiModel.hpc: the functionality of this package may be useful in any system that supports parallelization, including desktop computers with multiple cores.

### Installation
This software is currently hosted on Github only. It can be installed using the <a href="https://github.com/hadley/devtools" target="_blank">devtools package</a>:
```r
if (!require("devtools")) install.packages("devtools")
devtools::install_github("statnet/EpiModel.hpc", build_vignettes = TRUE)
```
