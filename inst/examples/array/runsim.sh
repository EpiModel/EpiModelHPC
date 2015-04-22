#!/bin/bash

### Specs
#PBS -N sim$SIMNO
#PBS -l nodes=1:ppn=16,mem=44gb,feature=16core,walltime=06:00:00
#PBS -o <standard output directory>
#PBS -e <standard error directory>
#PBS -d <data directory>
#PBS -m ae
#PBS -M <email address for notifications>

### Modules
module load r_3.1.1

### App
R CMD BATCH --vanilla -$SIMNO.${PBS_ARRAYID} sim$SIMNO.R sim$SIMNO.${PBS_ARRAYID}.Rout