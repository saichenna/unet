#!/bin/bash

#Sai Prabhakar Rao Chenna (schenna@ufl.edu)
#University of Florida




#read the input arguments

multi_node_flag=$1

memory_profiler_flag=$2

timeline_flag=$3

patch_dimension=$4

batch_size=$5

epochs=$6

time_stamp=$7 

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


if (( $multi_node_flag == 0 )); then
	if (( $memory_profiler_flag ==  0 )); then
		if (( $timeline_flag == 0 )); then
			mpirun --allow-run-as-root -H localhost \ 
			#oshrun --allow-run-as-root -H localhost \ 
			-np 2 --map-by ppr:2:node,pe=40 --oversubscribe \ 
			--report-bindings python train_horovod.py \ 
			--patch_height $patch_height \ 
			--patch_width $patch_width \ 
			--patch_depth $patch_depth --bz $batch_size \ 
			--epochs $epochs --data_path ../../Task01_BrainTumour \ 
			--saved_model ./saved_model/3d_unet_decathlon_"$time_stamp"_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".hdf5 | \ 
			tee ./performance_logs/"$time_stamp"/3d_unet_decathlon_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".log
#			cmd="mpirun --allow-run-as-root -H localhost \
#                        -np 4 --map-by ppr:1:socket,pe=20 --oversubscribe \
#                        --report-bindings python train_horovod.py \
#                        --patch_height ${patch_dimension} \ 
#                        --patch_width ${patch_dimension} \
#                        --patch_depth ${patch_dimension} --bz ${batch_size} \
#                        --epochs ${epochs} --data_path ../../Task01_BrainTumour \
#                        --saved_model ./saved_model/3d_unet_decathlon_${time_stamp}_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.hdf5 | \
#                        tee ./performance_logs/${time_stamp}/3d_unet_decathlon_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.log"
	
		else
			mpirun --allow-run-as-root -H localhost \
			#oshrun --allow-run-as-root -H localhost \
			-x HOROVOD_TIMELINE=`pwd`/performance_logs/${time_stamp}/3d_unet_decathlon_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.json \
                        -np 2 --map-by ppr:2:node,pe=40 --oversubscribe \
                        --report-bindings python train_horovod.py \
                        --patch_height $patch_height --patch_width $patch_width \
                        --patch_depth $patch_depth --bz $batch_size \
                        --epochs $epochs --data_path ../../Task01_BrainTumour \
                        --saved_model ./saved_model/3d_unet_decathlon_"$time_stamp"_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".hdf5 | \
                        tee ./performance_logs/"$time_stamp"/3d_unet_decathlon_patchdim"$patch_dimension"_bz"$batch_size"_epochs"$epochs".log
#			cmd="mpirun -x HOROVOD_TIMELINE=`pwd`/performance_logs/${time_stamp}/3d_unet_decathlon_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.json \
#                        --allow-run-as-root -H localhost \
#                        -np 4 --map-by ppr:1:socket,pe=20 --oversubscribe \
#                        --report-bindings python train_horovod.py \
#                        --patch_height ${patch_dimension} \ 
#			--patch_width ${patch_dimension} \
#                        --patch_depth ${patch_dimension} --bz ${batch_size} \
#                        --epochs ${epochs} --data_path ../../Task01_BrainTumour \
#                        --saved_model ./saved_model/3d_unet_decathlon_${time_stamp}_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.hdf5 | \
#                        tee ./performance_logs/${time_stamp}/3d_unet_decathlon_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.log"


		fi
	fi
fi

#echo "Sai Prabhakar Rao Chenna (schenna@ufl.edu)" > ./performance_logs/"$time_stamp"/README.txt
#echo "University of Florida" >> ./performance_logs/"$time_stamp"/README.txt
#echo "3D U-Net Model training on BRATS 2018 Dataset" >> ./performance_logs/"$time_stamp"/README.txt
#date >> ./performance_logs/"$time_stamp"/README.txt
#echo "Image dimension: ${patch_dimension}x${patch_dimension}x${patch_dimension} " >> ./performance_logs/"$time_stamp"/README.txt
#echo "Batch size: ${batch_size} " >> ./performance_logs/"$time_stamp"/README.txt
#echo "Trained model: `pwd`/saved_model/3d_unet_decathlon_${time_stamp}_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.hdf5" >> ./performance_logs/"$time_stamp"/README.txt
#echo "Log file: `pwd`/performance_logs/${time_stamp}/3d_unet_decathlon_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.log" >> ./performance_logs/"$time_stamp"/README.txt
#if (( $memory_profiler_flag == 1 )); then
#	echo "Memory profiler output log: " >> ./performance_logs/"$time_stamp"/README.txt
#fi
#if (( $timeline_flag == 1 )); then
#	echo "Horovod timeline log: `pwd`/performance_logs/${time_stamp}/3d_unet_decathlon_patchdim${patch_dimension}_bz${batch_size}_epochs${epochs}.json" >> ./performance_logs/"$time_stamp"/README.txt
#fi
#echo "Architecture details: " >> ./performance_logs/"$time_stamp"/README.txt
#lscpu >> README.txt
#echo "Script to reproduce the results: " >> ./performance_logs/"$time_stamp"/README.txt
#echo $cmd >> ./performance_logs/"$time_stamp"/README.txt


 

