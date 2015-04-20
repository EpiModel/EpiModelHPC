
#' @title Stochastic Network Models on High-Performance Computing Systems
#'
#' @description Simulates stochastic network epidemic models for infectious
#'              disease in parallel.
#'
#' @param x Character vector containing the file location and name of an Rdata
#'        file where an object of class \code{netest} is stored. Alternatively,
#'        if restarting a previous simulation, this may be a file name for an
#'        object of class \code{netsim}.
#' @param param Model parameters, as an object of class \code{param.net}.
#' @param init Initial conditions, as an object of class \code{init.net}.
#' @param control Control settings, as an object of class \code{control.net}.
#' @param save.min Argument passed to \code{\link{savesim}}.
#' @param save.max Argument passed to \code{\link{savesim}}.
#'
#' @details
#' This function provides a systematic method to running stochastic network
#' models in parallel on high-performance computing systems. The function wraps
#' \code{\link{netsim_par}} that establishes the parallelization of the
#' underlying sequential simulations run in \code{netsim}.
#'
#' The main purpose of using \code{netsim_hpc} is for a standardized checkpointing
#' method. Checkpointing is defined as incrementally saving simulation data for
#' the purpose of reloading it if a simulation job is canceled and restarted. If
#' checkpointing is not needed, users are advised to run their models directly
#' with the \code{\link{netsim_par}} function.
#'
#' This function performs the following tasks:
#' \enumerate{
#'   \item Check for the existence of checkpointed data, using the
#'         \code{\link{check_cp}} function. If CP data are available, a
#'         checkpointed model will be run, else a new model will be run.
#'   \item Create a checkpoint directory if one does not exist at
#'         "data/sim<simno>".
#'   \item Set a save interval of 100 time steps if one does not already exist
#'         on the control settings.
#'   \item Resets the initialize module function to \code{\link{initialize.cp}}
#'         if in checkpoint state.
#'   \item Run the simulation, either new or checkpointed, with a call to
#'         \code{\link{netsim_par}}.
#'   \item Save the completed simulation data, using the functionality of
#'         \code{\link{savesim}}.
#'   \item Remove any files in the "verb/" subdirectory, which is typically
#'         used to store incremental model tracking text files.
#'   \item Remove the checkpointed data and file directory created in step 1.
#' }
#'
#' Note that the \code{x} argument must specify a \strong{file name} in a
#' character string, rather than a \code{netest} or \code{netsim} class object
#' directly. This is mainly for efficency purposes in running the models in
#' parallel.
#'
#' @export
netsim_hpc <- function(x, param, init, control,
                       save.min = TRUE, save.max = FALSE) {

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

  # Creates CP directory
  if (type == "new") {
    dirname <- paste0("data/sim", control$simno)
    if (file.exists("data/") == FALSE) {
      dir.create("data/")
    }
    if (file.exists(dirname) == FALSE) {
      dir.create(dirname)
    }
  }

  # Set CP save interval if missing
  if (is.null(control$save.int)) {
    cat("Setting save.int on control settings at 100 time steps ... \n")
    control$save.int <- 100
  }

  # Store save CP on control settings
  if (is.null(control$savedata.FUN)) {
    control$savedata.FUN <- save_cpdata
    control$bi.mods <- c(control$bi.mods, "savedata.FUN")
  }

  # Replace initialization module if CP
  if (type == "cp") {
    control$initialize.FUN <- initialize.cp
  }

  # Run a new simulation
  if (type == "new") {
    cat("Running new simulation from netest object ... \n")
    load(x)
    if ("sim" %in% ls()) {
      est <- sim
    }
    sim <- netsim_par(est, param, init, control, type = "new")
  }

  # Run a checkpointed simulation
  if (type == "cp") {
    cat("Restarting simulation from checkpoint data ... \n")
    sim <- netsim_par(x, param, init, control, type = "cp")
  }

  # Save completed simulation data
  cat("Simulation complete. Saving data ... \n")
  savesim(sim, save.min = save.min, save.max = save.max)

  # Remove verbose txt files if present
  fn <- list.files("verb/", pattern = paste0("sim", control$simno, ".*"),
                   full.names = TRUE)
  if (length(fn) > 0) {
    cat("Removing verbose txt files ... \n ")
    unlink(fn)
  }

  # Remove CP data
  if (!is.null(control$save.int)) {
    dirname <- paste0("data/sim", control$simno)
    if (file.exists(dirname) == TRUE) {
      unlink(dirname, recursive = TRUE)
    }
  }

}
