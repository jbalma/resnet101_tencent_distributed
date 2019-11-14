#!/bin/bash
export INSTALL_DIR=/lus/scratch/${USERNAME}/condaenv_cpu_tf15
source ./env_python3.sh
# Setup programming environment
module unload PrgEnv-cray
module load PrgEnv-gnu
module unload craype-hugepages8M
module unload atp
source activate $INSTALL_DIR


which python
export SCRATCH=/lus/scratch/jbalma
export MPICH_ENV_DISPLAY=1
export MPICH_VERSION_DISPLAY=1
export MPICH_CPUMASK_DISPLAY=1
#export MPICH_COLL_SYNC=1 #force everyone into barrier before each collective
#export MPICH_RDMA_ENABLED_CUDA=1
export MPICH_MAX_THREAD_SAFETY=multiple

#export CRAY_CUDA_MPS=1
#export CUDA_VISIBLE_DEVICES=0
#export CRAY_CUDA_PROXY=0
#export HOROVOD_TIMELINE=/tmp/timeline.json
#export HOROVOD_FUSION_THRESHOLD=256000000
#export HOROVOD_MPI_THREADS_DISABLE=1
#export HOROVOD_FUSION_THRESHOLD=0
export HOROVOD_AUTOTUNE=1
#export HOROVOD_TIMELINE_MARK_CYCLES=1
#export HOROVOD_CYCLE_TIME=3.5
export OMP_NUM_THREADS=72

echo "Running..."
NUM_EPOCHS=100
BATCH_SIZE=4
mkdir checkpoint
export TF_CPP_MIN_LOG_LEVEL=0
export TF_CPP_MIN_VLOG_LEVEL=0
export PBS_NP=$(qstat -f $PBS_JOBID | grep Resource_List.ncpus | awk '{print $3}')
export PBS_NUM_NODES=$(qstat -f $PBS_JOBID | grep Resource_List.nodect | awk '{print $3}')
export PBS_NUM_PPN=$((PBS_NP/PBS_NUM_NODES))
export PBS_NUM_PPS=$((PBS_NUM_PPN/2))
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$CRAY_LD_LIBRARY_PATH
NP=$PBS_NP
NODES=$PBS_NUM_NODES
PPN=$PBS_NUM_PPN
PPS=$PBS_NUM_PPS 
NC=$OMP_NUM_THREADS 


WKDIR=/lus/scratch/${USER}/temp/resnet101_tencent_horovod_xc50bdw18_run_${NODES}nodes_${NP}np_${BATCH_SIZE}lbs_${NUM_EPOCHS}epochs
rm -rf $WKDIR
mkdir -p $WKDIR




set -x 

# Parameters for the training
DATASET_DIR=/lus/scratch/${USERNAME}/DataSets/resnet101_tencent_distributed/data/tfrecords-tiny/
WITH_BBOX=FALSE
IMG_SIZE=224
CLASSNUM=11166
RESNET=101
MASK_THRES=0.7
NEG_SELECT=0.1
BATCHSIZE=${BATCH_SIZE}
SNAPSHOT=4400
BATCHNORM_DECAY=0.997
BATCHNORM_EPS=1e-5
LR=0.08
LR_DECAY_STEP=110000
LR_DECAY_FACTOR=0.1
WEIGHT_DECAY=0.0001
WARMUP=35200
LR_WARMUP=0.01
LR_WARMUP_DECAY_STEP=4400
LR_WARMUP_DECAY_FACTOR=1.297
MAXIER=440000
#DATA_FORMAT='NCHW'
DATA_FORMAT='NHWC'
LOG_INTERVAL=100
LOG_DIR="${WKDIR}"
if [[ ! -d $LOG_DIR ]]; then
  mkdir -p $LOG_DIR
fi

CODE_DIR=${PWD}
cp -r $CODE_DIR/* $WKDIR/
cd $WKDIR/
#export HOROVOD_TIMELINE=$PWD/timeline.json
echo $PWD
date

#run training
#export PYTHONTHREADDEBUG=1
#export PYTHONDUMPREFS=1
#export PYTHONMALLOCSTATS=1
#export PYTHONFAULTHANDLER=1
#export PYTHONTRACEMALLOC=1
#export PYTHONASYNCIODEBUG=1

time aprun -n $PBS_NP -N $PBS_NUM_PPN -d $OMP_NUM_THREADS -j 2 -cc none python -d train.py \
	--data_dir=${DATASET_DIR} \
    --image_size=${IMG_SIZE} \
	--class_num=${CLASSNUM} \
	--resnet_size=${RESNET} \
    --mask_thres=${MASK_THRES} \
    --neg_select=${NEG_SELECT} \
	--batch_size=${BATCHSIZE} \
    --with_bbox=${WITH_BBOX} \
    --batch_norm_decay=${BATCHNORM_DECAY} \
    --batch_norm_epsilon=${BATCHNORM_EPS} \
	--lr=${LR} \
	--lr_decay_step=${LR_DECAY_STEP} \
	--lr_decay_factor=${LR_DECAY_FACTOR} \
    --weight_decay=${WEIGHT_DECAY} \
	--max_iter=${MAXIER} \
	--snapshot=${SNAPSHOT} \
	--warmup=${WARMUP} \
	--lr_warmup=${LR_WARMUP} \
	--lr_warmup_decay_step=${LR_WARMUP_DECAY_STEP} \
	--lr_warmup_decay_factor=${LR_WARMUP_DECAY_FACTOR} \
	--log_interval=${LOG_INTERVAL} \
	--data_format=${DATA_FORMAT} 2>&1 | tee ${LOG_DIR}/logfile #Node${NODE_NUM}_GPU${GPU_NUM}.log 
