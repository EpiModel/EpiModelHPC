
#' @title Custom Progress Print Module for HPC Workflow
#'
#' @description This function prints progress from stochastic network models
#'              simulated with \code{netsim} to the console or a txt file.
#'
#' @param x If the \code{type} is "startup", then an object of class
#'        \code{control.net}, otherwise the all master data object in
#'        \code{netsim} simulations.
#' @param type Progress type, either of "startup" for starting messages before
#'        all simulations, or "progress" for time step specific messages.
#' @param s Current simulation number, if type is "progress".
#' @param at Current time step, if type is "progress".
#'
#' @export
#' @keywords internal
#'
verbose.hpc.net <- function(x, type, s = 1, at = 2) {

  if (interactive()) {
    if (type == "startup" && x$ncores == 1) {
      if (x$verbose == TRUE) {
        cat("\nStarting Network Simulation...")
      }
    }

    if (type == "progress" && x$control$ncores == 1) {
      if (x$control$verbose == TRUE) {
        if (x$control$verbose.int == 0 && at == x$control$nsteps) {
          cat("\nSim = ", s, "/", x$control$nsims, sep = "")
        }
        if (x$control$verbose.int > 0 && (at %% x$control$verbose.int == 0)) {
          cat("\014")
          cat("\nEpidemic Simulation")
          cat("\n----------------------------")
          cat("\nSimulation: ", s, "/", x$control$nsims, sep = "")
          cat("\nTimestep: ", at, "/", x$control$nsteps, sep = "")
          active <- x$attr$active
          status <- x$attr$status[which(active == 1)]
          if (class(status) == "character") {
            status <- ifelse(status == "i", 1, 0)
          }
          cat("\nPrevalence:", sum(status, na.rm = TRUE))
          cat("\nPopulation Size:", sum(active == 1))
          cat("\n----------------------------")
        }
      }
    }
  } else {
    if (type == "progress" && (at == 2 || at %% x$control$verbose.int == 0) && !is.null(x$control$simno))  {
      if (is.null(x$control$verbose.dir)) {
        fn <- paste0("out/sim", x$control$simno, ".txt")
      } else {
        fn <- paste0(x$control$verbose.dir, "sim", x$control$simno, ".txt")
      }
      cat("\nSim: ", paste0(x$control$simno, ".", s),
          " | Time step: ", at, "/", x$control$nsteps, " | Time: ", as.character(Sys.time()),
          sep = "", file = fn, append = TRUE)
    }
  }
}
