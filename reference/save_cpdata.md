# Saves for Network Simulation Rdata Files for Checkpointing

Module to save simulation data from stochastic network models to disk at
specified time intervals.

## Usage

``` r
save_cpdata(dat, at)
```

## Arguments

- dat:

  A master data object used in models simulated with `netsim`.

- at:

  Current time step

## Details

This module saves data to a standardized location with standardized file
names for the purposes of checkpointing. This is intended to be used
when running these simulations with
[`netsim_hpc`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md),
and will be automatically inserted into the workflow when this is done.
