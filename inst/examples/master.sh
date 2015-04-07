#!/bin/bash

qsub -t 1-4 -v SIMNO=001 runsim.sh
qsub -t 1-4 -v SIMNO=002 runsim.sh