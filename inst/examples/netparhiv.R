
nethivpar <- function(x, type, param, init, control, merge = TRUE) {
  
  nsims <- control$nsims
  ncores <- control$ncores
  par.type <- control$par.type
  if (is.null(par.type)) {
    par.type <- "single"
  }
  
  if (nsims == 1 | ncores == 1) {
    out <- netsim(x, param, init, control)
  } else {
    suppressPackageStartupMessages(require(foreach))
    cluster.size <- min(nsims, ncores)
    if (par.type == "single") {
      suppressPackageStartupMessages(require(doParallel))
      registerDoParallel(cluster.size)
    }
    if (par.type == "mpi") {
      suppressPackageStartupMessages(require(doMPI))
      cl <- startMPIcluster(cluster.size)
      registerDoMPI(cl)
    }
    
    if (!is.null(control$save.int)) {
      dirname <- paste0("data/sim", control$simno)
      if (file.exists(dirname) == FALSE) {
        dir.create(dirname)
      }
    }
    
    if (type == "new") {
      out <- foreach(i = 1:nsims) %dopar% {
        require(EpiModelHIV)
        control$nsims = 1
        control$currsim = i
        netsim(x, param, init, control)
      }
    }
    
    if (type == "cp") {
      xfn <- x
      out <- foreach(i = 1:nsims) %dopar% {
        require(EpiModelHIV)
        control$nsims = 1
        control$currsim = i
        fn <- list.files(xfn, pattern = paste0("sim", i, ".cp.rda"), full.names = TRUE)
        load(fn)
        if (class(x$epi$num) == "data.frame") {
          ltstep <- nrow(x$epi$num)
          if (ltstep == control$nsteps) {
            control$start <- ltstep
          } else {
            control$start <- ltstep + 1
          }
        }
        if (class(x$epi$num) == "integer") {
          ltstep <- length(x$epi$num)
          if (ltstep == control$nsteps) {
            control$start <- ltstep
          } else {
            control$start <- ltstep + 1
          }
        }
        netsim(x, param, init, control)
      }
    } 
    
    if (par.type == "mpi") {
      doMPI::closeCluster(cl)
      mpi.finalize()
    }
    
    if (merge == TRUE) {
      all <- out[[1]]
      for (i in 2:length(out)) {
        all <- merge(all, out[[i]], param.error = FALSE)
      }
    } else {
      all <- out
    }
    
    if (!is.null(control$save.int) & control$keep.cpdata == FALSE) {
      dirname <- paste0("data/sim", control$simno)
      if (file.exists(dirname) == TRUE) {
        unlink(dirname, recursive = TRUE)
      }
    }
  }
  
  return(all)
}