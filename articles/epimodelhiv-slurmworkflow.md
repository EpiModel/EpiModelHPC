# Using \`slurmworkflow\` with EpiModel

## Introduction

[`slurmworkflow`](https://epimodel.github.io/slurmworkflow/) builds
*workflows* for a [SLURM](https://slurm.schedmd.com/overview.html)
equipped high-performance computing (HPC) cluster. A workflow is a
sequence of *steps*, each one a SLURM job, that run one after the other
on the HPC. We build the workflow on our own computer, copy it to the
HPC, and start it there with a single command.

This vignette explains the ideas behind the workflows we use in applied
EpiModelHIV projects. It follows the
[EpiModelHIV-Template](https://github.com/EpiModel/EpiModelHIV-Template)
(branch `v3.3.x`) and uses the Rollins School of Public Health (RSPH)
HPC at [Emory University](https://www.sph.emory.edu/) as the example
cluster. It is not a step-by-step guide. For that, follow the README in
each chapter of the Template and the wiki page [Running Project
Workflows on the
HPC](https://github.com/EpiModel/EpiModeling/wiki/Running-Project-Workflows-on-the-HPC).

The Template uses [renv](https://rstudio.github.io/renv/) and needs
access to the private
[EpiModelHIV-p](https://github.com/EpiModel/EpiModelHIV-p) repository.
We assume that the project is a git repository cloned both on your
computer and on the HPC.

## Structure of an applied EpiModelHIV project

All the R code lives under `R/`:

- `R/00-setup.R`: one-time setup of the project library with renv.
- `R/shared_variables.R`: paths, time steps and other values shared by
  every script. The paths to generated files point inside `data/run/`:
  for example `est_dir` is `data/run/estimates/` and `scenarios_dir` is
  `data/run/scenarios/`.
- `R/hpc_configs.R`: the HPC settings and the `make_em_workflow()`
  function used by every workflow.
- `R/netsim_settings.R`: builds the `param` and `init` objects and the
  `path_to_est` and `path_to_restart` paths used by the simulations.
- One folder per chapter: `R/A-networks`, `R/B-model_dev`,
  `R/C-calibration` and `R/D-interventions`. Each chapter has a README,
  numbered scripts (`1-estimation.R`, `2-diagnostics.R`, …) to run
  locally in order, `workflow-*.R` scripts that build HPC workflows, and
  a `z-context.R` file that switches between local and HPC settings.

The `data/` folder contains:

- `data/input/`: files the project needs before any code runs, such as
  model parameters and scenario definitions. Tracked by git.
- `data/run/`: everything the code produces: network estimates,
  calibration and scenario runs. Not tracked by git.
- `data/output/`: final tables and figures. Not tracked by git.

The project has two renv lockfiles. `renv.lock` records the full local
environment, analysis packages included. `renv.lock.hpc` records only
what the model needs on the HPC: EpiModelHIV, EpiModelHPC, ARTnetData
and their dependencies. Workflows are built in `workflows/`, which is
not tracked by git either.

Two per-user values go in the project `.Renviron` file (open it with
`usethis::edit_r_environ("project")`): `EPIMODELHIV_DIR`, the path to
your local clone of EpiModelHIV-p, and `HPC_MAIL_USER`, the address
SLURM mails about your jobs.

## Local and HPC contexts

Every numbered script and every workflow sources `R/shared_variables.R`
and the `z-context.R` file of its chapter. `z-context.R` looks for a
variable named `hpc_context`. When it is `TRUE`, it sets
`context <- "hpc"` and the full-scale settings; otherwise it sets
`context <- "local"` and small, fast ones. In
`R/A-networks/z-context.R`, for example, the local context estimates
10,000-node networks with the Stochastic-Approximation method on one
core, and the HPC context estimates 100,000-node networks with MCMLE on
10 cores.

The context also goes into the file names, so local and HPC results
never overwrite each other: the network estimates are saved as
`data/run/estimates/netest-local.rds` or
`data/run/estimates/netest-hpc.rds`.

On the HPC, workflow steps run the same numbered scripts with
`hpc_context = TRUE`. The goal is that a script that runs locally also
runs on the HPC without modification, so test every script locally
first.

**Note**: run each numbered script in a fresh R session (Ctrl+Shift+F10
in RStudio) to avoid starting from a polluted environment, which makes
debugging very hard. Do not use `rm(list = ls())` instead: [it does not
do the same thing](https://rstats.wtf/source-and-blank-slates). It also
breaks the scripts run by
[`step_tmpl_do_call_script()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_do_call_script.html),
because it deletes the variables the step defines before running the
script.

## Workflows and steps

A workflow is a folder, `workflows/<name>/`, holding a
`start_workflow.sh` script and one subfolder per step. Each
`workflow-*.R` script builds one workflow in two moves:

1.  `make_em_workflow()` creates the workflow and its first step, which
    brings the project on the HPC up to date (see below).
2.  Each call to
    [`slurmworkflow::add_workflow_step()`](https://epimodel.github.io/slurmworkflow/reference/add_workflow_step.html)
    appends a step. Its `step_tmpl` argument is a *step template*, which
    says what the step runs, and its `sbatch_opts` argument says which
    resources the step asks SLURM for.

`sbatch_opts` accepts any long-form
[`sbatch`](https://slurm.schedmd.com/sbatch.html) option without the
leading `--` (“cpus-per-task” is valid, “c” is not). The options given
to the workflow when it is created are the defaults for every step, and
each step can override them.

The steps are chained by a small controller job, so step 2 starts when
step 1 is over, and so on. A step can also change which step runs next;
this is how `swfcalib` loops over calibration iterations.

The templates used in the Template come from two packages:

- `slurmworkflow`:
  [`step_tmpl_do_call_script()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_do_call_script.html)
  runs an R script that is on the HPC,
  [`step_tmpl_do_call()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_do_call.html)
  runs an R function, and
  [`step_tmpl_map()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_map.html)
  runs a function over many inputs as a SLURM array.
- `EpiModelHPC`:
  [`step_tmpl_renv_restore()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_renv_restore.md)
  updates the project,
  [`step_tmpl_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_scenarios.md)
  runs scenario simulations,
  [`step_tmpl_merge_netsim_scenarios_tibble()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_merge_netsim_scenarios_tibble.md)
  merges their output, and
  [`step_tmpl_netsim_swfcalib_output()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_swfcalib_output.md)
  runs the model with calibrated parameters.

## `make_em_workflow()`: the common first step

Every workflow in the Template starts with `make_em_workflow()`, defined
in `R/hpc_configs.R`. Here is a slightly shortened version:

``` r

current_git_branch <- "main"          # <- USER: your git branch

hpc_node_setup <- c(
  ". /projects/epimodel/spack/share/spack/setup-env.sh",
  "spack unload -a",
  "spack load r@4.5.1"
)

make_em_workflow <- function(wf_name, override = FALSE, update_renv = TRUE) {
  # The Template stops with instructions if this is not set in `.Renviron`
  hpc_mail_user <- Sys.getenv("HPC_MAIL_USER")

  if (update_renv) {
    renv::snapshot(
      packages = c("EpiModelHIV", "EpiModelHPC", "ARTnetData"),
      lockfile = "renv.lock.hpc",
      prompt = FALSE
    )
  }

  wf_path <- paste0("workflows/", wf_name)
  if (override && fs::dir_exists(wf_path)) fs::dir_delete(wf_path)

  wf <- slurmworkflow::create_workflow(
    wf_name = wf_name,
    default_sbatch_opts = list(
      "partition" =
        "epimodel,short-cpu,day-long-cpu,week-long-cpu,month-long-cpu",
      "mail-type" = "FAIL",
      "mail-user" = hpc_mail_user
    )
  )

  # Update renv on the HPC
  wf <- slurmworkflow::add_workflow_step(
    wf_summary = wf,
    step_tmpl = EpiModelHPC::step_tmpl_renv_restore(
      git_branch = current_git_branch,
      setup_lines = hpc_node_setup,
      lockfile = if (update_renv) "renv.lock.hpc" else NULL
    ),
    sbatch_opts = list(
      "mem" = "16G",
      "cpus-per-task" = 4,
      "time" = 180
    )
  )

  wf
}
```

It does four things.

**It refreshes `renv.lock.hpc`** from the packages installed in your
local project library. Install the EpiModelHIV-p version you want to run
locally first, then build the workflow, then commit and push
`renv.lock.hpc`.

**It creates the workflow** in `workflows/<wf_name>/`.
[`create_workflow()`](https://epimodel.github.io/slurmworkflow/reference/create_workflow.html)
stops if that folder already exists; `override = TRUE` deletes the old
one first.

**It sets the default sbatch options**: mail `HPC_MAIL_USER` when a step
fails, and run on any of the listed partitions. SLURM starts each job on
whichever listed partition can run it first, and it considers the lab’s
dedicated `epimodel` partition (15 nodes, no time limit) before the
shared ones: `short-cpu` (8 hours), `day-long-cpu` (1 day),
`week-long-cpu` (7 days) and `month-long-cpu` (31 days). A step that
asks for more time than a partition allows only runs on the others. Lab
members can also add `CIDMATH`, 8 dedicated nodes shared with three
other groups. The `preemptable` partition that older projects used no
longer exists. `interactive-cpu` (12 hours, at most 16 cores per job) is
meant for `srun` sessions and `largemem` holds high-memory nodes;
neither is needed for routine runs.

**It adds the restore step**, which is always step 1. On a compute node,
this step loads R with `hpc_node_setup`, checks that the HPC clone is on
`current_git_branch` (and stops otherwise, to avoid running the wrong
code), runs `git pull`, and restores the packages listed in
`renv.lock.hpc`. This is how EpiModelHIV-p and the other packages get
installed on the HPC: there is no need to run `renv::init()` or
`renv::restore()` by hand. Do not run them on the login node either. The
login node runs a different release of the operating system than the
compute nodes, so renv keeps a separate library for it that the jobs
never use.

`hpc_node_setup` holds the bash lines that make R available in each
step. On RSPH, R comes from [spack](https://spack.io/): `r@4.6.1` is the
current build and `r@4.5.1` is still available. Load the version
recorded in your lockfile, and always give the full version:
`spack load r@4.3`, for example, fails because it matches several
builds.

### Outside the Template: `swf_configs_rsph()`

Projects that do not use `make_em_workflow()` can get the same settings
from
[`swf_configs_rsph()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md):

``` r

library(slurmworkflow)
library(EpiModelHPC)

hpc_configs <- swf_configs_rsph(
  partition = c("epimodel", "short-cpu", "day-long-cpu"),
  r_version = "4.6.1",
  mail_user = "<netid>@emory.edu"
)

wf <- create_workflow(
  wf_name = "my_workflow",
  default_sbatch_opts = hpc_configs$default_sbatch_opts
)

wf <- add_workflow_step(
  wf_summary = wf,
  step_tmpl = step_tmpl_renv_restore(
    git_branch = "main",
    setup_lines = hpc_configs$r_loader
  ),
  sbatch_opts = hpc_configs$renv_sbatch_opts
)
```

`hpc_configs` holds:

- `default_sbatch_opts`: the partition list and the mail settings.
- `renv_sbatch_opts`: the resources for the restore step.
- `r_loader`: the spack lines, followed by a trap that stops a job’s own
  R workers when the job is canceled or times out (see
  [`?swf_cleanup_r_workers`](http://epimodel.github.io/EpiModelHPC/reference/swf_cleanup_r_workers.md)).
  Pass it as `setup_lines` to every step template.
- `max_cores`: the most CPUs one task can request on every listed
  partition.

See
[`?swf_configs_rsph`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_rsph.md)
for the partitions it accepts and their limits.
[`swf_configs_hyak()`](http://epimodel.github.io/EpiModelHPC/reference/swf_configs_hyak.md)
does the same for the HYAK cluster at the University of Washington.

## Example: estimating the networks

`R/A-networks/workflow-networks.R` runs the network estimation and
diagnostics at full scale. Estimating 100,000-node networks with MCMLE
would take days on a laptop.

``` r

library(slurmworkflow)

hpc_context <- TRUE
source("R/shared_variables.R", local = TRUE)
source("R/A-networks/z-context.R", local = TRUE)
source("R/hpc_configs.R", local = TRUE)

wf <- make_em_workflow("networks", override = TRUE)

wf <- add_workflow_step(
  wf_summary = wf,
  step_tmpl = step_tmpl_do_call_script(
    r_script = "R/A-networks/1-estimation.R",
    args = list(hpc_context = TRUE),
    setup_lines = hpc_node_setup
  ),
  sbatch_opts = list(
    "cpus-per-task" = est_cores,
    "time" = "24:00:00",
    "mem" = "0"
  )
)

wf <- add_workflow_step(
  wf_summary = wf,
  step_tmpl = step_tmpl_do_call_script(
    r_script = "R/A-networks/2-diagnostics.R",
    args = list(hpc_context = TRUE),
    setup_lines = hpc_node_setup
  ),
  sbatch_opts = list(
    "mail-type" = "END",
    "cpus-per-task" = est_cores,
    "time" = "24:00:00",
    "mem" = "0"
  )
)
```

Setting `hpc_context <- TRUE` before sourcing `z-context.R` gives us the
HPC settings in this script too, including `est_cores` (10).

[`step_tmpl_do_call_script()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_do_call_script.html)
runs a script that is already **on the HPC**, in the git clone of the
project, after defining the variables listed in `args`. The syntax is
similar to [`base::do.call()`](https://rdrr.io/r/base/do.call.html).
Here the scripts start with `hpc_context = TRUE`, so they pick the HPC
settings when they source `z-context.R`.

The `sbatch_opts` of these two steps ask for `est_cores` CPUs, 24 hours,
and `mem = "0"`, which means all the memory of the node. That reserves a
whole node, which network estimation needs; do not use it for simulation
steps. With 24 hours, these steps cannot run on `short-cpu`. The last
step asks for a mail when it ends, so we know when the workflow is done.

The steps write `netest-hpc.rds`, `netstats-hpc.rds` and
`epistats-hpc.rds` to `data/run/estimates/` on the HPC, and the
diagnostics to `data/run/diagnostics/`. Once they are downloaded to the
same folders locally, `R/A-networks/3-assess.R` reads them (see the
chapter README).

## Example: running intervention scenarios

`R/D-interventions/workflow-intervention.R` runs every scenario in
`data/input/scenarios.csv` many times, starting from the restart point
made in the calibration chapter (`data/run/estimates/restart-hpc.rds`),
then merges and processes the results.

### Simulation step

Terminology:

- simulation: one run of an epidemic model.
- scenario: a set of parameter values for a simulation. See
  [`vignette("model-parameters", package = "EpiModel")`](https://epimodel.github.io/EpiModel/articles/model-parameters.html).
- batch: a set of up to `n_cores` simulations of the same scenario, run
  in parallel by one SLURM task.

``` r

library(slurmworkflow)
library(EpiModelHPC)
library(EpiModelHIV)

hpc_context <- TRUE
source("R/shared_variables.R", local = TRUE)
source("R/D-interventions/z-context.R", local = TRUE)
source("R/hpc_configs.R", local = TRUE)

max_cores <- 8

source("R/netsim_settings.R", local = TRUE) # `param`, `init`, `path_to_restart`

control <- control_msm(
  start          = restart_time,
  nsteps         = intervention_end,
  initialize.FUN = reinit_msm,
  verbose        = FALSE
)

wf <- make_em_workflow("interventions", override = TRUE)

scenarios_df <- read.csv("data/input/scenarios.csv")
scenarios_list <- EpiModel::create_scenario_list(scenarios_df)

wf <- add_workflow_step(
  wf_summary = wf,
  step_tmpl = step_tmpl_netsim_scenarios(
    path_to_restart, param, init, control,
    scenarios_list = scenarios_list,
    output_dir = scenarios_dir,
    n_rep = 32,
    n_cores = max_cores,
    max_array_size = 1000,
    setup_lines = hpc_node_setup
  ),
  sbatch_opts = list(
    "mail-type" = "FAIL,TIME_LIMIT",
    "cpus-per-task" = max_cores,
    "time" = "04:00:00",
    "mem-per-cpu" = "5G"
  )
)
```

These simulations restart from a previous simulation rather than from
time 0, so `control` sets `start = restart_time` and
`initialize.FUN = reinit_msm`, a function from EpiModelHIV-p that
handles the restart.

[`step_tmpl_netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_scenarios.md)
takes the same arguments as
[`netsim_scenarios()`](http://epimodel.github.io/EpiModelHPC/reference/netsim_scenarios.md),
which runs the same thing locally:

- `path_to_restart`, `param`, `init` and `control`: the inputs to
  [`netsim()`](https://epimodel.github.io/EpiModel/reference/netsim.html).
  The first one is the path to the restart point **on the HPC**, which
  [`netsim()`](https://epimodel.github.io/EpiModel/reference/netsim.html)
  uses as its `x` argument. The `nsims` and `ncores` values in `control`
  are replaced by the step.
- `scenarios_list`: the scenarios made by
  [`EpiModel::create_scenario_list()`](https://epimodel.github.io/EpiModel/reference/create_scenario_list.html).
- `output_dir`: where to save the simulations, here
  `data/run/scenarios/`.
- `n_rep`: how many times to run each scenario. 32 is enough to test the
  workflow; final analyses use many more.
- `n_cores`: how many simulations each task runs in parallel, on as many
  CPUs.
- `max_array_size`: the most tasks submitted at once (see below).
- `setup_lines`: the bash lines that load R.

Each scenario is run in `ceiling(n_rep / n_cores)` batches, and each
batch is one task of a SLURM array. With `n_rep = 32` and `n_cores = 8`,
each scenario takes 4 batches, so 10 scenarios make an array of 40
tasks. When `n_rep` is not a multiple of `n_cores`, the last batch of
each scenario runs the remainder. Each batch is saved as
`sim__<scenario id>__<batch number>.rds` in `output_dir`. Files from an
earlier run are not deleted, so empty `data/run/scenarios/` on the HPC
before running new scenarios.

RSPH sets SLURM’s `MaxArraySize` to 1001, so one array holds at most
1001 tasks (indices 0 to 1000), and we use `max_array_size = 1000`. When
a step has more tasks than `max_array_size`, slurmworkflow splits it
into parts of at most that size and submits each part when the previous
one is over. With 3,000 tasks, `max_array_size = 1000` makes 3 parts.
Older projects use 500, which works but can double the number of parts.

Each task asks for 8 CPUs for 4 hours, with 5 GB of memory per CPU. RSPH
does not enforce memory requests, so ask for what the simulations really
use: a task that uses more than it asked for is not stopped and slows
down the other jobs on its node. Tasks of 8 cores fit on partly busy
nodes and usually start sooner than whole-node tasks. The task mails us
if it fails or runs out of time.

`control_msm()` keeps the final state of the model in each saved
simulation (`save.run = TRUE`). On a 100,000-node model this state is
most of the file. When the simulations are only read through merged
tibbles, as here, `save.run = FALSE` makes the files much smaller. Keep
the default when a restart point will be picked from the files, as in
the calibration chapter.

### Merging and processing steps

``` r

wf <- add_workflow_step(
  wf_summary = wf,
  step_tmpl = step_tmpl_merge_netsim_scenarios_tibble(
    sim_dir = scenarios_dir,
    output_dir = fs::path(scenarios_dir, "merged_tibbles"),
    steps_to_keep = intervention_end - intervention_start,
    cols = dplyr::everything(),
    n_cores = max_cores,
    setup_lines = hpc_node_setup
  ),
  sbatch_opts = list(
    "cpus-per-task" = max_cores,
    "time" = "02:00:00",
    "mem-per-cpu" = "5G"
  )
)

wf <- add_workflow_step(
  wf_summary = wf,
  step_tmpl = step_tmpl_do_call_script(
    r_script = "R/D-interventions/3-process_tables.R",
    args = list(hpc_context = TRUE),
    setup_lines = hpc_node_setup
  ),
  sbatch_opts = list(
    "cpus-per-task" = max_cores,
    "time" = "04:00:00",
    "mem-per-cpu" = "5G"
  )
)
```

[`step_tmpl_merge_netsim_scenarios_tibble()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_merge_netsim_scenarios_tibble.md)
turns all the batches of a scenario into a single tibble, saved as
`df__<scenario id>.rds` in `output_dir`. It keeps only the last
`steps_to_keep` time steps and the columns selected by `cols`
(`batch_number`, `sim` and `time` are always kept). These files are much
smaller than the raw simulations and are what we download.

The processing scripts then run on the HPC with
[`step_tmpl_do_call_script()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_do_call_script.html),
as in the networks workflow. The Template adds a last step for the
plots, with `"mail-type" = "END"` so that we get a mail when the
workflow is done.

## Running a workflow on the HPC

The wiki page [Running Project Workflows on the
HPC](https://github.com/EpiModel/EpiModeling/wiki/Running-Project-Workflows-on-the-HPC)
gives the commands. These are the ideas behind them.

**Two channels.** The code and `renv.lock.hpc` reach the HPC through
git: commit and push them, and the restore step pulls them. The workflow
folder is not tracked by git, so copy it with `scp -r` into the
`workflows/` folder of the project on the HPC (for example
`/projects/epimodel/<netid>/<project>/workflows/`). Files in `data/run/`
that a run reads but that were made locally, such as a restart point,
must be copied with `scp` as well. A file that is neither pushed nor
copied does not exist on the HPC.

**Start from the project folder.** On the HPC, go to the root of the
project (where `renv.lock.hpc` is) and run
`./workflows/<name>/start_workflow.sh`. The script must be executed, not
sourced. Every step runs in the folder the workflow was started from,
which is why the relative paths such as `data/run/` work.
`start_workflow.sh -s <n>` starts the workflow at step `n`, and
`start_workflow.sh -h` lists the other options.

**Follow the jobs.** SLURM mails `HPC_MAIL_USER` when a step fails and
when the last step ends. `squeue -u $USER` lists your pending and
running jobs; the steps of a workflow are named
`<workflow name>_step<n>`. The output of each step, and of each array
task, goes to a file in `workflows/<name>/log/` on the HPC. `sacct` and
`seff` do not work on RSPH because SLURM accounting is turned off. To
stop a workflow, cancel its jobs by name
(`scancel -u $USER --name=<workflow name>_step<n>`) rather than all of
your jobs at once.

**Download the results.** The outputs are in the `data/run/` folder of
the project on the HPC. Copy what you need with `scp` to the same path
in your local project, preferably merged tibbles and summaries rather
than raw simulation files.

## Calibration with `swfcalib`

Automated calibration uses the same building blocks.
`R/C-calibration/workflow-swfcalib.R` in the Template chains
[`swfcalib::calibration_step1()`](https://epimodel.github.io/swfcalib/reference/calibration_step1.html),
`calibration_step2()` and `calibration_step3()` with
[`step_tmpl_do_call()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_do_call.html)
and
[`step_tmpl_map()`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_map.html),
and then runs the calibrated model with
[`step_tmpl_netsim_swfcalib_output()`](http://epimodel.github.io/EpiModelHPC/reference/step_tmpl_netsim_swfcalib_output.md).
See the [swfcalib
vignette](https://epimodel.github.io/swfcalib/articles/swfcalib.html)
and `R/C-calibration/README.md` in the Template.

## Other helpers

[`add_doctor_register_step()`](http://epimodel.github.io/EpiModelHPC/reference/doctor_watch_steps.md)
and
[`add_doctor_teardown_step()`](http://epimodel.github.io/EpiModelHPC/reference/doctor_watch_steps.md)
connect a workflow to the deploy doctor, a separate SLURM job that
watches for stalled tasks and requeues them. See their help pages and
[`hpc_doctor_script()`](http://epimodel.github.io/EpiModelHPC/reference/hpc_doctor_script.md).
