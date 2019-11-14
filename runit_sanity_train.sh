#!/bin/bash
source ./config.sh 
INSTALL_DIR=/lus/scratch/${USERNAME}/condaenv_cpu_tf15 
# Setup programming environment
module unload PrgEnv-cray
module load PrgEnv-gnu
module unload craype-hugepages8M
module unload atp
source activate $INSTALL_DIR


which python
#module list
export SCRATCH=/lus/scratch/${USERNAME}
export MPICH_ENV_DISPLAY=1
export MPICH_VERSION_DISPLAY=1
export MPICH_CPUMASK_DISPLAY=1
#export MPICH_COLL_SYNC=1 #force everyone into barrier before each collective
#export MPICH_RDMA_ENABLED_CUDA=1
export MPICH_MAX_THREAD_SAFETY=multiple

module rm atp

#export HOROVOD_MPI_THREADS_DISABLE=1
#export HOROVOD_FUSION_THRESHOLD=0
#export HOROVOD_TIMELINE_MARK_CYCLES=1
#export HOROVOD_CYCLE_TIME=3.5
export OMP_NUM_THREADS=72

echo "Running..."
NP=256
NODES=256
BATCH_SIZE=4
NUM_EPOCHS=100

WKDIR=/lus/scratch/${USER}/resnet101_tencent_horovod_xc50p100_run_${NODES}nodes_${NP}np_${BATCH_SIZE}lbs_${NUM_EPOCHS}epochs
rm -rf $WKDIR
mkdir -p $WKDIR


set -x 

# Parameters for the training
DATASET_DIR=/lus/scratch/${USER}/DataSets/resnet101_tencent_distributed/data/tfrecords-full
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
DATA_FORMAT='NCHW'
LOG_INTERVAL=100
LOG_DIR="${WKDIR}"
if [[ ! -d $LOG_DIR ]]; then
  mkdir -p $LOG_DIR
fi

cp -r * $WKDIR/
cd $WKDIR/
echo $PWD
mkdir checkpoint
export SLURM_WORKING_DIR=$WKDIR
#export TF_CPP_MIN_LOG_LEVEL=0
#export TF_CPP_MIN_VLOG_LEVEL=0

time srun -N ${NODES} -l --ntasks=${NP} --ntasks-per-node=1 -C P100 --gres=gpu --exclusive -u python train.py \
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
	--data_format=${DATA_FORMAT} 2>&1 | tee ${LOG_DIR}/Node${NODE_NUM}_GPU${GPU_NUM}.log 
