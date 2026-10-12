# Preset of Configuration for the RSPH Cluster

Preset of Configuration for the RSPH Cluster

## Usage

``` r
swf_configs_rsph(
  partition = "epimodel",
  r_version = "4.6.1",
  mail_user = NULL,
  cleanup_workers = TRUE
)
```

## Arguments

- partition:

  The RSPH partition, or partitions, to submit to: a single name, a
  character vector, or a comma-separated string such as
  `"epimodel,CIDMATH"`. With several partitions, SLURM starts each job
  on whichever can run it first. The default, `"epimodel"`, is the lab's
  dedicated partition. See the "Partitions" section for the valid names.

- r_version:

  Which version of R to load with spack. Use the full version (`"4.6.1"`
  or `"4.5.1"`) matching the R version in the project lockfile. A
  partial version such as `"4.3"` can match several spack builds, which
  makes `spack load` fail, so it gives a warning.

- mail_user:

  The mail address to send the messages to, default is NULL (see 'sbatch
  –mail-type' argument)

- cleanup_workers:

  If `TRUE` (the default), append
  [`swf_cleanup_r_workers`](http://epimodel.github.io/EpiModelHPC/reference/swf_cleanup_r_workers.md)
  to `r_loader` so each step reaps its own R workers on cancel or
  timeout. RSPH has no cgroup containment, so without this, workers
  survive `scancel` and squat on cores SLURM has re-allocated, starving
  later tasks. See
  [`swf_cleanup_r_workers`](http://epimodel.github.io/EpiModelHPC/reference/swf_cleanup_r_workers.md).

## Value

a list with four elements:

- `default_sbatch_opts`: sbatch options to pass to
  [`slurmworkflow::create_workflow()`](https://epimodel.github.io/slurmworkflow/reference/create_workflow.html).
  They set the partition list, `mail-type = "FAIL"` and, when
  `mail_user` is given, `mail-user`.

- `renv_sbatch_opts`: sbatch options for the
  [`step_tmpl_renv_restore()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_renv_restore.md)
  step: 16 GB of memory, 4 CPUs and 180 minutes, as in the
  EpiModelHIV-Template. The first restore under a new R version builds
  every package from source and takes longer than later ones.

- `r_loader`: bash lines that make R available on a compute node. Pass
  them to the `setup_lines` argument of the `step_tmpl_` functions.

- `max_cores`: the largest `cpus-per-task` a single task can request on
  every listed partition. It is 32, except 16 when `interactive-cpu` is
  listed and 31 when `largemem` is listed.

## Partitions

The RSPH partitions as of October 2026. All nodes have 32 cores.

|  |  |  |  |
|----|----|----|----|
| Partition | Time limit | Max cores per task | Notes |
| `epimodel` | none | 32 | The lab's dedicated nodes; the default |
| `CIDMATH` | none | 32 | Dedicated nodes shared with three other groups |
| `short-cpu` | 8 hours | 32 | The cluster's default partition |
| `day-long-cpu` | 1 day | 32 |  |
| `week-long-cpu` | 7 days | 32 | At most 6 nodes per job |
| `month-long-cpu` | 31 days | 32 | At most 4 nodes per job |
| `interactive-cpu` | 12 hours | 16 | Meant for `srun` sessions |
| `largemem` | 7 days | 31 | High-memory nodes |

The `preemptable` partition no longer exists, and asking for it is an
error.

`default_sbatch_opts` sets no `time`, so a step without its own `time`
runs up to the limit of the partition it lands on. A step whose `time`
exceeds a partition's limit can only start on the other partitions in
the list.

RSPH gives each CPU 5 GB of memory by default (`DefMemPerCPU = 5120`)
and does not enforce memory requests. A step that uses more than it
asked for is not killed, but it can starve other jobs on the node, so
request what each step needs with `mem-per-cpu`. Keep `mem = "0"` (a
whole node) for network estimation.

SLURM's `MaxArraySize` is 1001 on RSPH, so one array holds at most 1001
tasks (indices 0 to 1000). We use `max_array_size = 1000` in array
steps.

## Node setup

`r_loader` sources the shared spack environment, unloads everything, and
loads R. It deliberately does not load git: git is on the default path
on RSPH, and the project template has not loaded it for some time. The
`git_version` argument was removed accordingly.

## Examples

``` r
hpc_configs <- swf_configs_rsph(mail_user = "user@emory.edu")
hpc_configs$default_sbatch_opts
#> $partition
#> [1] "epimodel"
#> 
#> $`mail-type`
#> [1] "FAIL"
#> 
#> $`mail-user`
#> [1] "user@emory.edu"
#> 

# Start each step on whichever partition can run it first
swf_configs_rsph(c("epimodel", "CIDMATH", "short-cpu"))$default_sbatch_opts
#> $partition
#> [1] "epimodel,CIDMATH,short-cpu"
#> 
#> $`mail-type`
#> [1] "FAIL"
#> 

# A project whose lockfile records R 4.5
swf_configs_rsph(r_version = "4.5.1", cleanup_workers = FALSE)$r_loader
#> [1] ". /projects/epimodel/spack/share/spack/setup-env.sh"
#> [2] "spack unload -a"                                    
#> [3] "spack load r@4.5.1"                                 
```
