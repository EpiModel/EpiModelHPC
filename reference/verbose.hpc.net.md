# Custom Progress Print Module for HPC Workflow

This function prints progress from stochastic network models simulated
with `netsim` to the console or a txt file.

## Usage

``` r
verbose.hpc.net(x, type, s = 1, at = 2)
```

## Arguments

- x:

  If the `type` is "startup", then an object of class `control.net`,
  otherwise the all master data object in `netsim` simulations.

- type:

  Progress type, either of "startup" for starting messages before all
  simulations, or "progress" for time step specific messages.

- s:

  Current simulation number, if type is "progress".

- at:

  Current time step, if type is "progress".
