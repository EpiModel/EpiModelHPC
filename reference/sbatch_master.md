# Create sbatch Bash Shell Script with Parameter Combination

Creates a master-level SLURM::sbatch script given a set of parameter
combinations implied by environmental arguments used as parameters.

## Usage

``` r
sbatch_master(
  vars,
  expand.vars = TRUE,
  working.dir = "",
  master.file = "",
  runsim.file = "runsim.sh",
  build.runsim = FALSE,
  env.file = "~/loadR.sh",
  rscript.file = "sim.R",
  param.file = NULL,
  param.tag = NULL,
  simno.start,
  nsims = 100,
  ncores = 16,
  narray = NULL,
  ckpt = FALSE,
  append = FALSE,
  mem = "55G",
  walltime = "1:00:00",
  jobname,
  partition.main = "csde",
  partition.ckpt = "ckpt",
  account.main = "csde",
  account.ckpt = "csde-ckpt"
)
```

## Arguments

- vars:

  A list of parameters with varying values (see examples below).

- expand.vars:

  If `TRUE`, expand the grid on the individual vars, else the individual
  vars must be vectors of equal length.

- working.dir:

  Path to write out the `master.file`, and if specified the
  `runsim.file` and `param.file`.

- master.file:

  Name of the output bash shell script file to write. If `""`, then will
  print to console.

- runsim.file:

  Name of the bash shell script file that contains the R batch commands
  to be executed by `sbatch`.

- build.runsim:

  If `TRUE`, will write out a bash shell script with the file name
  `runsim.file` that loads the R environment listed in `env.file` and
  execute `Rscript` on the file listed in `rscript.file`.

- env.file:

  Bash shell script to load the R environment desired. Optionally kept
  in a user's home directory with the default file name. Example script
  below.

- rscript.file:

  Name of the `.R` file that contains the primary simulation to be
  executed by `Rscript`.

- param.file:

  Name of a csv file to write out the list of varying parameters and
  simulation numbers set within the function.

- param.tag:

  Character string for current scenario batch added to param.sheet.

- simno.start:

  Starting number for the `SIMNO` variable. If missing and
  `append=TRUE`, will read the lines of `outfile` and start numbering at
  one after the previous maximum.

- nsims:

  Total number of simulations across all array jobs.

- ncores:

  Number of cores per node to use within each Slurm job.

- narray:

  Number of array batches within each Slurm job. If `NULL`, then will
  use `nsims/ncores` array batches.

- ckpt:

  If `TRUE`, use the checkpoint queue to submit jobs. If numeric, will
  specify the first X jobs on the grid as non-backfill.

- append:

  If `TRUE`, will append lines to a previously created shell script. New
  simno will either start with value of `simno.start` or the previous
  value if missing.

- mem:

  Amount of memory needed per node within each Slurm job.

- walltime:

  Amount of clock time needed per Slurm job.

- jobname:

  Job name assigned to Slurm job. If unspecified, defaults to the
  simulation number in each job.

- partition.main:

  Name of primary HPC partition (passed to -p).

- partition.ckpt:

  Name of checkpoint HPC partition (passed to -p).

- account.main:

  Name of primary account (passed to -A).

- account.ckpt:

  Name of checkpoint account (passed to -A).

## Examples

