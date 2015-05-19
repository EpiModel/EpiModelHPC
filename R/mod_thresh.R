
#' @title Find Best Fitting Modeling on Time-Series Equilibrium and Epidemic
#'        Prevalence
#'
#' @description Calculates whether a set of models have met two thresholds for
#'              dynamic model fit: stable equilibrium prevalence and fit to an
#'              observed disease prevalence.
#'
#' @param dir File directory in which the simulations are stored.
#' @param job.nos Set of simulation job numbers, as an integer, for fit calculations
#'        to be run. If \code{"all"}, then will use all simulation data within the
#'        specified directory.
#' @param nsteps For the equilibrium threshold calculation, number of time steps
#'        from the end of the simulation over which to calculate equilbrium,
#'        following the methods in \code{calc_eql} in the EpiModel package.
#' @param threshold Threshold level at which the two decision rules will be
#'        made
#' @param prev Observed disease prevalence to which simulation prevalence should
#'        be fit. If \code{NULL}, then only perform the equilibrium decision rule.
#'
#' @export
#'
#' @examples
#' feql <- mod_fit(dir = "data", prev = 0.0475)
#'
mod_fit <- function(dir,
                    job.nos = "all",
                    nsteps = 1000,
                    threshold = 0.001,
                    prev = NULL) {

  fn <- list.files(dir)

  jids <- as.numeric(gsub("n", "", unname(sapply(fn, function(x)
                                           strsplit(x, split = "[.]")[[1]][2]))))

  df <- data.frame(fn, jids)
  if (is.numeric(job.nos)) {
    df <- df[df$jids %in% job.nos, ]
  }
  ujids <- sort(unique(df$jids))

  for (i in seq_along(ujids)) {
    sdat <- merge_simfiles(simno = ujids[i], indir = dir, verbose = FALSE)
    ce <- calc_eql(sdat, nsteps = nsteps, threshold = threshold, invisible = TRUE)
    if (i == 1) {
      odf <- data.frame(job = ujids[i],
                        nsims = sdat$control$nsims, as.data.frame(ce))
    } else {
      odf <- rbind(odf,
                   data.frame(job = ujids[i],
                              nsims = sdat$control$nsims, as.data.frame(ce)))
    }
  }
  if (!is.null(prev)) {
   odf$epidiff <- abs(prev - odf$endprev)
   odf$epithresh <- odf$epidiff < threshold
   odf$allthresh <- odf$thresh == TRUE & odf$epithresh
   goodIds <- odf$job[odf$allthresh == TRUE]
  } else {
   goodIds <- odf$job[odf$thresh == TRUE]
  }

  print(odf, print.gap = 3)
  return(goodIds)
  }
