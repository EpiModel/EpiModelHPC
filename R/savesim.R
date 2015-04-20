
#' @title Save Simulation Data from Stochastic Network Models
#'
#' @description Saves an Rdata file containing stochastic network model output
#'              from \code{netsim} function calls with time-stamped file names.
#'
#' @param sim An \code{EpiModel} object of class \code{netsim} to be saved to an
#'        Rdata file.
#' @param dataf If \code{TRUE}, saves data file within a subfolder called "data"
#'        relative to the current working directory, otherwise saves file to 
#'        current working directory. A data folder will be created if one does 
#'        not already exist.
#' @param save.min If \code{TRUE}, saves a small version of the \code{netsim}
#'        object in which large elements of the data structure like the network
#'        object and the transmission data frame are removed. The resulting
#'        name for this small file will have ".min" appended at the end.
#' @param save.max If \code{TRUE}, saves the full \code{netsim} object without
#'        any deletions.
#' 
#' @details
#' This function provides an automated method for saving a time-stamped Rdata
#' file containing the simulation number of a stochastic network model run
#' with \code{netsim}. This is used by default by the \code{\link{network_hpc}}
#' function.
#' 
#' @export
#' 
savesim <- function(sim, 
                    dataf = TRUE,
                    save.min = TRUE,
                    save.max = TRUE) {
  
  if (!is.null(sim$control$simno)) {
    no <- sim$control$simno
  } else {
    no <- 1
  }
  
  ctime <- format(Sys.time(), "%Y%m%d.%H%M")
  fn <- paste0("sim.n", no, ".", ctime, ".rda")
  
  if (dataf == TRUE) {
    if (file.exists("data/") == FALSE) {
      dir.create("data/")
    }
    fn <- paste0("data/", fn)
  }
  if (save.max == TRUE) {
    save(sim, file = fn)
  }
  
  if (save.min == TRUE) {
    sim$network <- NULL
    sim$stats$transmat <- NULL
    environment(sim$control$nwstats.formula) <- NULL
    for (i in seq_along(sim$nwparam)) {
      sim$nwparam[[i]][c("formation", "coef.form", "coef.form.crude",
                         "dissolution", "coef.diss", "edapprox",
                         "constraints")] <- NULL
    }
    fnm <- paste0("sim.n", no, ".", ctime, ".min.rda")
    if (dataf == TRUE) {
      fnm <- paste0("data/", fnm)
    }
    save(sim, file = fnm)
  }
  
}