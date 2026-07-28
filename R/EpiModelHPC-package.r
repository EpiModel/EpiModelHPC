
#' EpiModel Extensions for High-Performance Computing
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
#' @references The main website for EpiModel is at \url{https://www.epimodel.org/}.
#'             The source code for this extension package is hosted on GitHub
#'             at \url{https://github.com/EpiModel/EpiModelHPC}. Bug reports and
#'             feature requests may be filed there.
#'
#' @name EpiModelHPC-package
#' @aliases EpiModelHPC
#' @import EpiModel
#' @importFrom rlang .data
#' @keywords package
#'
"_PACKAGE"
