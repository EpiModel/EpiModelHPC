
#' @export
save_cpdata <- function(dat, at) {

  if (!is.null(dat$control$save.int) && at %% dat$control$save.int == 0) {
    currsim <- dat$control$currsim
    simno <- dat$control$simno
    fn <- paste0("data/sim", simno, "/sim", currsim, ".cp.rda")
    x <- dat
    save(x, file = fn)
  }
  
}