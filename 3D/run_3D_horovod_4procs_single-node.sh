#!/bin/bash

#setup paths and environment variables
root=`pwd`/performance_logs
memory_profiling=0    # Set this as 1 if you are dumping memory log
multi_node=0   # Set this as 1 if you are running on multiple nodes
timeline=1     # Set this as 1 if you want to dump a timeline eventlog

#setup python parameters
#patch_dimension_list="32 64 128"
patch_dimension_list="240"
#batch_size_list="2 4 8 16 32"
batch_size_list="4"
epochs="50"

#create a new directory to dump performance logs

time_stamp=$(date +%Y_%m_%d_%H_%M_%S)
mkdir -p "${root}/${time_stamp}"


#submit the runs for the given parameter list

cmd=""
for patch_dimension in $patch_dimension_list
do
	for batch_size in $batch_size_list
	do
		./mpirun_unet_horovod.sh $multi_node $memory_profiling \
		$timeline $patch_dimension $batch_size $epochs $time_stamp	
		echo "Training completed! Image resolution: ${patch_dimension}x${patch_dimension}x${patch_dimension} ; Batch size: ${batch_size} ; Epochs: ${epochs} "
		cmd+="./mpirun_unet_horovod.sh $multi_node $memory_profiling \
                $timeline $patch_dimension $batch_size $epochs $time_stamp"
		cmd+=$'\n'
		echo "Clearing caches!"   
		./clear_caches.sh
	done
done

echo "Benchmarking completed!!"

echo "Sai Prabhakar Rao Chenna (schenna@ufl.edu)" > ./performance_logs/"$time_stamp"/README.txt
echo "University of Florida" >> ./performance_logs/"$time_stamp"/README.txt
echo "3D U-Net Model training on BRATS 2018 Dataset" >> ./performance_logs/"$time_stamp"/README.txt
date >> ./performance_logs/"$time_stamp"/README.txt
echo "Image dimensions: ${patch_dimension_list} " >> ./performance_logs/"$time_stamp"/README.txt
#echo "Image dimension: ${patch_dimension}x${patch_dimension}x${patch_dimension} " >> ./performance_logs/"$time_stamp"/README.txt
echo "Batch sizes: ${batch_size_list} " >> ./performance_logs/"$time_stamp"/README.txt
#echo "Batch size: ${batch_size} " >> ./performance_logs/"$time_stamp"/README.txt
echo "Trained models: `pwd`/saved_model/3d_unet_decathlon_${time_stamp}_*.hdf5" >> ./performance_logs/"$time_stamp"/README.txt
echo "Log file: `pwd`/performance_logs/${time_stamp}/3d_unet_decathlon_patchdim*.log" >> ./performance_logs/"$time_stamp"/README.txt
if (( $memory_profiling == 1 )); then
        echo "Memory profiler output log: " >> ./performance_logs/"$time_stamp"/README.txt
fi
if (( $timeline == 1 )); then
        echo "Horovod timeline log: `pwd`/performance_logs/${time_stamp}/3d_unet_decathlon_patchdim*.json" >> ./performance_logs/"$time_stamp"/README.txt
fi
echo "Architecture details: " >> ./performance_logs/"$time_stamp"/README.txt
lscpu >> ./performance_logs/"$time_stamp"/README.txt
echo "Command(s) to reproduce the results: " >> ./performance_logs/"$time_stamp"/README.txt
echo $cmd >> ./performance_logs/"$time_stamp"/README.txt
