
#' @export
save_cpdata <- function(dat, at) {

  if (!is.null(dat$control$save.int)) {
    if (!is.null(dat$control$ncores) && dat$control$ncores > 1) {
      if (at %% dat$control$save.int == 0) {
        currsim <- dat$control$currsim
        simno <- dat$control$simno
        fn <- paste0("data/sim", simno, "/sim", currsim, ".cp.rda")
        x <- dat
        save(x, file = fn)
      }
    } else {
      if (at %% dat$control$save.int == 0) {
        fn <- paste0("sim.cp.rda")
        x <- dat
        save(x, file = fn)
      }
    }
  }
  
}