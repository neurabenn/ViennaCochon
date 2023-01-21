#!/bin/bash 

dir=$1
##WarpImageMultiTransform 3 seg/wm_ants.nii.gz  wm_func.nii.gz -R example_func_brain.nii.gz ReNormalization/epi2func0GenericAffine.mat

cd $dir 

WarpImageMultiTransform 3 seg/wm_ants.nii.gz  seg/wm_func.nii.gz -R example_func_brain.nii.gz ReNormalization/epi2func0GenericAffine.mat 
fslmaths seg/wm_func.nii.gz -thr 0.95  -bin  seg/wm_func.nii.gz 
fslmeants -i filtered_func_data -o seg/WMts.txt -m seg/wm_func.nii.gz 



WarpImageMultiTransform 3 seg/csf_ants.nii.gz  seg/csf_func.nii.gz -R example_func_brain.nii.gz ReNormalization/epi2func0GenericAffine.mat 
fslmaths seg/csf_func.nii.gz -thr 0.95  -bin  seg/csf_func.nii.gz 
fslmeants -i filtered_func_data -o seg/CSFts.txt -m seg/csf_func.nii.gz 


WarpImageMultiTransform 3 seg/gm_ants.nii.gz  seg/gm_func.nii.gz -R example_func_brain.nii.gz ReNormalization/epi2func0GenericAffine.mat 
fslmaths seg/gm_func.nii.gz -thr 0.5 -bin seg/gm_func.nii.gz 
fslmeants -i filtered_func_data -o seg/GMts.txt -m seg/gm_func.nii.gz 


paste seg/CSFts.txt seg/WMts.txt >> nuissance.txt

echo "###########################"
echo "regressing out csf and wm "
echo $dir
echo "##########################"

fsl_glm -i filtered_func_data.nii.gz -d nuissance.txt  -o nuissanceBetas --out_res=filtered_func_data_clean.nii.gz -m example_funcbrainmask.nii.gz