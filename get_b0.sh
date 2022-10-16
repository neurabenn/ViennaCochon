#!/bin/bash 

#### use a folder as input 
subj_dir=$1 

echo "######### The directiory is #########"
echo ${subj_dir}

echo  "########## The subject is ###########"
subj=$(basename ${subj_dir})
echo $subj


proc_dir=${subj_dir}/dti_${subj}_pprocess
mkdir -p ${proc_dir}

#### copy images into pproc directory 
for img in DTI_tra.bval DTI_tra.bvec DTI_tra.nii.gz;do 
	cp ${subj_dir}/${img} ${proc_dir}/${img}
done

echo "###### moving the T1 images to ${subj} pprocess diffusion dir ######"

cp ${subj_dir}/T1_GRE_TurboFLASH_WE_3D_tra.nii.gz ${proc_dir}/anat_T1.nii.gz

cp ${subj_dir}/t1_tir_cor.nii.gz ${proc_dir}/anat_T1_ir.nii.gz

cp ${subj_dir}/T2_TSE_tra_2_5mm.nii.gz ${proc_dir}/anat_T2.nii.gz


###### change working directory to proc_dir ####### 

cd ${proc_dir}
$FSLDIR/bin/fslroi DTI_tra.nii.gz B0_vol.nii.gz 0 1 
ls 