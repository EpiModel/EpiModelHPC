
#' @export
check_cp <- function(simno) {
  
  out <- FALSE
  goodFile <- FALSE
  
  dirname.top <- paste0("data/sim", simno)
  dirname.bot <- paste0("data/sim", gsub(".ext[1-9]", "", simno))
  
  if (file.exists(dirname.top) & file.exists(dirname.bot)) {
    dirname <- dirname.top
  } else if (!file.exists(dirname.top) & file.exists(dirname.bot)) {
    dirname <- dirname.bot
  } else {
    return(NULL)
  }
  
  fn <- list.files(path = dirname, pattern = "*.cp.rda", full.names = TRUE)
  if (length(fn) == 0) {
    dirname <- dirname.bot
    fn <- list.files(path = dirname, pattern = "*.cp.rda", full.names = TRUE)
  }
  if (length(fn) > 0) {
    a <- unname(sapply(fn, function(x) file.info(x)$size))
    goodFile <- ifelse(all(a > (mean(a) - 1000000)), TRUE, FALSE)
  }
  
  if (goodFile == TRUE) {
    return(dirname)
  } else {
    return(NULL)
  }
  
}



