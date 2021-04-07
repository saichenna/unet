#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# Copyright (c) 2019 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: EPL-2.0
#

# Using OpenMPI:
# mpirun -np 4 -H localhost --map-by ppr:2:socket:pe=10 \
#        --oversubscribe --report-bindings python train_horovod.py
# np :  Number of total processes (workers) = # nodes times # workers per node
# --map-by ppr:2 Processes (workers) per resource = 2 workers per resource
# --map-by socket Resource = socket
# --map-by pe=10 Process elements = 10 cores per worker
# --oversubscribe Allow more than one worker per resource
# --report-bindings Report what nodes/sockets/cores are bound by each worker

#
# Using the Intel MPI:
# mpirun -n 4 -H localhost -ppn 2  -print-rank-map  -genv I_MPI_PIN_DOMAIN=socket  \
#        -genv OMP_NUM_THREADS=24 -genv OMP_PROC_BIND=true \
#        -genv KMP_BLOCKTIME=1  python train_horovod.py
#
#   ppn:  Processes (workers) per node
#   -print-rank-map  Report what nodes/sockets/cores are bound by each worker
#   I_MPI_PIN_DOMAIN=socket pins a worker to a socket
#   -n


import horovod.keras as hvd

from dataloader import DataGenerator
from model import unet

import datetime
import os
from argparser import args
import numpy as np

import tensorflow as tf

#Sai Chenna
#from tensorflow.python import _pywrap_util_port

#import tensorflow.compat.v1 as tf
#tf.disable_v2_behavior()


#from tensorflow.python import _pywrap_util_port



if args.keras_api:
    import keras as K
else:
    from tensorflow import keras as K

CHANNELS_LAST = True

hvd.init()

os.environ["TF_CPP_MIN_LOG_LEVEL"] = "2"  # Get rid of the AVX, SSE warnings
os.environ["OMP_NUM_THREADS"] = str(args.intraop_threads)
os.environ["KMP_BLOCKTIME"] = str(args.blocktime)
os.environ["KMP_AFFINITY"] = "granularity=thread,compact,1,0"

if (hvd.rank() == 0):  # Only print on worker 0
    print_summary = args.print_model
    verbose = 1
    # os.system("lscpu")
    #os.system("uname -a")
    print("TensorFlow version: {}".format(tf.__version__))
    print("Intel MKL-DNN is enabled = {}".format(tf.pywrap_tensorflow.IsMklEnabled()))
#    print("Intel MKL-DNN is enabled = {}".format(_pywrap_util_port.IsMklEnabled()))
#    print("MKL enabled :", _pywrap_util_port.IsMklEnabled())
    print("Keras API version: {}".format(K.__version__))

else:  # Don't print on workers > 0
    print_summary = 0
    verbose = 0
    # Horovod needs to have every worker do the same amount of work.
    # Otherwise it will complain at the end of the epoch when
    # worker 0 takes more time than the others to do validation,
    # logging, and model checkpointing.
    # We'll save the worker logs and models separately but only
    # use the logs/saved model from worker 0.
    args.saved_model = "./worker{}/3d_unet_decathlon.hdf5".format(hvd.rank())

# Optimize CPU threads for TensorFlow
CONFIG = tf.ConfigProto(
    inter_op_parallelism_threads=args.interop_threads,
    intra_op_parallelism_threads=args.intraop_threads)

SESS = tf.Session(config=CONFIG)

K.backend.set_session(SESS)

CHANNEL_LAST = True
unet_model = unet(use_upsampling=args.use_upsampling,
                  learning_rate=args.lr,
                  n_cl_in=args.number_input_channels,
                  n_cl_out=1,  # single channel (greyscale)
                  feature_maps = args.featuremaps,
                  dropout=0.2,
                  print_summary=args.print_model,
                  channels_last = CHANNELS_LAST)  # channels first or last

opt = hvd.DistributedOptimizer(unet_model.optimizer)

unet_model.model.compile(optimizer=opt,
              loss=unet_model.loss,
              metrics=unet_model.metrics)

if hvd.rank() == 0:
    start_time = datetime.datetime.now()
    print("Started script on {}".format(start_time))

# Save best model to hdf5 file
saved_model_directory = os.path.dirname(args.saved_model)
try:
    os.stat(saved_model_directory)
except:
    os.mkdir(saved_model_directory)

# if os.path.isfile(args.saved_model):
#     model.load_weights(args.saved_model)

checkpoint = K.callbacks.ModelCheckpoint(args.saved_model,
                                         verbose=verbose,
                                         save_best_only=True)

