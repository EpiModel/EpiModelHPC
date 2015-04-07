
suppressPackageStartupMessages(library(EpiModelHIV))

args <- commandArgs(FALSE)
args <- args[length(args)]
fsimno <- sub("-","",args)
print(fsimno)

param <- param.hiv()
init <- init.hiv(i.prev.male = 0.01, i.prev.feml = 0.01)
control <- control.hiv(simno = fsimno,
                       nsteps = 52*100,
                       nsims = 15,
                       ncores = 15)

runsimHPC("est/est.rda", param, init, control)