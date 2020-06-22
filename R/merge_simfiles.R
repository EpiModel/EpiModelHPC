
#' @title Save Simulation Data from Stochastic Network Models
#'
#' @description Saves an Rdata file containing stochastic network model output
#'              from \code{netsim} function calls with time-stamped file names.
#'
#' @param simno First components of the simulation number in the standard format
#'        written by \code{\link{savesim}} (see details).
#' @param ftype Type of file to be merged, with either \code{"min"} for compacted
#'        files or \code{"max"} for large files. File availability depends on
#'        what files were saved in \code{\link{savesim}}.
#' @param indir File directory relative to working directory where simulation
#'        files are stored.
#' @param vars Character vector of variables stored in \code{epi} sub-list to
#'        retain in output data. If any variables are specified, then network
#'        statistics and other ancillary data are removed.
#' @param truncate.at Left-truncates a simulation epidemiological summary
#'        statistics and network statistics at a specified time step.
#' @param verbose If \code{TRUE}, print file load progress to console.
#'
#' @details
#' This function merges individual simulation runs stored in separate Rdata files
#' into one larger output object for analysis. This function would typically be
#' used after running \code{\link{netsim_hpc}} with an array job specification
#' (see the vignette) in order to combine individual blocks of simulations into
#' one complete set.
#'
#' The \code{simno} argument must therefore be specified as the first component
#' of the simulation number: what would be passed to the \code{-v} parameter
#' in \code{qsub}. For example, if one would like to aggregate the two files for
#' simulation number 1 stored in the \code{sim.n1.1.*} and \code{sim.n1.2.*} files,
#' the \code{simno} argument would be \code{1}.
#'
#' @export
#'
merge_simfiles <- function(simno, ftype = "min", indir = "data/",
                           vars = NULL,  truncate.at = NULL, verbose = TRUE) {

  if (!(ftype %in% c("min", "max"))) {
    stop("ftype must be either \"min\" or \"max\" ", call. = FALSE)
  }

  if (ftype == "min") {
    fn <- list.files(indir,
                     pattern = paste0("sim.n", simno, ".[0-9]+.*.min.rda"),
                     full.names = TRUE)
  } else if (ftype == "max") {
    fn <- list.files(indir,
                     pattern = paste0("sim.n", simno, ".[0-9]+.*.*[0-9].rda"),
                     full.names = TRUE)
  }
  if (length(fn) == 0) {
    stop("No files of that simno in the specified indir", call. = FALSE)
  }

  for (i in seq_along(fn)) {
    load(fn[i])

    if (!is.null(truncate.at)) {
      sim <- truncate_sim(sim, truncate.at)
    }

    if (ftype == "min") {
      sim$network <- NULL
      sim$attr <- NULL
      sim$temp <- NULL
      sim$el <- NULL
      sim$p <- NULL
      if (!is.null(vars)) {
        sim$epi <- sim$epi[vars]
        sim$stats <- NULL
        if (!is.null(sim$riskh)) {
          sim$riskh <- NULL
        }
      }
    }
    if (i == 1) {
      out <- sim
    } else {
      out <- merge(out, sim, param.error = FALSE)
    }
    if (verbose == TRUE) {
      cat("File ", i, "/", length(fn), " Loaded ... \n", sep = "")
    }


  }

  return(out)
}


#' @title Process sub-job simulation files saved as a series of Rdata files.
#'
#' @description Wraps the \code{merge_simfiles} function to merge all sub-job
#'              Rdata files and saves into a single output file, with the option
#'              to delete the sub-job files.
#'
#' @param simno Simulation number to process.
#' @param indir File directory relative to working directory where simulation
#'        files are stored.
#' @param outdir File directory relative to working directory where simulation
#'        files should be saved.
#' @param vars Argument passed to \code{\link{merge_simfiles}}.
#' @param truncate.at Left-truncates a simulation epidemiological summary
#'        statistics and network statistics at a specified time step.
#' @param min.n Integer value for the minimum number of simulation files to be
#'        eligible for processing.
#' @param nsims Total number of simulations across all sub-jobs.
#' @param compress Argument passed to \code{\link{save}}.
#' @param delete.sub Delete sub-job files after merge and saving.
#' @param verbose Logical, print progress to console.
#'
#' @export
#'
process_simfiles <- function(simno = NA, indir = "data/", outdir = "data/",
                             vars = NULL, truncate.at = NULL,
                             min.n, nsims, compress = "xz", delete.sub = TRUE,
                             verbose = FALSE) {

  if (is.na(simno)) {
    fn <- list.files(indir, pattern = "sim.*.[0-9]+.*.rda", full.names = FALSE)
    nums <- gsub("n", "",
                 unname(sapply(fn, function(x) strsplit(x, split = "[.]")[[1]][2])))
    unique.nums <- unique(nums)
  } else {
    fn <- list.files(indir, pattern = paste0("sim.n", simno, ".[0-9]+.*.rda"),
                     full.names = FALSE)
    unique.nums <- simno
  }

  for (j in seq_along(unique.nums)) {
    fnj <- list.files(indir, pattern = paste0("sim.n", unique.nums[j], "*.[0-9]+.*.rda"),
                      full.names = TRUE)
    if (!missing(min.n)) {
      if (min.n > length(fnj)) next
    }
    sim <- merge_simfiles(simno = unique.nums[j], indir = indir, vars = vars,
                          truncate.at = truncate.at, verbose = FALSE)
    if (!missing(nsims) && sim$control$nsims > nsims) {
      sim <- get_sims(sim, sims = sample(nsims))
    }
    if (dir.exists(outdir) == FALSE) {
      dir.create(outdir)
    }
    save(sim, file = paste0(outdir, "/sim.n", unique.nums[j], ".rda"), compress = compress)
    if (delete.sub == TRUE) {
      unlink(fnj)
    }
    if (verbose == TRUE) {
      cat("File", unique.nums[j], "complete ... \n")
    }
  }

}
