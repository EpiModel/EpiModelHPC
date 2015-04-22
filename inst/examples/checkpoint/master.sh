#!/bin/bash

# Use of the backfill queue is specified on our system with the -q bf
qsub -q bf -t 1-7 -v SIMNO=1 runsim.sh