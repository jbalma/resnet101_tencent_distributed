#!/bin/bash
export INSTALL_DIR=/lus/scratch/${USERNAME}/condaenv_cpu_tf15
source ./env_python3.sh
# Setup programming environment
module unload PrgEnv-cray
module load PrgEnv-gnu
module unload atp
module unload craype-hugepages8M
#-D_GLIBCXX_USE_CXX11_ABI=0
source activate $INSTALL_DIR
conda update --all
conda install -c conda -y cmake
pip uninstall -y horovod 
#conda install -y -c anaconda tensorflow-mkl
#pip install intel-tensorflow
#pip install -y intel-tensorflow==1.14.0
which gcc 
CC=cc CXX=CC HOROVOD_MPICXX_SHOW="CC --cray-print-opts=all" HOROVOD_WITHOUT_GLOO=1 HOROVOD_HIERARCHICAL_ALLREDUCE=1 HOROVOD_WITH_TENSORFLOW=1 HOROVOD_WITHOUT_PYTORCH=1 HOROVOD_WITHOUT_MXNET=1 pip install -v --no-cache-dir horovod 

conda deactivate
