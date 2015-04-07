#' @export
runsimHPC <- function(x, param, init, control, save.max = FALSE) {
  
  onHyak <- ifelse(Sys.info()[4] %in%
                     c(paste0("n", 1:14), "union", "libra"),
                   FALSE, TRUE)
  cpDir <- check_cp(simno = control$simno)
  type <- ifelse(is.null(cpDir), "new", "cp")
  if (type == "cp") {
    x <- cpDir
  }
  
  if (is.null(control$save.int) & onHyak == TRUE) {
    cat("Setting save.int on control ... \n")
    control$save.int <- 200
  }
  
  if (type == "new") {
    cat("Running new simulation from netest object ... \n")
    load(x)
    if ("sim" %in% ls()) est <- sim
    sim <- nethivpar(est, type = "new", param, init, control)
  }
  
  if (type == "cp") {
    cat("Restarting simulation from checkpoint data ... \n")
    sim <- nethivpar(x, type = "cp", param, init, control)
  }
  
  cat("Simulation complete. Saving data ... \n")
  if (onHyak == TRUE) {
    savesim(sim, send.email = FALSE, save.max = save.max)
  } else {
    savesim(sim, send.email = TRUE, save.max = save.max)
  }
  
  fn <- list.files("verb/",
                   pattern = paste0("sim", control$simno, ".*"),
                   full.names = TRUE)
  if (length(fn) > 0) {
    cat("Removing verbose txt files ... \n ")
    unlink(fn)
  }
  
}