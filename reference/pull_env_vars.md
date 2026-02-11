# Pull Standard Environmental Variables in Slurm Jobs

Pulls four environmental variables commonly used in Slurm jobs directly
into the Global Environment of an R Script.

## Usage

``` r
pull_env_vars(standard.vars = TRUE, num.vars, char.vars, logic.vars)
```

## Arguments

- standard.vars:

  Pull and assign four standard Slurm variables: simno, jobno, ncores,
  njobs.

- num.vars:

  Vector of environmental variables to pull and assign as numeric in the
  global environment.

- char.vars:

  Vector of environmental variables to pull and assign as character in
  the global environment.

- logic.vars:

  Vector of environmental variables to pull and assign as logical in the
  global environment.

## Examples

``` r
Sys.setenv("SIMNO"=23)
Sys.setenv("SLURM_ARRAY_TASK_ID"=4)
Sys.setenv("SLURM_CPUS_PER_TASK"=4)
Sys.setenv("NJOBS"=10)
Sys.setenv("NSIMS"=100)

pull_env_vars(standard.vars = TRUE)
ls()
#> character(0)

Sys.setenv("tprob"=0.1)
Sys.setenv("rrate"=14)
Sys.setenv("scenario"="base")
Sys.setenv("condition"=TRUE)

pull_env_vars(num.vars = c("tprob", "rrate"),
              char.vars = "scenario",
              logic.vars = "condition")
ls()
#> character(0)
```
