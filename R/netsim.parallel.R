#' @title Stochastic Network Models in Parallel
#'
#' @description Simulates stochastic network epidemic models for infectious
#'              disease in parallel.
#'
#' @inheritParams netsim
#' @param merge If \code{TRUE}, merge parallel simulations into one \code{netsim}
#'        object after simulation.
#'
#' @details
#' This is an experimental implementation of the \code{\link{netsim}} function
#' that runs model simulations in parallel, using the \code{doParallel} and
#' \code{doMPI} R packages.
#'
#' To run models in parallel on a single node, add an argument to the control
#' settings called \code{ncores} that is equal to the number of parallel cores
#' the simulations should be initiated on. Use \code{\link{detectCores}} to find
#' the maximum on a node.
#'
#' Also available is an MPI option, called by adding a control argument
#' \code{par.type} set to \code{"mpi"}. This requires a local MPI installation on
#' the computing cluster, and the run of a bash script with an mpirun call
#' containing the R script with the \code{netsim_parallel} call.
#'
#' The default single-node method has been tested on Linux, Mac, and Windows
#' platforms. The MPI method is only intended to be run on Linux-based clusters
#' with an MPI installation, although it may be possible to run on Mac or Windows.
#' Both methods are best-suited to be run in non-interactive batch mode.
#'
#' Note that this function may be folded into \code{\link{netsim}} and deprecated
#' in the future.
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
#' sims <- netsim_parallel(est, param, init, control)
#'
#' # Runs parallelization across nodes using MPI
#' control <- control.net(type = "SI", nsteps = 100, verbose = FALSE,
#'                        par.type = "mpi", nsims = 4, ncores = 4)
#'
#' # This would be included in the script file called by mpirun
#' sims <- netsim_parallel(est, param, init, control)
#'
#' }
#'
netsim_parallel <- function(x,
                            param,
                            init,
                            control,
                            merge = TRUE) {
  
  nsims <- control$nsims
  ncores <- control$ncores
  par.type <- control$par.type
  if (is.null(par.type)) {
    par.type <- "single"
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
      require(EpiModel)
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