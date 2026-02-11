# Initializes Network Model after Checkpointing

Sets the parameters, initial conditions, and control settings on the
data object, necessary for checkpointing simulations.

## Usage

``` r
initialize_cp(x, param, init, control, s)
```

## Arguments

- x:

  An `EpiModel` object of class `netest`.

- param:

  An `EpiModel` object of class `param.net`.

- init:

  An `EpiModel` object of class `init.net`.

- control:

  An `EpiModel` object of class `control.net`.

- s:

  Simulation number, used for restarting dependent simulations.

## Details

When running a stochastic network model from checkpointed data, it is
not necessary to run the originally specified initialization module.
Instead, the initialization module should reset the parameters, initial
conditions, and control settings back onto the data object.

This module is intended to be used in the context of running simulations
on high-performance computing settings using
[`netsim_hpc`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md).
That function automatically replaces the original initialization
function with this checkpointed version when the simulation is in a
checkpoint state.
