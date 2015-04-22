library(EpiModel.hpc)

nw <- network.initialize(n = 1000, directed = FALSE)
formation <- ~ edges
target.stats <- 500
dissolution <- ~ offset(edges)
duration <- 50
coef.diss <- dissolution_coefs(dissolution, duration)
est <- netest(nw, formation, dissolution,
              target.stats, coef.diss)

param <- param.net(inf.prob = 0.09)
init <- init.net(i.num = 50)
control <- control.net(type = "SI", nsteps = 250, verbose = FALSE,
                       par.type = "single", nsims = 10, ncores = 10)

sim <- netsim_par(est, param, init, control)
save(sim, file = "sim.rda")