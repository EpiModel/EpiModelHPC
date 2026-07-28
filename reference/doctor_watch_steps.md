# Deploy-Doctor Watch-List Workflow Steps

`add_doctor_register_step` and `add_doctor_teardown_step` add the two
halves of the deploy-doctor watch list to a `slurmworkflow` workflow.
Together they stop the shared deploy doctor
([`hpc_doctor_script`](http://epimodel.github.io/EpiModelHPC/reference/hpc_doctor_script.md))
automatically once the last campaign it is watching has finished, so it
no longer runs to its walltime or needs a manual `scancel`.

## Usage

``` r
add_doctor_register_step(
  wf,
  wf_name,
  watch_dir = "data/run/.doctor_watch",
  sbatch_opts = list()
)

add_doctor_teardown_step(
  wf,
  wf_name,
  watch_dir = "data/run/.doctor_watch",
  job_name = "deploy_doctor",
  sbatch_opts = list()
)
```

## Arguments

- wf:

  a `slurmworkflow` workflow summary (e.g. from
  [`slurmworkflow::create_workflow`](https://epimodel.github.io/slurmworkflow/reference/create_workflow.html)).

- wf_name:

  the campaign name, used as the marker file name. It must be identical
  in the register and teardown calls and unique per concurrent campaign;
  the workflow name is the natural choice.

- watch_dir:

  the watch-list directory, relative to the HPC repository root (the
  working directory of a workflow step job). Defaults to
  `data/run/.doctor_watch`, which is gitignored in the standard EpiModel
  project layout.

- sbatch_opts:

  a named list of sbatch options, merged over the step defaults (1 CPU,
  5 minutes, 1G, mail on FAIL).

- job_name:

  the SLURM job name of the deploy doctor to stop. Defaults to
  `deploy_doctor`, matching the `#SBATCH --job-name` default in the
  bundled `deploy_doctor.sh`. If you rename the doctor's job at submit
  time to scope it to one project, pass the same name here or the
  teardown will not find it.

## Value

the updated workflow summary, with one step appended.

## Details

The deploy doctor is one standalone SLURM job, launched once per deploy
and shared across every concurrent campaign whose job name matches its
`PATTERN`. It therefore must not be stopped when any single workflow
finishes, only when the last one does. The watch list is a directory
holding one empty marker file per live campaign. Add the register step
near the start of a workflow (right after the workflow is created) and
the teardown step as the final step:

1.  the register step creates the marker for this campaign;

2.  the teardown step removes this campaign's marker and, only if the
    directory is then empty, stops the doctor.

Because each campaign removes its own marker before testing emptiness,
whichever campaign finishes last always observes an empty directory. No
concurrent sibling is ever left unmonitored, and there is no
interleaving in which two simultaneous finishes both leave the doctor
running. `slurmworkflow` chains steps with `afterany`, so the teardown
runs even when an earlier step fails. Register and teardown are a
matched pair: a workflow that registers but never tears down leaves a
stale marker that blocks teardown for other campaigns, and a teardown
with no matching doctor is a harmless no-op.

## See also

[`hpc_doctor_script`](http://epimodel.github.io/EpiModelHPC/reference/hpc_doctor_script.md)
for the doctor itself.

## Examples

``` r
if (FALSE) { # \dontrun{
wf <- make_em_workflow("my_campaign", override = TRUE)
wf <- add_doctor_register_step(wf, "my_campaign")
# ... netsim / merge / process steps ...
wf <- add_doctor_teardown_step(wf, "my_campaign")
} # }
```
