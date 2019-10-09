
# testing no VARS passed to sbatch_master

sbatch_master(vars = NULL,
              working.dir = "inst/",
              master.file = "master.sh",
              build.runsim = TRUE, 
              param.file = "params.csv",
              param.tag = "Calibrate",
              append = FALSE,
              simno.start = 100,
              ckpt = TRUE,
              nsims = 100,
              ncores = 16,
              mem = "55G")
