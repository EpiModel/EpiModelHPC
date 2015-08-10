
#' @title Truncate Simulation Time Series
#'
#' @description Left-truncates a simulation epidemiological summary statistics and
#'              network statistics at a specified time step.
#'
#' @param x Object of class \code{netsim}.
#' @param at Time step at which to left-truncate the time series.
#'
#' @details
#' This function would be used when running a follow-up simulation from time steps
#' \code{b} to \code{c} after a burnin period from time \code{a} to \code{b},
#' where the final time window of interest for data analysis is \code{b} to \code{c}
#' only.
#'
#' @export
#'
truncate_sim <- function(x, at) {

  rows <- at:(x$control$nsteps)

  # epi
  x$epi <- lapply(x$epi, function(r) r[rows, ])

  # nwstats
  for (i in 1:length(x$stats$nwstats)) {
    for (j in 1:length(x$stats$nwstats[[i]])) {
      x$stats$nwstats[[i]][[j]] <- x$stats$nwstats[[i]][[j]][rows, ]
    }
  }

  # control settings
  x$control$start <- 1
  x$control$nsteps <- max(seq_along(rows))

  return(x)
}