# TensorBoard
if (hvd.rank() == 0):
    tb_logs = K.callbacks.TensorBoard(log_dir=os.path.join(
        saved_model_directory, "tensorboard_logs"), update_freq="batch")
else:
    tb_logs = K.callbacks.TensorBoard(log_dir=os.path.join(
        saved_model_directory, "tensorboard_logs_worker{}".format(hvd.rank())),
        update_freq="batch")

# NOTE:
# Horovod talks about having callbacks for rank 0 and callbacks
# for other ranks. For example, they recommend only doing checkpoints
# and tensorboard on rank 0. However, if there is a signficant time
# to execute tensorboard update or checkpoint update, then
# this might cause an issue with rank 0 not returning in time.
# My thought is that all ranks need to have essentially the same
# time taken for each rank.
callbacks = [
    # Horovod: broadcast initial variable states from
    # rank 0 to all other processes.
    # This is necessary to ensure consistent initialization
    # of all workers when
    # training is started with random weights or
    # restored from a checkpoint.
    hvd.callbacks.BroadcastGlobalVariablesCallback(0),

    # Horovod: average metrics among workers at the end of every epoch.
    #
    # Note: This callback must be in the list before the ReduceLROnPlateau,
    # TensorBoard or other metrics-based callbacks.
    hvd.callbacks.MetricAverageCallback(),

    # Horovod: using `lr = 1.0 * hvd.size()` from the very
    # beginning leads to worse final
    # accuracy. Scale the learning rate
    # `lr = 1.0` ---> `lr = 1.0 * hvd.size()` during
    # the first five epochs. See https://arxiv.org/abs/1706.02677
    # for details.
    hvd.callbacks.LearningRateWarmupCallback(args.lr, verbose=verbose),

    # Reduce the learning rate if training plateaus.
    K.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.6,
                                  verbose=verbose,
                                  patience=5, min_lr=0.0001),
    tb_logs,  # we need this here otherwise tensorboard delays rank 0
    checkpoint
]

training_data_params = {"dim": (args.patch_height, args.patch_width, args.patch_depth),
                        "batch_size": args.bz,
                        "n_in_channels": args.number_input_channels,
                        "n_out_channels": 1,
                        "train_test_split": args.train_test_split,
                        "validate_test_split": args.validate_test_split,
                        "augment": True,
                        "shuffle": True,
#                        "seed": args.random_seed}
                        "seed": args.random_seed*(hvd.rank()+1)}

training_generator = DataGenerator("train", args.data_path,
                                   **training_data_params)
if (hvd.rank() == 0):
    training_generator.print_info()

validation_data_params = {"dim": (args.patch_height, args.patch_width, args.patch_depth),
                          "batch_size": 1,
                          "n_in_channels": args.number_input_channels,
                          "n_out_channels": 1,
                          "train_test_split": args.train_test_split,
                          "validate_test_split": args.validate_test_split,
                          "augment": False,
                          "shuffle": False,
#                          "seed": args.random_seed}
                          "seed": args.random_seed*(hvd.rank()+1)}
validation_generator = DataGenerator("validate", args.data_path,
                                     **validation_data_params)

if (hvd.rank() == 0):
    validation_generator.print_info()

# Fit the model
# Do at least 3 steps for training and validation
steps_per_epoch = max(3, training_generator.get_length()//(args.bz*hvd.size()))
validation_steps = max(
    3, 3*training_generator.get_length()//(args.bz*hvd.size()))

unet_model.model.fit_generator(training_generator,
                    steps_per_epoch=steps_per_epoch,
                    epochs=args.epochs, verbose=verbose,
                    validation_data=validation_generator,
                    #validation_steps=validation_steps,
                    callbacks=callbacks,
                    max_queue_size=1, #args.num_prefetched_batches,
                    workers=1, #args.num_data_loaders,
                    #use_multiprocessing=True)
                    use_multiprocessing=False)

if hvd.rank() == 0:

    """
    Test the final model on test set
    """
    testing_generator = DataGenerator("test", args.data_path,
                                      **validation_data_params)
    testing_generator.print_info()

#    m = model.evaluate_generator(testing_generator, verbose=1,
    m = unet_model.model.evaluate_generator(testing_generator, verbose=1,
                                 max_queue_size=args.num_prefetched_batches,
                                 workers=args.num_data_loaders,
                                 use_multiprocessing=False)

    print("\n\nTest metrics")
    print("============")
    for idx, name in enumerate(unet_model.model.metrics_names):
        print("{} = {:.4f}".format(name, m[idx]))

    print("\n\n")

    stop_time = datetime.datetime.now()
    print("Started script on {}".format(start_time))
    print("Stopped script on {}".format(stop_time))
    print("\nTotal time = {}".format(
        stop_time - start_time))
