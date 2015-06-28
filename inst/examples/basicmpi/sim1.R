library(EpiModelHPC)

nw <- network.initialize(n = 1000, directed = FALSE)
formation <- ~edges
target.stats <- 500
coef.diss <- dissolution_coefs(dissolution = ~offset(edges), duration = 50)
est <- netest(nw, formation, target.stats, coef.diss)

param <- param.net(inf.prob = 0.25, b.rate = 0.001,
                   ds.rate = 0.001, di.rate = 0.001)
init <- init.net(i.num = 50)
control <- control.net(type = "SI", nsteps = 100, verbose = FALSE,
                       par.type = "mpi", nsims = 25, ncores = 25)

sim <- netsim_par(est, param, init, control)
save(sim, file = "sim.rda")
