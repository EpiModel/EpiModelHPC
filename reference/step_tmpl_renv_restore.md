# Step template to update a project `renv`

This template makes the step run `git pull` and `renv::restore()`. This
could help ensure that the project is up to date when running the rest
of the workflow. See
[`slurmworkflow::step_tmpl_bash_lines`](https://epimodel.github.io/slurmworkflow/reference/step_tmpl_bash_lines.html)
for details on step templates

## Usage

``` r
step_tmpl_renv_restore(git_branch, setup_lines = NULL, lockfile = NULL)
```

## Arguments

- git_branch:

  The git branch that the project is supposed to follow. If the project
  is not following the right branch, this step will error.

- setup_lines:

  (optional) a vector of bash lines to be run first. This can be used to
  load the required modules (like R, python, etc).

- lockfile:

  (optional) path to an alternative lockfile to restore

## Value

a template function to be used by `add_workflow_step`
