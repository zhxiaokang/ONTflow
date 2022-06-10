#!/bin/bash

# Job name:
#SBATCH --job-name=NanoGF
#
# Project:
#SBATCH --account=p19_radium
#
# Wall clock limit:
#SBATCH --time=1:00:00
#
# Scratch size (working directory)
#SBATCH --partition=normal
#
#SBATCH --nodes=1
# Number of cores to be used on one single node (assign 12 since there are often 12 samples/barcodes from one run, otherwise modify this number accordingly)
#SBATCH --cpus-per-task=12
# Max memory usage: (BWA requires lots of mem for aligning reads to genome)
#SBATCH --mem-per-cpu=20G
#

module load python3.gnu/3.7.0 
module load snakemake/6.6.1-foss-2021a
module unload SciPy-bundle
module load bwa/0.7.17
module load samtools/1.8
module load Salmon/0.12.0-foss-2018b
module load R/3.5.0

### pycoQC
export PATH=~/.local/bin:$PATH
### guppy
export PATH=/cluster/projects/p19/Software/ont-guppy-cpu/bin:$PATH
### minimap2
export PATH=/cluster/projects/p19/Software/minimap2:$PATH
### LongGF
export PATH=/cluster/projects/p19/Software/nanogf/bin:$PATH

# use 12 cores since there are often 12 samples/barcodes from one run, otherwise modify this number accordingly
snakemake --cores 12 -s nanopore_main.smk
