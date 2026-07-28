# EpiModel Extensions for High-Performance Computing

Extension package to EpiModel to run large-scale stochastic network
models on modern high-performance computing systems. Provides
scenario-based batch simulation, helpers for building 'slurmworkflow'
job workflows and 'swfcalib' calibrations, cluster configuration
presets, and shell tooling for detecting and recovering degenerate SLURM
tasks.

## Details

EpiModel provides tools for the mathematical modeling of infectious
diseases. Supported model classes include stochastic network models,
which rely on the statistical framework of exponential-family random
graph models (ERGMs) that evolve over time. This allows for modeling of
disease-related contacts with duration, such as ongoing sexual
partnerships.

The level of statistical complexity of these models, based in
Markov-chain Monte Carlo (MCMC) simulation, results in computationally
intensive simulation processes. The goal of EpiModelHPC is to provide a
standardized framework for extending EpiModel to run on modern
high-performance computing (HPC) systems.

## References

The main website for EpiModel is at <https://www.epimodel.org/>. The
source code for this extension package is hosted on GitHub at
<https://github.com/EpiModel/EpiModelHPC>. Bug reports and feature
requests may be filed there.

## See also

Useful links:

- <https://www.epimodel.org/>

- <https://epimodel.github.io/EpiModelHPC/>

- Report bugs at <https://github.com/EpiModel/EpiModelHPC/issues>

## Author

**Maintainer**: Samuel Jenness <samuel.m.jenness@emory.edu>

Authors:

- Samuel Jenness <samuel.m.jenness@emory.edu>
