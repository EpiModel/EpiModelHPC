
#' @title Create sbatch Bash Shell Script with Parameter Combination
#'
#' @description Creates a master-level SLURM::sbatch script given a set of parameter
#'              combinations implied by environmental arguments used as parameters.
#'
#' @param vars A list of parameters with varying values (see examples below).
#' @param outfile Name of the output bash shell script file to write. If \code{""}, 
#'        then will print to console.
#' @param runsimfile Name of the bash shell script file that contains the R batch
#'        commands
#' @param simno.start Starting number for the \code{SIMNO} variable. If missing
#'        and \code{append=TRUE}, will read the lines of \code{outfile}
#'        and start numbering at one after the previous maximum.
#' @param narray Number of array jobs to run per scenario set.
#' @param ckpt If \code{TRUE}, use the checkpoint queue to submit jobs. If
#'        numeric, will specify the first X jobs on the grid as non-backfill.
#' @param append If \code{TRUE}, will append lines to a previously created shell
#'        script. New simno will either start with value of \code{simno.start}
#'        or the previous value if missing.
#'
#' @export
#'
#' @examples
#' vars <- list(A = 1:10, B = seq(0.5, 1.5, 0.5))
#' sbatch_master(vars = vars)
#' sbatch_master(vars = vars, narray = 10)
#' sbatch_master(vars = vars, narray = 4, ckpt = TRUE)
#' sbatch_master(vars = vars, narray = 4, ckpt = 10)
#' sbatch_master(vars = vars, simno.start = 1000)
#' 
#' \dontrun{
#' sbatch_master(vars = vars, narray = 4, simno.start = 1000, outfile = "master.sh")
#' sbatch_master(vars = vars, narray = 4, append = TRUE, outfile = "master.sh")
#' 
#' sbatch_master(vars = vars, simno.start = 1000, outfile = "master.sh")
#' sbatch_master(vars = vars, simno.start = 2000, append = TRUE, outfile = "master.sh")
#' }
#'
sbatch_master <- function(vars,
                          outfile = "",
                          runsimfile = "runsim.sh",
                          simno.start,
                          narray = 0,
                          ckpt = FALSE,
                          append = FALSE
                          ) {

  grd.temp <- do.call("expand.grid", vars)
  if (append == TRUE) {
    if (missing(simno.start)) {
      t <- read.table(outfile)
      t <- as.list(t[nrow(t), ])
      tpos <- unname(which(sapply(t, function(x) grepl("SIMNO", x)) == TRUE))
      vs <- as.character(t[[tpos]])
      vs1 <- strsplit(vs, ",")[[1]][2]
      sn <- as.numeric(strsplit(vs1, "=")[[1]][2])
      SIMNO <- (sn + 1):(sn + nrow(grd.temp))
    } else {
      SIMNO <- simno.start:(simno.start + nrow(grd.temp) - 1)
    }
  } else {
    if (missing(simno.start)) {
      simno.start <- 1
    }
    SIMNO <- simno.start:(simno.start + nrow(grd.temp) - 1)
  }
  NJOBS <- narray
  grd <- data.frame(SIMNO, NJOBS, grd.temp)

  if (is.logical(ckpt)) {
    ckpt.ch <- rep(ifelse(ckpt == TRUE, "-p ckpt -A csde-ckpt", "-p csde -A csde"), nrow(grd))
  } else {
    ckpt.ch <- rep(c("-p ckpt -A csde-ckpt", "-p csde -A csde"), times = c(ckpt,  max(0, nrow(grd) - ckpt)))
    if (length(ckpt.ch) > nrow(grd)) {
      ckpt.ch <- ckpt.ch[1:nrow(grd)]
    }
  }

  if (narray > 1) {
    narray.ch <- paste(" --array=1", narray, sep = "-")
  } else if (narray == 1) {
    narray.ch <- " --array=1 "
  } else {
    narray.ch <- " "
  }
  
  if (append == FALSE) {
    cat("#!/bin/bash\n", file = outfile)
  }
  for (i in 1:nrow(grd)) {
    v.args <- NA
    for (j in 1:ncol(grd)) {
      v.args[j] <- paste0(names(grd)[j], "=", grd[i,j])
    }
    v.args <- paste(v.args, collapse = ",")
    v.args <- paste(" --export=ALL", v.args, sep = ",")

    cat("\n", "sbatch ", ckpt.ch[i], narray.ch, v.args, " ", runsimfile,
        file = outfile, append = TRUE, sep = "")
  }
  cat("\n", file = outfile, append = TRUE)

}
