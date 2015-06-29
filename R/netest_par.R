
#' @title Dynamic Network Model Estimation in Parallel
#'
#' @description Estimates statistical network models using the exponential
#'              random graph modeling (ERGM) framework with extensions for
#'              dynamic/temporal models (STERGM) in parallel.
#'
#' @inheritParams EpiModel::netest
#' @param ncores Number of processor cores to run multiple simulations
#'        on, using the \code{foreach} and \code{doParallel} implementations.
#'
#' @details
#' Fits multiple temporal ERGMs in paralell by wrapping the
#' \code{EpiModel::netest} function. Allows for either \code{coef.diss} or
#' \code{target.stats} to be a list, each element of which would be an object of
#' class \code{disscoef} or a numeric vector, respectively.
#'
#' @export
#'
#' @examples
#' \dontrun{
#' ## Multiple coef.diss elements
#' nw <- network.initialize(n = 100, directed = FALSE)
#' formation <- ~edges + concurrent
#' target.stats <- c(50, 25)
#' coef.diss <- list(dissolution_coefs(dissolution = ~offset(edges), duration = 10),
#'                   dissolution_coefs(dissolution = ~offset(edges), duration = 20))
#' est <- netest_par(nw, formation, target.stats, coef.diss, ncores = 2)
#' est
#'
#' ## Multiple target.stats elements
#' nw <- network.initialize(n = 100, directed = FALSE)
#' formation <- ~edges + concurrent
#' target.stats <- list(c(50, 25),
#'                      c(50, 10))
#' coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 10)
#' est <- netest_par(nw, formation, target.stats, coef.diss, ncores = 2)
#' est
#' }
#'
netest_par <- function(nw, formation, target.stats, coef.diss,
                       constraints, coef.form = NULL, edapprox = TRUE, output = "fit",
                       set.control.ergm, set.control.stergm, ncores) {

  modvar <- NULL
  nmods <- NULL
  if (class(target.stats) == "list" & length(target.stats) > 1) {
    modvar <- "ts"
    nmods <- length(target.stats)
  } else if (class(coef.diss) == "list" & length(coef.diss) > 1) {
    modvar <- "cd"
    nmods <- length(coef.diss)
  } else {
    stop("Either target.stats or coef.diss must be a list containing more than 1 element",
         call. = FALSE)
  }
  if (class(target.stats) == "list" & class(coef.diss) == "list") {
    stop("Only 1 of target.stats or coef.diss is allowed to have multiple inputs",
         call. = FALSE)
  }

  if (missing(ncores)) {
    stop("Supply ncores parameter", call. = FALSE)
  }

  maxcores <- parallel::detectCores()
  if (ncores > maxcores) {
    ncores <- maxcores
    message("Setting ncores to maximum cores on current machine")
  }

  if (missing(constraints)) {
    constraints	<- ~.
  }
  if (missing(set.control.stergm)) {
    set.control.stergm <- control.stergm(EGMME.MCMC.burnin.min = 1e5)
  }
  if (missing(set.control.ergm)) {
    set.control.ergm <- control.ergm(MCMC.burnin = 1e5, MCMLE.maxit = 200)
  }

  cluster.size <- min(nmods, ncores)
  registerDoParallel(cluster.size)
  i <- NULL

  if (modvar == "ts") {
    out <- foreach(i = 1:nmods) %dopar% {
      netest(nw, formation, target.stats[[i]], coef.diss,
             constraints, coef.form = NULL, edapprox = TRUE, output = "fit",
             set.control.ergm, set.control.stergm, nonconv.error = TRUE, verbose = FALSE)
    }
  }
  if (modvar == "cd") {
    out <- foreach(i = 1:nmods) %dopar% {
      netest(nw, formation, target.stats, coef.diss[[i]],
             constraints, coef.form = NULL, edapprox = TRUE, output = "fit",
             set.control.ergm, set.control.stergm, nonconv.error = TRUE, verbose = FALSE)
    }
  }

  return(out)
}
