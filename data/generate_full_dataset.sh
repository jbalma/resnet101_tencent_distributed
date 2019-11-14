#!/bin/bash
#source /cray/css/users/jbalma/bin/env_python.sh
export INSTALL_DIR=/lus/scratch/jbalma/condaenv_cpu_tf15
source /cray/css/users/jbalma/bin/env_python3.sh
# Setup programming environment
module unload PrgEnv-cray
module load PrgEnv-gnu
module unload craype-hugepages8M
module unload atp
source activate /lus/scratch/jbalma/condaenv_cpu_tf15


which python
#module rm gcc
#module load craype-ml-plugin-py2
#module load craype-dl-plugin-py3
#module list
export SCRATCH=/lus/scratch/jbalma



echo "Starting download of tiny dataset..."
export PBS_O_WORKDIR=/lus/scratch/jbalma/DataSets/resnet101_tencent_distributed/data
#source download_urls_multithreading.sh
#Make sure you're using python2.7
export OMP_NUM_THREADS=72
which python 

export APRUN_WDIR=$PBS_O_WORKDIR

#time aprun -r 1 -n 1 -N 1 -cc none -d $OMP_NUM_THREADS python $PBS_O_WORKDIR/download_urls_multithreading.py --url_list=url_lists/train_urls_from_openimages.txt --im_list=image_lists/train_image_id_from_openimages.txt --num_threads=${OMP_NUM_THREADS} --save_dir='./images-full' 2>&1 |& tee ${PBS_O_WORKDIR}/logfile_downloads_full.log 
#aprun -n 1 -N 1 python ./download_urls_multithreading.py --url_list=train_urls_tiny.txt --im_list=train_im_list_tiny.txt --num_threads=20 --save_dir='./images-tiny'
echo "Done downloading."

echo "Generating tfrecords ..."
time aprun -n 1 -N 1 -cc none -d $OMP_NUM_THREADS -j 2 python $PBS_O_WORKDIR/tfrecord.py -idx $PBS_O_WORKDIR/image_lists/ -tfs $PBS_O_WORKDIR/tfrecords-full/ -im $PBS_O_WORKDIR/images-full/ -cls 11166 -one True 2>&1 |& tee ${PBS_O_WORKDIR}/logfile_tfrecords_full.log
echo "Done generating tfrecords

