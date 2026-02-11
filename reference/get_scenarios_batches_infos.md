# Helper function to access the file name elements of scenarios

This function returns the list of simulation files and the corresponding
scenario name and batch number present in a given directory. It is meant
to be used after `netsim_scenarios` or `step_tmpl_netsim_scenarios`.

## Usage

``` r
get_scenarios_batches_infos(scenario_dir)
```

## Arguments

- scenario_dir:

  the directory where `netsim_scenarios` saved it's simulations.

## Value

a `tibble` with three columns: `file_path` - the full paths of the
simulation file, `scenario_name` the associated scenario name,
`batch_number` the associated batch number.
