
for i in `ls */*/*T1_GRE*sag*gz`;do 
	echo $i
	T1_train/NHP-BrainExtraction/UNet_Model/muSkullStrip.py -in ${i} \
-model T1_train/TrainedVienna/Vienna.model/model-39-epoch -out $(dirname $i)

done
