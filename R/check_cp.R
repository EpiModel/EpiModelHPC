
#' @title Checks for Checkpointed Rdata Files
#'
#' @description Checks whether there are checkpointed data files in a specific
#'              format given a simulation number.
#'
#' @param simno Simulation number for current model simulation, typically stored
#'        in \code{control$simno}.
#'
#' @details
#' This function checks whether checkpointed data files are available for loading.
#' Checkpointed data files are incrementally saved during the simulation and
#' loaded when a simulation job has been cancelled and restarted. This is done
#' automatically within the \code{\link{netsim_hpc}} function.
#'
#' Checkpointed data files are searched for in a specific subdirectory relative
#' to the current working directory: \code{data/sim<x>}, where \code{<x>} is the
#' \code{simno} value. Within that directory \code{check_cp} looks for files
#' ending \code{.cp.rda}, which is the standard checkpoint data file name. Note
#' that these standards for file directory and name are consistent with the
#' \code{\link{save_cpdata}} module function. If running simulations using the
#' \code{\link{netsim_hpc}} function, this data saving module will automatically
#' be inserted in the workflow of a simulation.
#'
#' The files are tested to see that they are of similar size, meaning that no
#' file is less than 50% of the average file size of the others. Smaller size
#' files usually indicates that the interim file saving was interrupted. If the
#' files exist and are of correct size, a full directory name is returned, else
#' \code{NULL} is returned.
#'
#' @export
#'
check_cp <- function(simno) {

  goodFile <- FALSE

  dirname <- paste0("data/sim", simno)

  if (file.exists(dirname) == FALSE) {
    return(NULL)
  }

  fn <- list.files(path = dirname, pattern = "*.cp.rda", full.names = TRUE)
  if (length(fn) > 0) {
    a <- unname(sapply(fn, function(x) file.info(x)$size))
    goodFile <- ifelse(all(a > (mean(a) - mean(a) * 0.5)), TRUE, FALSE)
  }

  if (goodFile == TRUE) {
    return(dirname)
  } else {
    return(NULL)
  }

}
