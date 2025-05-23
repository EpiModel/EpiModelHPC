% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/netsim_scenarios.R
\name{netsim_scenarios}
\alias{netsim_scenarios}
\title{Function to run EpiModel network simulations with scenarios}
\usage{
netsim_scenarios(
  path_to_x,
  param,
  init,
  control,
  scenarios_list,
  n_rep,
  n_cores,
  output_dir,
  libraries = NULL,
  ...
)
}
\arguments{
\item{path_to_x}{Path to a Fitted network model object saved with \code{saveRDS}.
(See the \code{x} argument to the \code{EpiModel::netsim} function)}

\item{param}{Model parameters, as an object of class \code{param.net}.}

\item{init}{Initial conditions, as an object of class \code{init.net}.}

\item{control}{Control settings, as an object of class
\code{control.net}.}

\item{scenarios_list}{A list of scenarios to be run. Produced by the
\code{EpiModel::create_scenario_list} function}

\item{n_rep}{The number of replication to be run for each scenario.}

\item{n_cores}{The number of CPUs on which the simulations will be run.}

\item{output_dir}{The folder where the simulation files are to be stored.}

\item{libraries}{A character vector containing the name of the libraries
required for the model to run. (e.g. EpiModelHIV or EpiModelCOVID)}

\item{...}{for compatibility reasons}
}
\description{
This function will run \code{n_rep} replications of each scenarios in
the \code{scenarios_list}. It runs them as multiple batches of up to
\code{n_cores} simulations at a time. The simfiles are then stored in the
\code{output_dir} folder and are named using the following pattern:
"sim__name_of_scenario__2.rds". Where the last number is the batch number
for this particular scenario. Each scenario is therefore run over
\code{ceiling(n_rep / n_cores)} batches.
This function is meant to mimic the behavior of
\code{step_tmpl_netsim_scenarios} in your local machine. It should fail
in a similar fashion an reciprocally, if it runs correctly locally, moving
to an HPC should not produce any issue.
}
\section{Checkpointing}{

This function takes care of editing \code{.checkpoint.dir} to create unique sub
directories for each scenario. The \code{EpiModel::control.net} way of setting up
checkpoints can be used transparently.
}

