
#' @export
netsim_hpc <- function(x, param, init, control, 
                       save.min = TRUE, save.max = FALSE) {
  
  # Check for CP data
  cpDir <- check_cp(simno = control$simno)
  type <- ifelse(is.null(cpDir), "new", "cp")
  if (type == "cp") {
    x <- cpDir
  }
  
  # Creates CP directory
  if (type == "new") {
    dirname <- paste0("data/sim", control$simno)
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
