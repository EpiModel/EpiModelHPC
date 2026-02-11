# Process sub-job simulation files saved as a series of Rdata files.

Wraps the `merge_simfiles` function to merge all sub-job Rdata files and
saves into a single output file, with the option to delete the sub-job
files.

## Usage

``` r
process_simfiles(
  simno = NA,
  indir = "data/",
  outdir = "data/",
  vars = NULL,
  truncate.at = NULL,
  min.n,
  nsims,
  compress = "xz",
  delete.sub = TRUE,
  verbose = FALSE
)
```

## Arguments

- simno:

  Simulation number to process.

- indir:

  File directory relative to working directory where simulation files
  are stored.

- outdir:

  File directory relative to working directory where simulation files
  should be saved.

- vars:

  Argument passed to
  [`merge_simfiles`](http://epimodel.github.io/EpiModelHPC/reference/merge_simfiles.md).

- truncate.at:

  Left-truncates a simulation epidemiological summary statistics and
  network statistics at a specified time step.

- min.n:

  Integer value for the minimum number of simulation files to be
  eligible for processing.

- nsims:

  Total number of simulations across all sub-jobs.

- compress:

  Argument passed to [`save`](https://rdrr.io/r/base/save.html).

- delete.sub:

  Delete sub-job files after merge and saving.

- verbose:

  Logical, print progress to console.
