
#' @title Save Simulation Data from Stochastic Network Models
#'
#' @description Saves an Rdata file containing stochastic network model output
#'              from \code{netsim} function calls with time-stamped file names.
#'
#' @param sim An \code{EpiModel} object of class \code{netsim} to be saved to an
#'        Rdata file.
#' @param data.dir Path to save data files. Directory will be created if it does
#'        not already exist.
#' @param save.min If \code{TRUE}, saves a small version of the \code{netsim}
#'        object in which large elements of the data structure like the network
#'        object and the transmission data frame are removed. The resulting
#'        name for this small file will have ".min" appended at the end.
#' @param save.max If \code{TRUE}, saves the full \code{netsim} object without
#'        any deletions.
#' @param time.stamp If \code{TRUE}, saves the file with a time stamp in the
#'        file name.
#' @param compress Matches the \code{compress} argument for the \code{\link{save}}
#'        function.
#'
#' @details
#' This function provides an automated method for saving a time-stamped Rdata
#' file containing the simulation number of a stochastic network model run
#' with \code{netsim}.
#'
#' @export
#'
savesim <- function(sim,
                    data.dir = "data/",
                    save.min = TRUE,
                    save.max = TRUE,
                    time.stamp = TRUE,
                    compress = FALSE) {

  if (!is.null(sim$control$simno)) {
    no <- sim$control$simno
  } else {
    no <- 1
  }

  ctime <- format(Sys.time(), "%Y%m%d.%H%M")

  if (!dir.exists(data.dir)) {
    dir.create(data.dir)
  }

  if (save.max == TRUE) {
    if (time.stamp == TRUE) {
      fn <- paste0("sim.n", no, ".", ctime, ".rda")
    } else {
      fn <- paste0("sim.n", no, ".rda")
    }
    fn <- paste0(data.dir, fn)
    save(sim, file = fn, compress = compress)
  }

  if (save.min == TRUE) {
    keep <- c("param", "epi", "control")
    sim <- sim[keep]
    sim$param$netstats <- NULL
    if (time.stamp == TRUE) {
      fnm <- paste0("sim.n", no, ".", ctime, ".min.rda")
    } else {
      fnm <- paste0("sim.n", no, ".min.rda")
    }
    fnm <- paste0(data.dir, fnm)
    save(sim, file = fnm, compress = compress)
  }

}
