
supressPackageStartupMessages(library(EpiModel.hpc))

nw <- network.initialize(n = 1000, directed = FALSE)
formation <- ~ edges
target.stats <- 500
dissolution <- ~ offset(edges)
duration <- 50
coef.diss <- dissolution_coefs(dissolution, duration)

est <- netest(nw,
              formation,
              dissolution,
              target.stats,
              coef.diss,
              verbose = FALSE)
save(est, file = "est.rda")

param <- param.net(inf.prob = 0.25, b.rate = 0.001, ds.rate = 0.001, di.rate = 0.001)
init <- init.net(i.num = 50)

# Runs multicore-type parallelization on single node
control <- control.net(type = "SI", nsteps = 250, verbose = FALSE,
                       par.type = "single", nsims = 10, ncores = 10,
                       save.int = 25)

# sims <- netsim_par(est, param, init, control)
# savesim(sims)

netsim_hpc("est.rda", param, init, control)
