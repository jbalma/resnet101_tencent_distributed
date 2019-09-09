#!/bin/bash
#SBATCH -N 8
#SBATCH -C P100
#SBATCH --gres=gpu
#SBATCH --exclusive

source ./setup_env_cuda10_cray.sh
source ./env_python.sh
#module load craype-ml-plugin-py2
#module load craype-dl-plugin-py3
#module list
export SCRATCH=/lus/scratch/jbalma
export MPICH_ENV_DISPLAY=1
export MPICH_VERSION_DISPLAY=1
export MPICH_CPUMASK_DISPLAY=1
#export MPICH_COLL_SYNC=1 #force everyone into barrier before each collective
#export MPICH_RDMA_ENABLED_CUDA=1
export MPICH_MAX_THREAD_SAFETY=multiple
#export CRAY_CUDA_MPS=1
export CUDA_VISIBLE_DEVICES=0
#export CRAY_CUDA_PROXY=0

echo "Running..."
NP=8
NODES=8
BATCH_SIZE=1
NUM_EPOCHS=100

WKDIR=/lus/scratch/${USER}/resnet_cifar10_keras_horovod_xc50p100_run_${NODES}nodes_${NP}np_${BATCH_SIZE}lbs_${NUM_EPOCHS}epochs
rm -rf $WKDIR
mkdir -p $WKDIR


set -x 

# Parameters for the training
DATASET_DIR=/lus/scratch/${USER}/DataSets/TenCent/tencent-ml-images/data/tfrecords 
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

#--model_dir=./out/checkpoint/imagenet/resnet_model_${NODE_NUM}node_${GPU_NUM}gpu \
#--tmp_model_dir=./out/tmp/imagenet/resnet_model_${NODE_NUM}node_${GPU_NUM}gpu \

cp -r * $WKDIR/
cd $WKDIR/
echo $PWD
#export PYTHONPATH="${PYTHONPATH}:$PWD/cray_keras_utils"
mkdir checkpoint
export SLURM_WORKING_DIR=$WKDIR
#export TF_CPP_MIN_LOG_LEVEL=3
#export TF_CPP_MIN_VLOG_LEVEL=0

time srun -N ${NODES} -l --ntasks=${NP} --ntasks-per-node=1 -C P100 --gres=gpu --exclusive --cpu_bind=none -u python train.py \
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
