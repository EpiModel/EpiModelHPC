
#' @title Initializes Network Model after Checkpointing
#'
#' @description Sets the parameters, initial conditions, and control settings on
#'              the data object, necessary for checkpointing simulations.
#'
#' @param x An \code{EpiModel} object of class \code{\link{netest}}.
#' @param param An \code{EpiModel} object of class \code{\link{param.net}}.
#' @param init An \code{EpiModel} object of class \code{\link{init.net}}.
#' @param control An \code{EpiModel} object of class \code{\link{control.net}}.
#' @param s Simulation number, used for restarting dependent simulations.
#'
#' @details
#' When running a stochastic network model from checkpointed data, it is not
#' necessary to run the originally specified initialization module. Instead, the
#' initialization module should reset the parameters, initial conditions, and
#' control settings back onto the data object.
#'
#' This module is intended to be used in the context of running simulations on
#' high-performance computing settings using \code{\link{netsim_hpc}}. That
#' function automatically replaces the original initialization function with this
#' checkpointed version when the simulation is in a checkpoint state.
#'
#' @export
#'
initialize.cp <- function(x, param, init, control, s) {

  x$param <- param
  x$param$modes <- ifelse(x$nw$gal$bipartite, 2, 1)
  x$init <- init
  x$control <- control

  return(x)

}