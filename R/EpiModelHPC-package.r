
#' EpiModel Extensions for High-Performance Computing
#'
#' \tabular{ll}{
#'    Package: \tab EpiModelHPC\cr
#'    Type: \tab Package\cr
#'    Version: \tab 2.1.1\cr
#'    Date: \tab 2020-05-18\cr
#'    License: \tab GPL-3\cr
#'    LazyLoad: \tab yes\cr
#' }
#'
#' @details
#' EpiModel provides tools for the mathematical modeling of infectious diseases.
#' Supported model classes include stochastic network models, which rely on the
#' statistical framework of exponential-family random graph models (ERGMs) that
#' evolve over time. This allows for modeling of disease-related contacts with
#' duration, such as ongoing sexual partnerships.
#'
#' The level of statistical complexity of these models, based in Markov-chain
#' Monte Carlo (MCMC) simulation, results in computationally intensive
#' simulation processes. The goal of EpiModelHPC is to provide a standardized
#' framework for extending EpiModel to run on modern high-performance computing
#' (HPC) systems.
#'
#' @references The main website for EpiModel is at \url{http://epimodel.org/}.
#'             The source code for this extension package is hosted on Github
#'             at \url{http://github.com/statnet/EpiModelHPC}. Bug reports and
#'             feature requests may be filed there.
#'
#' @name EpiModelHPC-package
#' @aliases EpiModelHPC
#' @import EpiModel doParallel foreach ergm tergm
#' @importFrom utils read.table read.csv write.csv
#' @importFrom stringr str_pad
#' @docType package
#' @keywords package
#'
NULL