``` r
# Examples printing to console
vars <- list(A = 1:5, B = seq(0.5, 1.5, 0.5))
sbatch_master(vars)
#> #!/bin/bash
#> 
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1 --export=ALL,SIMNO=1,NJOBS=7,NSIMS=100,A=1,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s2 --export=ALL,SIMNO=2,NJOBS=7,NSIMS=100,A=2,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s3 --export=ALL,SIMNO=3,NJOBS=7,NSIMS=100,A=3,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s4 --export=ALL,SIMNO=4,NJOBS=7,NSIMS=100,A=4,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s5 --export=ALL,SIMNO=5,NJOBS=7,NSIMS=100,A=5,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s6 --export=ALL,SIMNO=6,NJOBS=7,NSIMS=100,A=1,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s7 --export=ALL,SIMNO=7,NJOBS=7,NSIMS=100,A=2,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s8 --export=ALL,SIMNO=8,NJOBS=7,NSIMS=100,A=3,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s9 --export=ALL,SIMNO=9,NJOBS=7,NSIMS=100,A=4,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s10 --export=ALL,SIMNO=10,NJOBS=7,NSIMS=100,A=5,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s11 --export=ALL,SIMNO=11,NJOBS=7,NSIMS=100,A=1,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s12 --export=ALL,SIMNO=12,NJOBS=7,NSIMS=100,A=2,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s13 --export=ALL,SIMNO=13,NJOBS=7,NSIMS=100,A=3,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s14 --export=ALL,SIMNO=14,NJOBS=7,NSIMS=100,A=4,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s15 --export=ALL,SIMNO=15,NJOBS=7,NSIMS=100,A=5,B=1.5 runsim.sh
sbatch_master(vars, nsims = 250)
#> #!/bin/bash
#> 
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1 --export=ALL,SIMNO=1,NJOBS=16,NSIMS=250,A=1,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s2 --export=ALL,SIMNO=2,NJOBS=16,NSIMS=250,A=2,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s3 --export=ALL,SIMNO=3,NJOBS=16,NSIMS=250,A=3,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s4 --export=ALL,SIMNO=4,NJOBS=16,NSIMS=250,A=4,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s5 --export=ALL,SIMNO=5,NJOBS=16,NSIMS=250,A=5,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s6 --export=ALL,SIMNO=6,NJOBS=16,NSIMS=250,A=1,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s7 --export=ALL,SIMNO=7,NJOBS=16,NSIMS=250,A=2,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s8 --export=ALL,SIMNO=8,NJOBS=16,NSIMS=250,A=3,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s9 --export=ALL,SIMNO=9,NJOBS=16,NSIMS=250,A=4,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s10 --export=ALL,SIMNO=10,NJOBS=16,NSIMS=250,A=5,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s11 --export=ALL,SIMNO=11,NJOBS=16,NSIMS=250,A=1,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s12 --export=ALL,SIMNO=12,NJOBS=16,NSIMS=250,A=2,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s13 --export=ALL,SIMNO=13,NJOBS=16,NSIMS=250,A=3,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s14 --export=ALL,SIMNO=14,NJOBS=16,NSIMS=250,A=4,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-16 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s15 --export=ALL,SIMNO=15,NJOBS=16,NSIMS=250,A=5,B=1.5 runsim.sh
sbatch_master(vars, ckpt = TRUE)
#> #!/bin/bash
#> 
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1 --export=ALL,SIMNO=1,NJOBS=7,NSIMS=100,A=1,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s2 --export=ALL,SIMNO=2,NJOBS=7,NSIMS=100,A=2,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s3 --export=ALL,SIMNO=3,NJOBS=7,NSIMS=100,A=3,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s4 --export=ALL,SIMNO=4,NJOBS=7,NSIMS=100,A=4,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s5 --export=ALL,SIMNO=5,NJOBS=7,NSIMS=100,A=5,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s6 --export=ALL,SIMNO=6,NJOBS=7,NSIMS=100,A=1,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s7 --export=ALL,SIMNO=7,NJOBS=7,NSIMS=100,A=2,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s8 --export=ALL,SIMNO=8,NJOBS=7,NSIMS=100,A=3,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s9 --export=ALL,SIMNO=9,NJOBS=7,NSIMS=100,A=4,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s10 --export=ALL,SIMNO=10,NJOBS=7,NSIMS=100,A=5,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s11 --export=ALL,SIMNO=11,NJOBS=7,NSIMS=100,A=1,B=1.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s12 --export=ALL,SIMNO=12,NJOBS=7,NSIMS=100,A=2,B=1.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s13 --export=ALL,SIMNO=13,NJOBS=7,NSIMS=100,A=3,B=1.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s14 --export=ALL,SIMNO=14,NJOBS=7,NSIMS=100,A=4,B=1.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s15 --export=ALL,SIMNO=15,NJOBS=7,NSIMS=100,A=5,B=1.5 runsim.sh
sbatch_master(vars, nsims = 50, ckpt = 10)
#> #!/bin/bash
#> 
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1 --export=ALL,SIMNO=1,NJOBS=4,NSIMS=50,A=1,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s2 --export=ALL,SIMNO=2,NJOBS=4,NSIMS=50,A=2,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s3 --export=ALL,SIMNO=3,NJOBS=4,NSIMS=50,A=3,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s4 --export=ALL,SIMNO=4,NJOBS=4,NSIMS=50,A=4,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s5 --export=ALL,SIMNO=5,NJOBS=4,NSIMS=50,A=5,B=0.5 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s6 --export=ALL,SIMNO=6,NJOBS=4,NSIMS=50,A=1,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s7 --export=ALL,SIMNO=7,NJOBS=4,NSIMS=50,A=2,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s8 --export=ALL,SIMNO=8,NJOBS=4,NSIMS=50,A=3,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s9 --export=ALL,SIMNO=9,NJOBS=4,NSIMS=50,A=4,B=1 runsim.sh
#> sbatch -p ckpt -A csde-ckpt --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s10 --export=ALL,SIMNO=10,NJOBS=4,NSIMS=50,A=5,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s11 --export=ALL,SIMNO=11,NJOBS=4,NSIMS=50,A=1,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s12 --export=ALL,SIMNO=12,NJOBS=4,NSIMS=50,A=2,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s13 --export=ALL,SIMNO=13,NJOBS=4,NSIMS=50,A=3,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s14 --export=ALL,SIMNO=14,NJOBS=4,NSIMS=50,A=4,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-4 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s15 --export=ALL,SIMNO=15,NJOBS=4,NSIMS=50,A=5,B=1.5 runsim.sh
sbatch_master(vars, simno.start = 1000)
#> #!/bin/bash
#> 
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1000 --export=ALL,SIMNO=1000,NJOBS=7,NSIMS=100,A=1,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1001 --export=ALL,SIMNO=1001,NJOBS=7,NSIMS=100,A=2,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1002 --export=ALL,SIMNO=1002,NJOBS=7,NSIMS=100,A=3,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1003 --export=ALL,SIMNO=1003,NJOBS=7,NSIMS=100,A=4,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1004 --export=ALL,SIMNO=1004,NJOBS=7,NSIMS=100,A=5,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1005 --export=ALL,SIMNO=1005,NJOBS=7,NSIMS=100,A=1,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1006 --export=ALL,SIMNO=1006,NJOBS=7,NSIMS=100,A=2,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1007 --export=ALL,SIMNO=1007,NJOBS=7,NSIMS=100,A=3,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1008 --export=ALL,SIMNO=1008,NJOBS=7,NSIMS=100,A=4,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1009 --export=ALL,SIMNO=1009,NJOBS=7,NSIMS=100,A=5,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1010 --export=ALL,SIMNO=1010,NJOBS=7,NSIMS=100,A=1,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1011 --export=ALL,SIMNO=1011,NJOBS=7,NSIMS=100,A=2,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1012 --export=ALL,SIMNO=1012,NJOBS=7,NSIMS=100,A=3,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1013 --export=ALL,SIMNO=1013,NJOBS=7,NSIMS=100,A=4,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=s1014 --export=ALL,SIMNO=1014,NJOBS=7,NSIMS=100,A=5,B=1.5 runsim.sh
sbatch_master(vars, jobname = "epiSim")
#> #!/bin/bash
#> 
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=1,NJOBS=7,NSIMS=100,A=1,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=2,NJOBS=7,NSIMS=100,A=2,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=3,NJOBS=7,NSIMS=100,A=3,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=4,NJOBS=7,NSIMS=100,A=4,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=5,NJOBS=7,NSIMS=100,A=5,B=0.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=6,NJOBS=7,NSIMS=100,A=1,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=7,NJOBS=7,NSIMS=100,A=2,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=8,NJOBS=7,NSIMS=100,A=3,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=9,NJOBS=7,NSIMS=100,A=4,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=10,NJOBS=7,NSIMS=100,A=5,B=1 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=11,NJOBS=7,NSIMS=100,A=1,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=12,NJOBS=7,NSIMS=100,A=2,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=13,NJOBS=7,NSIMS=100,A=3,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=14,NJOBS=7,NSIMS=100,A=4,B=1.5 runsim.sh
#> sbatch -p csde -A csde --array=1-7 --nodes=1 --cpus-per-task=16 --time=1:00:00 --mem=55G --job-name=epiSim --export=ALL,SIMNO=15,NJOBS=7,NSIMS=100,A=5,B=1.5 runsim.sh

if (FALSE) { # \dontrun{
# Full-scale example writing out files
sbatch_master(vars, nsims = 50, simno.start = 1000, build.runsim = TRUE,
              master.file = "master.sh", param.sheet = "params.csv")
sbatch_master(vars, nsims = 50, append = TRUE,
              master.file = "master.sh", param.sheet = "params.csv")

} # }
```
