#!/bin/bash 

subj=$1
struct=$2
func=$3
std=$4
std_mask=$5

out=${subj}/$(basename $subj).pcp
mkdir -p ${out}


echo "OUTPUT DIRECTORY IS" 
echo ${out}

echo "structural image is" 
echo ${struct}
echo "func is"
echo ${func}


echo '######################################################'
mask=${struct/.nii.gz/_pre_mask.nii.gz}

fslmaths ${struct} ${out}/highres.nii.gz
fslmaths ${func} ${out}/prefiltered_func_data.nii.gz
fslmaths ${mask} ${out}/brain_mask.nii.gz
fslmaths ${std} ${out}/std.nii.gz
fslmaths ${std_mask} ${out}/ref_mask.nii.gz

cd ${out}

mkdir -p reg

echo "###### registraton to PNI50 ######"

fslmaths highres -mas brain_mask highres_brain

DenoiseImage -d 3 -i highres_brain.nii.gz -o highres_brain.nii.gz

flirt -in highres_brain -ref std -searchrx -180 180 -searchry -180 180 -searchrz -180 180 -out highres2stdLin.nii.gz -dof 12 -omat highres2std.mat 

echo "running fnirt"
fnirt --in=highres_brain.nii.gz --ref=std.nii.gz --aff=highres2std.mat --inmask=brain_mask.nii.gz --refmask=ref_mask.nii.gz --cout=highres2std_warp

applywarp --in=highres_brain.nii.gz --ref=std.nii.gz  --warp=highres2std_warp --out=highres2stdWarped.nii.gz
echo "registration done"


#### create example func image 
echo "example func volume is "
vols=$(fslnvols prefiltered_func_data.nii.gz)
mid=`echo $vols/2|bc`
echo $mid

fslroi prefiltered_func_data.nii.gz example_func_data.nii.gz ${mid} 1


#### initial betting 

bet example_func_data.nii.gz example_func_data_initBET.nii.gz -m  -f 0.9 -c 38 28 10 

#### initialize func brain extraction with registration 
flirt -in example_func_data_initBET.nii.gz -ref highres_brain.nii.gz -dof 7  -out example_func2highresInit  -omat example_func2highresInit.mat -usesqform
convert_xfm  -omat highres_2examplefuncInit.mat -inverse example_func2highresInit.mat

applywarp  -i brain_mask.nii.gz -r example_func_data.nii.gz -o func_maskInit.nii.gz --premat=highres_2examplefuncInit.mat

fslmaths func_maskInit.nii.gz -dilM -dilM -bin func_maskInit.nii.gz

fslmaths example_func_data.nii.gz -mas func_maskInit.nii.gz example_func_brain.nii.gz

##### second extraction 

flirt -in example_func_brain.nii.gz -ref highres_brain.nii.gz -dof 7  -usesqform -out example_func2highres -omat example_func2highres.mat
convert_xfm  -omat highres_2examplefunc.mat -inverse example_func2highres.mat

applywarp  -i brain_mask.nii.gz -r example_func_data.nii.gz -o example_funcbrainmask.nii.gz --premat=highres_2examplefuncInit.mat

fslmaths example_funcbrainmask.nii.gz -dilM -bin  example_funcbrainmask.nii.gz
fslmaths example_func_data.nii.gz -mas example_funcbrainmask.nii.gz example_func_brain.nii.gz

### final registration
### init with 6dof 
flirt -in example_func_brain.nii.gz -ref highres_brain.nii.gz -dof 7 -usesqform -out example_func2highres -omat example_func2highres.mat



convertwarp --premat=example_func2highres.mat --ref=$std --warp1=highres2std_warp.nii.gz --out=example_func2std_warp



rm *Init*

mv *mat reg
mv *warp* reg
##### run fast to do white matter segmentation 

mkdir -p seg

fast -o seg/seg highres_brain.nii.gz

fslmaths seg/seg_pve_2.nii.gz -thr 0.5 -bin wm.nii.gz


####### TIME FOR TIME SERIES ######## 


### let's do motion correction to the example func image 

mcflirt -in prefiltered_func_data -out prefiltered_func_data_mcf -mats -plots -reffile example_func_data.nii.gz -rmsrel -rmsabs -spline_final

/bin/mkdir -p mc ; /bin/mv -f prefiltered_func_data_mcf.mat prefiltered_func_data_mcf.par prefiltered_func_data_mcf_abs.rms prefiltered_func_data_mcf_abs_mean.rms prefiltered_func_data_mcf_rel.rms prefiltered_func_data_mcf_rel_mean.rms mc
cd mc
fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated rotations (radians)' -u 1 --start=1 --finish=3 -a x,y,z -w 640 -h 144 -o rot.png 

fsl_tsplot -i prefiltered_func_data_mcf.par -t 'MCFLIRT estimated translations (mm)' -u 1 --start=4 --finish=6 -a x,y,z -w 640 -h 144 -o trans.png 

fsl_tsplot -i prefiltered_func_data_mcf_abs.rms,prefiltered_func_data_mcf_rel.rms -t 'MCFLIRT estimated mean displacement (mm)' -u 1 -w 640 -h 144 -a absolute,relative -o disp.png 
cd ../

pwd

#### extract brain so make sure we only include brain voxels in smoothing 

# fslmaths prefiltered_func_data_mcf.nii.gz -mas example_funcbrainmask.nii.gz prefiltered_func_data_thr



#### do smoothing and susan 

kernel=6
mask=example_funcbrainmask.nii.gz 

func_data=prefiltered_func_data_mcf.nii.gz
echo $FSLDIR/bin/fslstats  ${func_data} -k ${mask} -p 50
med=`$FSLDIR/bin/fslstats ${func_data} -k ${mask}  -p 50`
thr_sus=$(echo "${med} * 0.75" |bc -l) ####### for info on this look here: https://www.jiscmail.ac.uk/cgi-bin/webadmin?A2=fsl;a0fe9d7c.1209

echo "intensity for susan is " ${thr_sus}
echo "gaussian kernel selected is" ${kernel}

sig=$(echo "${kernel}/(sqrt(8 * l(2)))" | bc -l)

echo ${sig}
echo "running susan using a gausian kernel of" ${kernel} "mm"

fslmaths ${func_data} -Tmean mean_func

echo susan ${func_data} ${thr_sus} ${sig}  3 1 1 mean_func ${thr_sus} ${func_data/.nii.gz/smooth}
susan ${func_data} ${thr_sus} ${sig}  3 1 1 mean_func ${thr_sus} ${func_data/.nii.gz/smooth}

rm *usan*.nii.gz

mean=`$FSLDIR/bin/fslstats  ${func_data/.nii.gz/smooth} -k ${mask} -m`

scale=`echo "10000/${mean}"|bc -l`
echo ${scale}
echo $FSLDIR/bin/fslmaths -mul ${scale}  ${func_data/.nii.gz/scaled}


fslmaths ${func_data/.nii.gz/smooth} -mul ${scale}  ${func_data/.nii.gz/scaled}



# # ##### implement band pass filter
# # #### should be done for a 3 second TR 

fslmaths ${func_data/.nii.gz/scaled} -bptf 16.66666667 -1 filtered_func_data ##### bandpass filtered to 100 seconds. its FWHM so TR of 2, 50 seconds means 25 as half max.

melodic -i filtered_func_data.nii.gz -o ./filtered_func_data.ica -m ${mask} --report --nobet --Oall



