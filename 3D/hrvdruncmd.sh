#!/usr/bin/env bash

mpiexec --machinefile hostfile -genv I_MPI_DEBUG 4 \ 
	-np 1  --ppn 1 --genv OMP_NUM_THREADS 24 \
	python train_horovod.py --patch_height 32 --patch_width 32 --patch_depth 32 --bz 16 --epochs 1 --data_path ../../Task01_BrainTumour --saved_model ./saved_model/3d_unet_decathlon_10-09-20-MKLDNN-hrvd-2serv-v1.hdf5
