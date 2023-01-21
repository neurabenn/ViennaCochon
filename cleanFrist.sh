#!/bin/bash 

subj=$1

python3 pyclean.py $subj
cd $subj

fslmaths prefiltered_func_data_mcf.nii.gz -Tmean mean_func.nii.gz 

fslmaths prefiltered_func_data_PyCleanFSL.GLM.func.nii -add mean_func.nii.gz prefiltered_func_data_PyCleanFSL.GLM.func.nii.gz 
rm prefiltered_func_data_PyCleanFSL.GLM.func.nii

fslmaths prefiltered_func_data_PyCleanFSL.GLMBeta.func.nii -add mean_func.nii.gz prefiltered_func_data_PyCleanFSL.GLMBeta.func.nii.gz 
rm prefiltered_func_data_PyCleanFSL.GLMBeta.func.nii

func_data=prefiltered_func_data_PyCleanFSL.GLM.func.nii.gz 
mask=example_funcbrainmask.nii.gz

# func_data=prefiltered_func_data_mcf.nii.gz
echo $FSLDIR/bin/fslstats  ${func_data} -k ${mask} -p 50
med=`$FSLDIR/bin/fslstats ${func_data} -k ${mask}  -p 50`
thr_sus=$(echo "${med} * 0.75" |bc -l) ###


bright=$(echo "${thr_sus}/10"|bc -l)
echo $bright
susan ${func_data} ${thr_sus} 6  3 1 1 mean_func ${thr_sus} ${func_data/.nii.gz/smooth}


rm *usan*.nii.gz

mean=`$FSLDIR/bin/fslstats  ${func_data/.nii.gz/smooth} -k ${mask} -m`

scale=`echo "10000/${mean}"|bc -l`
echo ${scale}
echo $FSLDIR/bin/fslmaths -mul ${scale}  ${func_data/.nii.gz/scaled}


fslmaths ${func_data/.nii.gz/smooth} -mul ${scale}  ${func_data/.nii.gz/scaled}



# # ##### implement band pass filter
# # #### should be done for a 3 second TR 
fslmaths ${func_data/.nii.gz/scaled} -Tmean tempMean

fslmaths ${func_data/.nii.gz/scaled} -bptf 16.66666667 -1 -add tempMean filtered_func_dataPyclean ##### bandpass filtered to 100 seconds. its FWHM so TR of 2, 50 seconds means 25 as half max.

melodic -i filtered_func_dataPyclean -o ./filtered_func_dataPyclean.ica -m example_funcbrainmask.nii.gz --report --nobet --Oall



# fslmaths filtered_func_data_pycleanSmooth.nii.gz -mas example_funcbrainmask.nii.gz filtered_func_data_brain_pyclean.nii.gz


