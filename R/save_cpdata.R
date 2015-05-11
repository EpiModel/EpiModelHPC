
#' @title Saves for Network Simulation Rdata Files for Checkpointing
#'
#' @description Module to save simulation data from stochastic network models
#'              to disk at specified time intervals.
#'
#' @param dat A master data object used in models simulated with \code{netsim}.
#' @param at Current time step
#'
#' @details
#' This module saves data to a standardized location with standardized file names
#' for the purposes of checkpointing. This is intended to be used when running
#' these simulations with \code{\link{netsim_hpc}}, and will be automatically
#' inserted into the workflow when this is done.
#'
#' @export
save_cpdata <- function(dat, at) {

  if (!is.null(dat$control$save.int) && at %% dat$control$save.int == 0) {
    currsim <- dat$control$currsim
    simno <- dat$control$simno
    fn <- paste0("data/sim", simno, "/sim", currsim, ".cp.rda")
    dat$last.ts <- at
    x <- dat
    save(x, file = fn)
  }

  return(dat)
}
