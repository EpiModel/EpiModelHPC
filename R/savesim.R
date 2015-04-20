
#' @export
savesim <- function(sim, 
                    dataf = TRUE,
                    save.min = TRUE,
                    save.max = TRUE) {
  
  if (!is.null(sim$control$simno)) {
    no <- sim$control$simno
  } else {
    no <- 1
  }
  
  ctime <- format(Sys.time(), "%Y%m%d.%H%M")
  fn <- paste0("sim.n", no, ".", ctime, ".rda")
  
  if (dataf == TRUE) {
    if (file.exists("data/") == FALSE) {
      dir.create("data/")
    }
    fn <- paste0("data/", fn)
  }
  if (save.max == TRUE) {
    save(sim, file = fn)
  }
  
  if (save.min == TRUE) {
    sim$network <- NULL
    sim$stats$transmat <- NULL
    environment(sim$control$nwstats.formula) <- NULL
    for (i in seq_along(sim$nwparam)) {
      sim$nwparam[[i]][c("formation", "coef.form", "coef.form.crude",
                         "dissolution", "coef.diss", "edapprox",
                         "constraints")] <- NULL
    }
    fnm <- paste0("sim.n", no, ".", ctime, ".min.rda")
    if (dataf == TRUE) {
      fnm <- paste0("data/", fnm)
    }
    save(sim, file = fnm)
  }
  
}