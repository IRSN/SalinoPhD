#!/bin/bash

sss2=/soft_snc/SERPENT2/2.1.32/sss2
if ! command -v $sss2 &> /dev/null
then
    echo "Serpent 2 could not be found in $sss2"
    exit 1
fi

for input in UOX*.sss2
do
    echo $input
    sbatch -c 10 --mem=8G --partition="seq,dev,par_IB" --wrap="srun $sss2 -omp 10 $input"
done
