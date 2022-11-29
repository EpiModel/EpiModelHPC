
#' @title Stochastic Network Models on High-Performance Computing Systems
#'
#' @description Simulates stochastic network epidemic models for infectious
#'              disease dynamics in parallel.
#'
#' @param x Character vector containing the file path of an Rdata
#'        file where an object of class \code{netest} is stored. Alternatively,
#'        if restarting a previous simulation, this may be a file path for an
#'        object of class \code{netsim}.
#' @param param Model parameters, as an object of class \code{param.net}.
#' @param init Initial conditions, as an object of class \code{init.net}.
#' @param control Control settings, as an object of class \code{control.net}.
#' @param cp.save.int Check-pointing save interval, which is used to specify how
#'        often intermediate data should be saved out to disk. When a job has been
#'        check-pointed, it will resume automatically at the last saved time
#'        step stored on disk. If set to \code{NULL}, then no intermediate data
#'        storage will occur.
#' @param save.min Argument passed to \code{\link{savesim}}.
#' @param save.max Argument passed to \code{\link{savesim}}.
#' @param compress Matches the \code{compress} argument for the \code{\link{save}}
#'        function.
#' @param verbose If \code{FALSE}, suppress all output messages except errors.
#'
#' @details
#' This function provides a systematic method to running stochastic network
#' models in parallel on high-performance computing systems.
#'
#' The main purpose of using \code{netsim_hpc} is for a standardized checkpointing
#' method. Checkpointing is defined as incrementally saving simulation data for
#' the purpose of reloading it if a simulation job is canceled and restarted. If
#' checkpointing is not needed, users are advised to run their models directly
#' with the \code{EpiModel::netsim} function.
#'
#' This function performs the following tasks:
#' \enumerate{
#'   \item Check for the existence of checkpointed data, using the
#'         \code{\link{check_cp}} function. If CP data are available, a
#'         checkpointed model will be run, else a new model will be run.
#'   \item Create a checkpoint directory if one does not exist at
#'         "data/simsimno". This and the related checkpointing functions will
#'         not occur if \code{cp.save.int} is set to \code{NULL}.
#'   \item Sets the checkpoint save interval at the number of time steps specified
#'         in \code{cp.save.int}.
#'   \item Resets the initialize module function to \code{\link{initialize_cp}}
#'         if in checkpoint state.
#'   \item Run the simulation, either new or checkpointed, with a call to
#'         \code{EpiModel::netsim}.
#'   \item Save the completed simulation data, using the functionality of
#'         \code{\link{savesim}}.
#'   \item Remove the checkpointed data and file directory created in step 1, if
#'         it exists.
#' }
#'
#' The \code{x} argument must specify a \strong{file name} in a character string,
#' rather than a \code{netest} or \code{netsim} class object directly. This is
#' mainly for efficiency purposes in running the models in parallel.
#'
#' If \code{save.min} and \code{save.max} are both set to \code{FALSE}, then the
#' function will return rather than save the output EpiModel object.
#'
#' @export
netsim_hpc <- function(x, param, init, control,
                       cp.save.int = NULL,
                       save.min = TRUE,
                       save.max = FALSE,
                       compress = TRUE,
                       verbose = TRUE) {

  # Check x validity
  if (file.exists(x) == FALSE) {
    stop("x must be a valid path to a file containing an object of class netest",
         call. = FALSE)
  }

  # Set simno
  if (is.null(control$simno)) {
    control$simno <- 1
  }


  # Check for CP data
  cpDir <- check_cp(simno = control$simno)
  type <- ifelse(is.null(cpDir), "new", "cp")
  if (type == "cp") {
    x <- cpDir
  }

  # New simulations ---------------------------------------------------------

  if (type == "new") {

    if (verbose == TRUE) {
      cat("\nSTARTING Simulation ", control$simno, sep = "")
    }

    # Set CP save interval if missing
    if (is.null(control$save.int) && !is.null(cp.save.int)) {
      if (verbose == TRUE) {
        cat("\nSetting save.int on control settings at", cp.save.int, "time steps ... ")
      }
      control$save.int <- cp.save.int
    }

    # Store save CP on control settings
    if (is.null(control$savedata.FUN) && !is.null(control$save.int)) {
      control$savedata.FUN <- save_cpdata
      control$bi.mods <- c(control$bi.mods, "savedata.FUN")
    }

    # Creates CP directory
    if (!is.null(control$save.int)) {
      dirname <- paste0("data/sim", control$simno)
      if (file.exists("data/") == FALSE) {
        dir.create("data/")
      }
      if (file.exists(dirname) == FALSE) {
        dir.create(dirname)
      }
    }

    # Run a new simulation
    if (type == "new") {
      load(x)
      if ("sim" %in% ls()) {
        assign("est", sim)
      }
      if (verbose == TRUE) {
        cat("\nRunning new simulation from", class(est), "object ...")
      }
      sim <- netsim(est, param, init, control)
    }

  }


  # CP resumed simulations --------------------------------------------------

  if (type == "cp") {

    # Replace initialization module
    control$initialize.FUN <- initialize_cp
    control$skip.check <- TRUE

    if (verbose == TRUE) {
      cat("\nRestarting simulation from checkpoint data ...")
    }

    nsims <- control$nsims
    ncores <- ifelse(nsims == 1, 1, min(parallel::detectCores(), control$ncores))

    cluster.size <- min(nsims, ncores)
    doParallel::registerDoParallel(cluster.size)

    xfn <- x
    i <- NULL # just to pass R CMD Check
    out <- foreach(i = 1:nsims) %dopar% {
      control$nsims <- 1
      control$currsim <- i
      control$ncores <- 1
      fn <- list.files(xfn, pattern = paste0("sim", i, ".cp.rda"), full.names = TRUE)
      load(fn)
      ltstep <- x$last.ts
      if (ltstep == control$nsteps) {
        control$start <- ltstep
      } else {
        control$start <- ltstep + 1
      }
      netsim(x, param, init, control)
    }

    all <- out[[1]]
    for (j in 2:length(out)) {
      all <- merge(all, out[[j]], param.error = FALSE)
    }
    sim <- all

  }


  # Post-Processing ---------------------------------------------------------

  # Save completed simulation data
  if (verbose == TRUE) {
    cat("\nSaving simulation data ...")
  }
  if (save.min == TRUE || save.max == TRUE) {
    savesim(sim, save.min = save.min, save.max = save.max, compress = compress)
  }

  # Remove CP data
  if (!is.null(control$save.int)) {
    if (verbose == TRUE) {
      cat("\nRemoving checkpoint data ... \n")
    }
    dirname <- paste0("data/sim", control$simno)
    if (file.exists(dirname) == TRUE) {
      unlink(dirname, recursive = TRUE)
    }
  }

  # Return object if not saved
  if (save.min == FALSE && save.max == FALSE) {
    return(sim)
  }

}
