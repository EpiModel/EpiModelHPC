
#' @title Source All Files in a Directory
#'
#' @description Loops over all files in a directory to source them to the Global Environment.
#'
#' @param path Directory of files to source.
#' @param trace Print names of sourced files to console.
#' @param ... Additional arguments passed to \code{source}.
#'
#' @export
#'
sourceDir <- function(path, trace = TRUE, ...) {
  for (nm in list.files(path, pattern = "\\.[RrSsQq]$")) {
    if(trace) cat(nm,":")           
    source(file.path(path, nm), ...)
    if(trace) cat("\n")
  }
}