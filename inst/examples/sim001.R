library(EpiModel.hpc)

nw <- network.initialize(n = 10000, directed = FALSE)
formation <- ~ edges
target.stats <- 5000
dissolution <- ~ offset(edges)
duration <- 50
coef.diss <- dissolution_coefs(dissolution, duration)

est <- netest(nw, formation, dissolution,
              target.stats, coef.diss)

param <- param.net(inf.prob = 0.01)
init <- init.net(i.num = 50)
control <- control.net(type = "SI", nsteps = 1000, verbose = FALSE,
                       par.type = "mpi", nsims = 100, ncores = 100)

sim <- netsim_parallel(est, param, init, control)

save(sim, file = "sim.rda")