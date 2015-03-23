
.onAttach <- function(...) {

  if (!interactive()) return()

  vcurr <- utils::packageVersion("EpiModel.hpc")

  msg <- c("\n",
           paste0("Loading EpiModel.hpc ", vcurr))

  packageStartupMessage(msg)
}
