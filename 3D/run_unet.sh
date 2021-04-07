#!/bin/bash

#Sai Prabhakar Rao Chenna (schenna@ufl.edu)
#University of Florida




#read the input arguments


memory_profiler_flag=$1
patch_dimension=$2
batch_size=$3
epochs=$4
time_stamp=$5 

zero=0

#make necessary changes if image dimensions are not symmetrical
if (( $patch_dimension == 240 )); then
	patch_height=$patch_dimension
	patch_width=$patch_dimension
	patch_depth="144"

else
	patch_height=$patch_dimension
	patch_width=$patch_dimension
	patch_depth=$patch_dimension

fi


if (( $memory_profiler_flag ==  0 )); then
	python train.py --patch_height $patch_height --patch_width $patch_width --patch_depth $patch_depth --bz $batch_size --epochs $epochs --data_path ../../Task01_BrainTumour --saved_model ./saved_model/3d_unet_decathlon_nohrvd_"$time_stamp"_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".hdf5 | tee ./performance_logs/"$time_stamp"/3d_unet_decathlon_nohrvd_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".log

else
	mprof run --output ./performance_logs/"$time_stamp"/3d_unet_decathlon_nohrvd_"$time_stamp"_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.dat python train.py --patch_height $patch_height --patch_width $patch_width --patch_depth $patch_depth --bz $batch_size --epochs $epochs --data_path ../../Task01_BrainTumour --saved_model ./saved_model/3d_unet_decathlon_nohrvd_"$time_stamp"_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".hdf5 | tee ./performance_logs/"$time_stamp"/3d_unet_decathlon_nohrvd_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".log

fi



 

