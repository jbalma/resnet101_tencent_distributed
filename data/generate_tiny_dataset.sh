#!/bin/bash
source /cray/css/users/jbalma/bin/env_python.sh

echo "Starting download of tiny dataset..."
export PBS_O_WORKDIR=/lus/scratch/jbalma/DataSets/resnet101_tencent_distributed/data
#source download_urls_multithreading.sh
#Make sure you're using python2.7
export OMP_NUM_THREADS=36
which python 

export APRUN_WDIR=$PBS_O_WORKDIR

#time aprun -r 1 -n 1 -N 1 -cc none -d $OMP_NUM_THREADS python $PBS_O_WORKDIR/download_urls_multithreading.py --url_list=train_urls_tiny.txt --im_list=train_im_list_tiny.txt --num_threads=${OMP_NUM_THREADS} --save_dir='./images-tiny' 2>&1 |& tee ${PBS_O_WORKDIR}/logfile_downloads.log
#aprun -n 1 -N 1 python ./download_urls_multithreading.py --url_list=train_urls_tiny.txt --im_list=train_im_list_tiny.txt --num_threads=20 --save_dir='./images-tiny'
echo "Done downloading."

echo "Generating tfrecords ..."
time aprun -r 1 -n 1 -N 1 -cc none -d $OMP_NUM_THREADS python $PBS_O_WORKDIR/tfrecord.py -idx $PBS_O_WORKDIR/image_lists_tiny/ -tfs $PBS_O_WORKDIR/tfrecords-tiny/ -im $PBS_O_WORKDIR/images-tiny/ -cls 11166 -one True 2>&1 |& tee ${PBS_O_WORKDIR}/logfile_tfrecords.log 
echo "Done generating tfrecords

