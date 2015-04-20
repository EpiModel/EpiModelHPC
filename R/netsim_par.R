#' @title Stochastic Network Models in Parallel
#'
#' @description Simulates stochastic network epidemic models for infectious
#'              disease in parallel.
#'
#' @param x Fitted network model object, as an object of class \code{netest}.
#'        Alternatively, if restarting a previous simulation, may be an object of
#'        class \code{netsim}.
#' @param param Model parameters, as an object of class \code{param.net}.
#' @param init Initial conditions, as an object of class \code{init.net}.
#' @param control Control settings, as an object of class \code{control.net}.
#' @param type Either \code{"new"} if running a new or restarted \code{netsim} 
#'        simulation or \code{"cp"} if a checkpoint run is restarted.
#' @param merge If \code{TRUE}, merge parallel simulations into one \code{netsim}
#'        object after simulation.
#' @param required.pkgs A character vector of R packages that must be loaded
#'        for the simulation, necessary for MPI-based parallel simulations. If
#'        \code{NULL}, this will load \code{EpiModel} and the first package package
#'        listed in the "other attached packages" section of \code{sessionInfo()}.
#'
#' @details
#' This function facilitates running stochastic network models in parallel, with
#' the intended use on linux-based high-performance computing systems. Parallel
#' runs may be conducted either with multi-core, single-node systems or multiple
#' node systems running MPI.
#' 
#' To run models in parallel using this function, it is necessary to add two 
#' parameters to the control settings specified in \code{control.net}. A parameter
#' called \code{ncores} should be added that specifies the number of parallel
#' cores the simulations should use. Second, a \code{par.type} parameter should
#' equal either \code{"single"} to run on a single-node or \code{"mpi"} to run
#' on multiple nodes using MPI. 
#' 
#' Running models in an MPI framework depends on correctly installed MPI 
#' applications, such as Open MPI. One way to test this is by installing and 
#' loading the \code{Rmpi} package. In fact, \code{netsim_par} uses the functionality
#' of the \code{doMPI} package, which depends on \code{Rmpi}.
#' 
#' The \code{type} argument here specifies whether the parallel simulations should
#' load checkpointed data. Checkpointing is when simulation data are periodically
#' saved in the case that a simulation job is cancelled and must be rerun from
#' some intermediate time step. This parameter is typically set automatically
#' by the \code{netsim_hpc} function, so would not need to be changed manually.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' nw <- network.initialize(n = 1000, directed = FALSE)
#' formation <- ~ edges
#' target.stats <- 500
#' dissolution <- ~ offset(edges)
#' duration <- 50
#' coef.diss <- dissolution_coefs(dissolution, duration)
#'
#' est <- netest(nw,
#'               formation,
#'               dissolution,
#'               target.stats,
#'               coef.diss,
#'               verbose = FALSE)
#'
#' param <- param.net(inf.prob = 0.25)
#' init <- init.net(i.num = 50)
#'
#' # Runs multicore-type parallelization on single node
#' control <- control.net(type = "SI", nsteps = 100, verbose = FALSE,
#'                        par.type = "single", nsims = 4, ncores = 4)
#'
#' # Note: one should do this function call in batch mode
#' sims <- netsim_par(est, param, init, control)
#'
#' # Runs parallelization across nodes using MPI
#' control <- control.net(type = "SI", nsteps = 100, verbose = FALSE,
#'                        par.type = "mpi", nsims = 4, ncores = 4)
#'
#' # This would be included in the script file called by mpirun
#' sims <- netsim_par(est, param, init, control)
#'
#' }
#'
netsim_par <- function(x,
                       param,
                       init,
                       control,
                       type = "new",
                       merge = TRUE,
                       required.pkgs = NULL) {

  nsims <- control$nsims
  ncores <- control$ncores
  par.type <- control$par.type
  if (is.null(par.type)) {
    par.type <- "single"
  }

  if (is.null(required.pkgs)) {
    top.pkg <- sessionInfo()$otherPkgs[[1]]$Package
    if (("EpiModel" %in% top.pkg) == FALSE) {
      top.pkg <- c(top.pkg, "EpiModel")
    }
  } else {
    top.pkg <- required.pkgs
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
        for (j in seq_along(top.pkg)) {
          library(top.pkg[j], character.only = TRUE)
        }
        control$nsims = 1
        control$currsim = i
        netsim(x, param, init, control)
      }
    }

    if (type == "cp") {
      xfn <- x
      out <- foreach(i = 1:nsims) %dopar% {
        for (j in seq_along(top.pkg)) {
          library(top.pkg[j], character.only = TRUE)
        }
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

  }

  return(all)
}