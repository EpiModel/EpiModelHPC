# Save Simulation Data from Stochastic Network Models

Saves an Rdata file containing stochastic network model output from
`netsim` function calls with time-stamped file names.

## Usage

``` r
merge_simfiles(
  simno,
  ftype = "min",
  indir = "data/",
  vars = NULL,
  truncate.at = NULL,
  keep.other = FALSE,
  verbose = TRUE
)
```

## Arguments

- simno:

  First components of the simulation number in the standard format
  written by
  [`savesim`](http://epimodel.github.io/EpiModelHPC/reference/savesim.md)
  (see details).

- ftype:

  Type of file to be merged, with either `"min"` for compacted files or
  `"max"` for large files. File availability depends on what files were
  saved in
  [`savesim`](http://epimodel.github.io/EpiModelHPC/reference/savesim.md).

- indir:

  File directory relative to working directory where simulation files
  are stored.

- vars:

  Character vector of variables stored in `epi` sub-list to retain in
  output data. If any variables are specified, then network statistics
  and other ancillary data are removed.

- truncate.at:

  Left-truncates a simulation epidemiological summary statistics and
  network statistics at a specified time step.

- keep.other:

  If `TRUE`, keep the other simulation elements (as set by the
  `save.other` parameter in `control.netsim`) from the original `x` and
  `y` elements.

- verbose:

  If `TRUE`, print file load progress to console.

## Details

This function merges individual simulation runs stored in separate Rdata
files into one larger output object for analysis. This function would
typically be used after running
[`netsim_hpc`](http://epimodel.github.io/EpiModelHPC/reference/netsim_hpc.md)
with an array job specification (see the vignette) in order to combine
individual blocks of simulations into one complete set.

The `simno` argument must therefore be specified as the first component
of the simulation number: what would be passed to the `-v` parameter in
`qsub`. For example, if one would like to aggregate the two files for
simulation number 1 stored in the `sim.n1.1.*` and `sim.n1.2.*` files,
the `simno` argument would be `1`.
