#!/bin/sh

. ~/.profile.perso

rm -f FSH2.out FSH2.log

# Use JEFF-3.1.1 data and 12 cores
sbatch --mem=12000 -c 12 --wrap="/soft_snc/scripts/cas5 FSH2.inp -S 4G -N /soft_snc/CASMO5/library/j311.200.586.bin"

# TIF generation uses much more memory
#sbatch --mem=250000 -c 12 --wrap="/soft_snc/scripts/cas5 FSH2.inp -S 250G -N /soft_snc/CASMO5/library/j311.200.586.bin"