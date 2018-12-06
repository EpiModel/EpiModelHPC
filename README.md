EpiModelHPC
================
<a href='https://travis-ci.org/statnet/EpiModelHPC' target="_blank"><img src='https://travis-ci.org/statnet/EpiModelHPC.svg?branch=master' alt='Build Status' /></a>

EpiModelHPC is an R package that provides extensions for simulating stochastic network models in EpiModel on high-performance computing (HPC) systems. Functionality provided to simulate models in parallel, with checkpointing functions to save and restore simulation work.

While there are many potential HPCs systems, this software is developed with the standard within large-scale scientific computing: linux-based clusters that operate job scheduling software like OpenPBS, or a commercial variation of it like Moab or TORQUE. We have also just added support for HPCs running Slurm. These types of system are not necessary for running EpiModelHPC: the functionality of this package may be useful in any system that supports parallelization, including desktop computers with multiple cores.

### Installation
This software is currently hosted on Github only. Install it using the `remotes` package:
```r
if (!require("remotes")) install.packages("remotes")
remotes::install_github("statnet/EpiModelHPC")
```
