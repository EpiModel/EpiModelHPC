library(EpiModelHPC)

args <- commandArgs(FALSE)
args <- args[length(args)]
fsimno <- sub("-", "", args)
print(fsimno)

nw <- network.initialize(n = 1000, directed = FALSE)
formation <- ~ edges
target.stats <- 500
coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 50)
est <- netest(nw, formation, target.stats, coef.diss)
save(est, file = "est.rda")

param <- param.net(inf.prob = 0.01)
init <- init.net(i.num = 50)
control <- control.net(simno = fsimno, save.int = 10,
                       type = "SI", nsteps = 250, verbose = FALSE,
                       par.type = "single", nsims = 10, ncores = 10)

netsim_hpc("est.rda", param, init, control)
