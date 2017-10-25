EpiModelHPC
================
<a href='https://travis-ci.org/statnet/EpiModelHPC' target="_blank"><img src='https://travis-ci.org/statnet/EpiModelHPC.svg?branch=master' alt='Build Status' /></a>

EpiModelHPC is an R package that provides extensions for simulating stochastic network models in EpiModel on high-performance computing (HPC) systems. Functionality provided to simulate models in parallel, with checkpointing functions to save and restore simulation work.

While there are many potential HPCs systems, this software is developed with the standard within large-scale scientific computing: linux-based clusters that operate job scheduling software like OpenPBS, or a commercial variation of it like Moab or TORQUE. This type of system, however, is not a necessity for running EpiModelHPC: the functionality of this package may be useful in any system that supports parallelization, including desktop computers with multiple cores.

### Installation
This software is currently hosted on Github only. It can be installed using the <a href="https://github.com/hadley/devtools" target="_blank">devtools package</a>:
```r
if (!require("devtools")) install.packages("devtools")
devtools::install_github("statnet/EpiModelHPC", build_vignettes = TRUE)
```
