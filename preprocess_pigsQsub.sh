#!/bin/bash
module load Boost/1.67.0-foss-2018b
module load FSL/5.0.11-foss-2018b-Python-3.6.6
module load ANTs/2.3.1-foss-2018b-Python-3.6.6



source ${FSLDIR}/etc/fslconf/fsl.sh

### job parameters
#$ -N PigPower
#$ -o logs/
#$ -e logs/
#$ -j y
#$ -cwd
#$ -q short.qc
#$ -pe shmem 3
#$ -t 1-2


SUBJECT_LIST=./params.txt


params=$(sed -n "${SGE_TASK_ID}p" $SUBJECT_LIST)

./pre_clean.sh ${params}
