#!/bin/bash

### User specs
#PBS -N sim$SIMNO
#PBS -l nodes=1:ppn=16,mem=44gb,feature=16core,walltime=06:00:00
#PBS -o /gscratch/csde/sjenness/out/sout
#PBS -e /gscratch/csde/sjenness/out/serr
#PBS -d /gscratch/csde/sjenness
#PBS -m ae
#PBS -M sjenness@u.washington.edu

### Standard specs
HYAK_NPE=$(wc -l < $PBS_NODEFILE)
HYAK_NNODES=$(uniq $PBS_NODEFILE | wc -l )
HYAK_TPN=$((HYAK_NPE/HYAK_NNODES))
NODEMEM=`grep MemTotal /proc/meminfo | awk '{print $2}'`
NODEFREE=$((NODEMEM-2097152))
MEMPERTASK=$((NODEFREE/HYAK_TPN))
ulimit -v $MEMPERTASK
export MX_RCACHE=0

### Modules
module load r_3.1.1 icc_14.0.3-ompi_1.8.3

### App
mpirun -np 1 R --slave CMD BATCH --vanilla -$SIMNO.${PBS_ARRAYID} sim$SIMNO.R out/sim$SIMNO.${PBS_ARRAYID}.Rout
