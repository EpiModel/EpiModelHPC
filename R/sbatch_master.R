
#' @title Create sbatch Bash Shell Script with Parameter Combination
#'
#' @description Creates a master-level SLURM::sbatch script given a set of parameter
#'              combinations implied by environmental arguments used as parameters.
#'
#' @param vars A list of parameters with varying values (see examples below).
#' @param master.file Name of the output bash shell script file to write. If 
#'        \code{""}, then will print to console.
#' @param runsim.file Name of the bash shell script file that contains the R batch
#'        commands to be executed by \code{sbatch}.
#' @param build.runsim If \code{TRUE}, will write out a bash shell script with the
#'        file name \code{runsim.file} that loads the R environment listed in
#'        \code{env.file} and execute \code{Rscript} on the file listed in 
#'        \code{rscript.file}.
#' @param env.file Bash shell script to load the R environment desired. Optionally
#'        kept in a user's home directory with the default file name. Example 
#'        script below.
#' @param rscript.file Name of the \code{.R} file that contains the primary 
#'        simulation to be executed by \code{Rscript}.
#' @param param.sheet Name of a csv file to write out the list of varying 
#'        parameters and simulation numbers set within the function. 
#' @param param.tag Character string for current scenario batch added to 
#'        param.sheet.
#' @param simno.start Starting number for the \code{SIMNO} variable. If missing
#'        and \code{append=TRUE}, will read the lines of \code{outfile}
#'        and start numbering at one after the previous maximum.
#' @param nsims Total number of simulations across all array jobs.
#' @param ncores Number of cores per node to use within each Slurm job. 
#' @param ckpt If \code{TRUE}, use the checkpoint queue to submit jobs. If
#'        numeric, will specify the first X jobs on the grid as non-backfill.
#' @param append If \code{TRUE}, will append lines to a previously created shell
#'        script. New simno will either start with value of \code{simno.start}
#'        or the previous value if missing.
#' @param mem Amount of memory needed per node within each Slurm job.
#' @param walltime Amount of clock time needed per Slurm job.
#' @param jobname Job name assigned to Slurm job. If unspecified, defaults to the
#'        simulation number in each job.
#' @param partition.main Name of primary HPC partition (passed to -p).
#' @param partition.ckpt Name of checkpoint HPC partition (passed to -p).
#' @param account.main Name of primary account (passed to -A).
#' @param account.ckpt Name of checkpoint account (passed to -A).
#'
#' @export
#'
#' @examples
#' # Examples printing to console
#' vars <- list(A = 1:5, B = seq(0.5, 1.5, 0.5))
#' sbatch_master(vars)
#' sbatch_master(vars, nsims = 250)
#' sbatch_master(vars, ckpt = TRUE)
#' sbatch_master(vars, nsims = 50, ckpt = 10)
#' sbatch_master(vars, simno.start = 1000)
#' sbatch_master(vars, jobname = "epiSim")
#' 
#' \dontrun{
#' # Full-scale example writing out files
#' sbatch_master(vars, nsims = 50, simno.start = 1000, build.runsim = TRUE,
#'               master.file = "master.sh", param.sheet = "params.csv")
#' sbatch_master(vars, nsims = 50, append = TRUE, 
#'               master.file = "master.sh", param.sheet = "params.csv")
#' 
#' ## Example bash environment file
#' #!/bin/bash
#' 
#' . /gscratch/csde/sjenness/spack/share/spack/setup-env.sh
#' module load gcc-8.2.0-gcc-4.8.5-rhsxipz
#' module load r-3.5.1-gcc-8.2.0-4suigve
#' 
#' }
#' 
sbatch_master <- function(vars,
                          master.file = "",
                          runsim.file = "runsim.sh",
                          build.runsim = FALSE,
                          env.file = "~/loadR.sh",
                          rscript.file = "sim.R",
                          param.sheet,
                          param.tag,
                          simno.start,
                          nsims = 100,
                          ncores = 16,
                          ckpt = FALSE,
                          append = FALSE,
                          mem = "55G",
                          walltime = "1:00:00",
                          jobname,
                          partition.main = "csde",
                          partition.ckpt = "ckpt",
                          account.main = "csde",
                          account.ckpt = "csde-ckpt"
                          ) {

  # build master.sh file
  grd.temp <- do.call("expand.grid", vars)
  if (append == TRUE) {
    if (missing(simno.start)) {
      t <- read.table(master.file)
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
  narray <- ceiling(nsims/ncores)
  NJOBS <- narray
  NSIMS <- nsims
  grd <- data.frame(SIMNO, NJOBS, NSIMS, grd.temp)

  pA.ckpt <- paste("-p", partition.ckpt, "-A", account.ckpt)
  pA.main <- paste("-p", partition.main, "-A", account.main)
  
  if (is.logical(ckpt)) {
    ckpt.ch <- rep(ifelse(ckpt == TRUE, pA.ckpt, pA.main), nrow(grd))
  } else {
    ckpt.ch <- rep(c(pA.ckpt, pA.main), times = c(ckpt,  max(0, nrow(grd) - ckpt)))
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
    cat("#!/bin/bash\n", file = master.file)
  }
  for (i in 1:nrow(grd)) {
    v.args <- NA
    for (j in 1:ncol(grd)) {
      v.args[j] <- paste0(names(grd)[j], "=", grd[i,j])
    }
    v.args <- paste(v.args, collapse = ",")
    v.args <- paste(" --export=ALL", v.args, sep = ",")

    node.args <- paste(" --nodes=1 --ntasks-per-node=", ncores, sep = "")
    time.arg <- paste(" --time=", walltime, sep = "")
    mem.arg <- paste(" --mem=", mem, sep = "")
    if (!missing(jobname)) {
      jname.arg <- paste(" --job-name=", jobname, sep = "")
    } else {
      jname.arg <- paste(" --job-name=s", SIMNO[i], sep = "")
    }
    
    cat("\n", "sbatch ", ckpt.ch[i], narray.ch, 
        node.args, time.arg, mem.arg, jname.arg,
        v.args, " ", runsim.file,
        file = master.file, append = TRUE, sep = "")
  }
  cat("\n", file = master.file, append = TRUE)
  
  # build runsim.sh script
  if (build.runsim == TRUE) {
    cat("#!/bin/bash\n", 
        "\nsource", env.file,
        "\nRscript", rscript.file, file = runsim.file)
  }

  # build params sheet
  if (!missing(param.sheet)) {
    out <- grd[, -2]
    if (!missing(param.tag)) {
      out <- cbind(tag = param.tag, out)
    }
    if (append == FALSE) {
      write.csv(out, file = param.sheet, row.names = FALSE)
    } else {
      prior <- read.csv(param.sheet)
      out <- rbind(prior, out)
      write.csv(out, file = param.sheet, row.names = FALSE)
    }
  }


}
