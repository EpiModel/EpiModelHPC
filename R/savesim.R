
#' @export
savesim <- function(sim, 
                    dataf = TRUE,
                    save.min = TRUE,
                    save.max = FALSE) {
  
  no <- sim$control$simno
  ctime <- format(Sys.time(), "%Y%m%d.%H%M")
  fn <- paste0("sim.n", no, ".", ctime, ".rda")
  if (dataf == TRUE) {
    fn <- paste0("data/", fn)
  }
  if (save.max == TRUE) {
    save(sim, file = fn)
  }
  
  if (save.min == TRUE) {
    sim$network <- NULL
    sim$stats$transmat <- NULL
    environment(sim$control$nwstats.formula) <- NULL
    sim$nwparam[[1]][c("formation", "coef.form", "coef.form.crude",
                       "dissolution", "coef.diss", "edapprox",
                       "constraints")] <- NULL
    fnm <- paste0("sim.n", no, ".", ctime, ".min.rda")
    if (dataf == TRUE) {
      fnm <- paste0("data/", fnm)
    }
    save(sim, file = fnm)
  }
  
}