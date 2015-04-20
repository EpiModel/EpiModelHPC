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
#' @param control Control settings, as an object of class
#'        \code{control.net}.
#' @param merge If \code{TRUE}, merge parallel simulations into one \code{netsim}
#'        object after simulation.
#'
#' @details
#' This is an experimental implementation of the \code{netsim} function
#' that runs model simulations in parallel, using the \code{doParallel} and
#' \code{doMPI} R packages.
#'
#' To run models in parallel on a single node, add an argument to the control
#' settings called \code{ncores} that is equal to the number of parallel cores
#' the simulations should be initiated on.
#'
#' Also available is an MPI option, called by adding a control argument
#' \code{par.type} set to \code{"mpi"}. This requires a local MPI installation on
#' the computing cluster, and the run of a bash script with an mpirun call
#' containing the R script with the \code{netsim_par} call.
#'
#' @keywords model
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
  } else {
    top.pkg <- required.pkgs
  }


  if (nsims == 1 | ncores == 1) {
    all <- netsim(x, param, init, control)
  } else {
    cluster.size <- min(nsims, ncores)
    if (par.type == "single") {
      doParallel::registerDoParallel(cluster.size)
    }
    if (par.type == "mpi") {
      cl <- doMPI::startMPIcluster(cluster.size)
      doMPI::registerDoMPI(cl)
    }

    out <- foreach(i = 1:nsims) %dopar% {
      library(top.pkg, character.only = TRUE)
      control$nsims = 1
      control$currsim = i
      netsim(x, param, init, control)
    }

    if (par.type == "mpi") {
      doMPI::closeCluster(cl)
    }

    if (merge == TRUE) {
      all <- out[[1]]
      for (i in 2:length(out)) {
        all <- merge(all, out[[i]])
      }
    } else {
      all <- out
    }
  }

  return(all)
}


#' @export
netsim_par_cp <- function(x,
                          param,
                          init,
                          control,
                          type,
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
        library(top.pkg, character.only = TRUE)
        control$nsims = 1
        control$currsim = i
        netsim(x, param, init, control)
      }
    }

    if (type == "cp") {
      xfn <- x
      out <- foreach(i = 1:nsims) %dopar% {
        library(top.pkg, character.only = TRUE)
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