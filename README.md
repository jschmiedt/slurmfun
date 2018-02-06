# slurmfun
MATLAB tools for submitting jobs into SLURM

This repository provides tools for submitting MATLAB jobs into the SLURM (Simple Linux Utility for Resource Management) scheduling system. The MATLAB function `slurmfun` can be used similar to the MATLAB function `cellfun`, i.e. it will apply a user-defined function to all elements of a cell array and return a cell array of output arguments. Each function all will be submitted as a separate job into the schedulder. See also `help slurmfun` for details.

## Cluster Environment
So far, `slurmfun` has only been used in the cluster environment of the Ernst Strungmann Institute for Neuroscience using

* SLURM 15.08
* MATLAB 2014a until 2016b
* Debian 8.5

The default paths for log files and the SLURM working directory (`'slurmWorkingDirectory'`, `availableToolboxes` in `slurmfun.m`),  will have to be adjusted for the specific cluster environment.

