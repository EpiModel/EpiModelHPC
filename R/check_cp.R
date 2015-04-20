
#' @export
check_cp <- function(simno) {
  
  out <- FALSE
  goodFile <- FALSE
  
  dirname <- paste0("data/sim", simno)
  
  if (file.exists(dirname) == FALSE) {
    return(NULL)
  }
  
  fn <- list.files(path = dirname, pattern = "*.cp.rda", full.names = TRUE)
  if (length(fn) > 0) {
    a <- unname(sapply(fn, function(x) file.info(x)$size))
    goodFile <- ifelse(all(a > (mean(a) - mean(a) * 0.5)), TRUE, FALSE)
  }
  
  if (goodFile == TRUE) {
    return(dirname)
  } else {
    return(NULL)
  }
  
}