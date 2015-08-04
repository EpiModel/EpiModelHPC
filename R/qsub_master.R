
#' @title Create qsub Bash Shell Script Parameter Combination
#'
#' @description Creates a master-level qsub script given a set of parameter
#'              combinations implied by one or more parameters passed in.
#'
#' @param outfile Name of the output bash shell script file. If \code{""}, then
#'        will print to console.
#' @param runsimfile Name of the bash shell script file that contains the R batch
#'        commandsis
#' @param simno.start Starting number for the \code{SIMNO} variable. If set to
#'        \code{"auto"} and \code{append=TRUE}, will read the lines of \code{outfile}
#'        and start numbering at one after the previous maximum.
#' @param nsubjobs Number of sub/array jobs to run per simulation set.
#' @param backfill If \code{TRUE}, use the backfill queue to submit jobs. If
#'        numeric, will specify the first X jobs on the grid as non-backfill.
#' @param email If \code{TRUE}, send email on job termination or completion.
#' @param append If \code{TRUE}, will append lines to a previously created shell
#'        script.
#' @param vars A list of parameters with varying values (see example).
#'
#' @export
#'
#' @examples
#' vars <- list(A = 1:10, B = seq(0.5, 1.5, 0.5))
#' qsub_master(vars = vars, outfile = "")
#'
#' qsub_master(vars = vars, outfile = "", backfill = TRUE)
#' qsub_master(vars = vars, outfile = "", backfill = 10)
#'
qsub_master <- function(outfile = "master.sh",
                        runsimfile = "runsim.sh",
                        simno.start = 1,
                        nsubjobs = 4,
                        backfill = TRUE,
                        email = FALSE,
                        append = FALSE,
                        vars) {

  grd.temp <- do.call("expand.grid", vars)
  if (simno.start == "auto" & append == TRUE) {
    t <- read.table(outfile)
    t <- as.list(t[nrow(t), ])
    tpos <- unname(which(sapply(t, function(x) grepl("SIMNO", x)) == TRUE))
    vs <- as.character(t[[tpos]])
    vs1 <- strsplit(vs, ",")[[1]][1]
    sn <- as.numeric(strsplit(vs1, "=")[[1]][2])
    SIMNO <- (sn + 1):(sn + nrow(grd.temp))
  } else {
    if (simno.start == "auto") {
      stop("simno.start cannot be \"auto\" if append is FALSE", call. = FALSE)
    }
    SIMNO <- simno.start:(simno.start + nrow(grd.temp) - 1)
  }
  grd <- data.frame(SIMNO, grd.temp)

  if (is.logical(backfill)) {
    backfill.ch <- rep(ifelse(backfill == TRUE, "-q bf", "-q batch"), nrow(grd))
  } else {
    backfill.ch <- rep(c("-q batch", "-q bf"), c(backfill, max(0, nrow(grd) - backfill)))
    if (length(backfill.ch) > nrow(grd)) {
      backfill.ch <- backfill.ch[1:nrow(grd)]
    }
  }

  email.ch <- ifelse(email == FALSE, "-m n", "-m ae")
  if (nsubjobs > 1) {
    nsubjobs.ch <- paste("1", nsubjobs, sep = "-")
  } else {
    nsubjobs.ch <- "1 "
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

    cat("\nqsub", backfill.ch[i], "-t", nsubjobs.ch, email.ch, "-v", v.args, runsimfile,
        file = outfile, append = TRUE)
  }
  cat("\n", file = outfile, append = TRUE)

}
