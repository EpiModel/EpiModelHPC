#!/bin/bash

qsub -v SIMNO=1 runsim.sh
qsub -v SIMNO=2 runsim.sh
qsub -v SIMNO=3 runsim.sh