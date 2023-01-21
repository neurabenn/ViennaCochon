#!/usr/bin/env python
import sys
import os
from nilearn import image as nimg
from nilearn import plotting as nplot
import matplotlib.pyplot as pkt
import nilearn
import nibabel as nib
import numpy as np
import pandas as pd
from nipype.algorithms.confounds import ACompCor
from nipype.interfaces.fsl import GLM



subj_dir=sys.argv[1]
func=f'{subj_dir}/prefiltered_func_data_mcf.nii.gz'
raw_func_img = nimg.load_img(func)

mvmt=pd.read_csv(f'{subj_dir}/mc/prefiltered_func_data_mcf.par',delimiter=' ',header=None).dropna(axis=1)
# nuis=pd.read_csv(f'{subj_dir}/nuissance.txt',delimiter='\t',header=None)

# noise=pd.concat([mvmt,nuis],axis=1)


def friston_confs(data):
    data=data.values
    friston=np.zeros((300,24))
    friston[:,0:6]=data
    friston[1:,6:12]=data[0:-1,:]
    friston[:,12:18]=data**2
    friston[1:,18:]=data[0:-1,:]**2
    return friston
mvmt_fr=friston_confs(mvmt)
friston_file=f'{subj_dir}/movementFriston.txt'
np.savetxt(friston_file,mvmt_fr)

print('friston movement done ')
print(mvmt_fr.shape)

def wm_csfComps():
    cc = ACompCor()
    mask_con=[f'{subj_dir}/seg/csf_func.nii.gz',f'{subj_dir}/seg/wm_func.nii.gz']
    cc_txt =(f'{subj_dir}/wm_csfCompt.txt')
    cc.inputs.realigned_file= func
    cc.inputs.mask_files = mask_con
    cc.inputs.merge_method = 'none'
    cc.inputs.num_components = 5
    cc.inputs.components_file = cc_txt
    cc.run()
wm_csfComps()
wm_csf=pd.read_csv(f'{subj_dir}/wm_csfCompt.txt',delimiter='\t').values
print(wm_csf.shape)
print('wm_csf done')
noise_file=f'{subj_dir}/noise.txt'
noise=np.hstack([mvmt_fr,wm_csf])
print(noise.shape)
np.savetxt(noise_file,noise)
# noise=np.hstack([mvmt])
# print(noise.shape)


print('cleaning with all rgressors. movement, wm and CSF regressors ')

def cleanFSLGLM(data_path,frist):
    glm = GLM()
    glm.inputs.in_file = data_path
    glm.inputs.design =frist
    glm.inputs.output_type = 'NIFTI'
    glm.inputs.demean = True
    glm.inputs.out_res_name = f'{subj_dir}/prefiltered_func_data_PyCleanFSL.GLM.func.nii'
    glm.inputs.out_file = f'{subj_dir}/prefiltered_func_data_PyCleanFSL.GLMBeta.func.nii'
    glm.run()
cleanFSLGLM(func,noise_file)

# clean_img=nilearn.image.clean_img(raw_func_img,confounds=mvmt_fr,low_pass = 0.05,high_pass= 0.001,t_r=3)

# nib.save(clean_img, f'{subj_dir}/filtered_func_data_pyclean.nii.gz')