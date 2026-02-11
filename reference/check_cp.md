# Checks for Checkpointed Rdata Files

Checks whether there are checkpointed data files in a specific format
given a simulation number.

## Usage

``` r
check_cp(simno)
```

## Arguments

- simno:

  Simulation number for current model simulation, typically stored in
  `control$simno`.

## Details

This function checks whether checkpointed data files are available for
loading. Checkpointed data files are incrementally saved during the
simulation and loaded when a simulation job has been cancelled and
restarted. This is done automatically within the
[`netsim_hpc`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md)
function.

Checkpointed data files are searched for in a specific subdirectory
relative to the current working directory: `data/sim<x>`, where `<x>` is
the `simno` value. Within that directory `check_cp` looks for files
ending `.cp.rda`, which is the standard checkpoint data file name. Note
that these standards for file directory and name are consistent with the
[`save_cpdata`](http://epimodel.github.io/EpiModelHPC/reference/save_cpdata.md)
module function. If running simulations using the
[`netsim_hpc`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md)
function, this data saving module will automatically be inserted in the
workflow of a simulation.

The files are tested to see that they are of similar size, meaning that
no file is less than 50% of the average file size of the others. Smaller
size files usually indicates that the interim file saving was
interrupted. If the files exist and are of correct size, a full
directory name is returned, else `NULL` is returned.
