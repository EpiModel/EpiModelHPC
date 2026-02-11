# Create a Single Sim File per Scenarios Using the Files From `netsim_scenarios`

Create a Single Sim File per Scenarios Using the Files From
`netsim_scenarios`

## Usage

``` r
merge_netsim_scenarios_tibble(
  sim_dir,
  output_dir,
  steps_to_keep,
  cols = dplyr::everything()
)
```

## Arguments

- sim_dir:

  The folder where the simulation files are to be stored.

- output_dir:

  The folder where the merged files will be stored.

- steps_to_keep:

  Numbers of time steps add the end of the simulation to keep in the
  `data.frame`.

- cols:

  columns to keep in the `data.frame`. By default all columns are kept.
  And in any case, the `batch_number`, `sim` and `time` are always kept.
