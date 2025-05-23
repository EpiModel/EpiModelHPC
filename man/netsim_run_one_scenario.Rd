% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/netsim_scenarios.R
\name{netsim_run_one_scenario}
\alias{netsim_run_one_scenario}
\title{Run one \code{netsim} call with a scenario and saves the results deterministically}
\usage{
netsim_run_one_scenario(
  scenario,
  batch_num,
  path_to_x,
  param,
  init,
  control,
  libraries,
  output_dir,
  n_batch,
  n_rep,
  n_cores
)
}
\arguments{
\item{scenario}{A single "\code{EpiModel} scenario" to be used in the simulation}

\item{batch_num}{The batch number, calculated from the number of replications
and CPUs required.}

\item{path_to_x}{Path to a Fitted network model object saved with \code{saveRDS}.
(See the \code{x} argument to the \code{EpiModel::netsim} function)}

\item{param}{Model parameters, as an object of class \code{param.net}.}

\item{init}{Initial conditions, as an object of class \code{init.net}.}

\item{control}{Control settings, as an object of class
\code{control.net}.}

\item{libraries}{A character vector containing the name of the libraries
required for the model to run. (e.g. EpiModelHIV or EpiModelCOVID)}

\item{output_dir}{The folder where the simulation files are to be stored.}

\item{n_batch}{The number of batches to be run \code{ceiling(n_rep / n_cores)}.}

\item{n_rep}{The number of replication to be run for each scenario.}

\item{n_cores}{The number of CPUs on which the simulations will be run.}
}
\description{
This inner function is called by \code{netsim_scenarios} and
\code{step_tmpl_netsim_scenarios}.
}
\section{Checkpointing}{

This function takes care of editing \code{.checkpoint.dir} to create unique sub
directories for each scenario. The \code{EpiModel::control.net} way of setting up
checkpoints can be used transparently.
}

