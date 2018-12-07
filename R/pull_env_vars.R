
#' @title Pull Standard Environmental Variables in Slurm Jobs
#'
#' @description Pulls four environmental variables commonly used in Slurm jobs
#'              directly into the Global Environment of an R Script.
#'
#' @export
#'
#' @examples
#' Sys.setenv("SIMNO"=1000)
#' Sys.setenv("SLURM_ARRAY_TASK_ID"=4)
#' Sys.setenv("SLURM_NTASKS_PER_NODE"=4)
#' Sys.setenv("SLURM_ARRAY_TASK_MAX"=10)
#' 
#' ls()
#' pull_env_vars()
#' ls()
#' 
pull_env_vars <- function() {

  simno <- as.numeric(Sys.getenv("SIMNO"))
  if (!is.na(simno)) {
    assign("simno", simno, pos = 1)
  } else {
    assign("simno", 1L, pos = 1)
  }
  jobno <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID"))
  if (!is.na(jobno)) {
    assign("jobno", jobno, pos = 1)
  } else {
    assign("jobno", 1L, pos = 1)
  }
  if (!is.na(simno) & !is.na(jobno)) {
    fsimno <- paste(simno, jobno, sep = ".")
    assign("fsimno", fsimno, pos = 1)
  } else {
    assign("fsimno", 1L, pos = 1)
  }

  ncores <- as.numeric(Sys.getenv("SLURM_NTASKS_PER_NODE"))
  if (!is.na(ncores)) {
    assign("ncores", ncores, pos = 1)
  } else {
    assign("ncores", 1L, pos = 1)
  }
  
  njobs <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_MAX"))
  if (!is.na(njobs)) {
    assign("njobs", njobs, pos = 1)
  } else {
    assign("njobs", 1L, pos = 1)
  }
}
