# Save Simulation Data from Stochastic Network Models

Saves an Rdata file containing stochastic network model output from
`netsim` function calls with time-stamped file names.

## Usage

``` r
savesim(
  sim,
  data.dir = "data/",
  save.min = TRUE,
  save.max = TRUE,
  time.stamp = TRUE,
  compress = FALSE
)
```

## Arguments

- sim:

  An `EpiModel` object of class `netsim` to be saved to an Rdata file.

- data.dir:

  Path to save data files. Directory will be created if it does not
  already exist.

- save.min:

  If `TRUE`, saves a small version of the `netsim` object in which large
  elements of the data structure like the network object and the
  transmission data frame are removed. The resulting name for this small
  file will have ".min" appended at the end.

- save.max:

  If `TRUE`, saves the full `netsim` object without any deletions.

- time.stamp:

  If `TRUE`, saves the file with a time stamp in the file name.

- compress:

  Matches the `compress` argument for the
  [`save`](https://rdrr.io/r/base/save.html) function.

## Details

This function provides an automated method for saving a time-stamped
Rdata file containing the simulation number of a stochastic network
model run with `netsim`.
