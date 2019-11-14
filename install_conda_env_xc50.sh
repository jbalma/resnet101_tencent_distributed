#!/bin/bash

#If on Cray XC, use these modules
#Modules required imply gcc/g++, anaconda with python3
module rm PrgEnv-cray
module load PrgEnv-gnu 
module use /cray/css/users/dctools/modulefiles
module load anaconda3
module list

#If on cluster, setup these variables with your local MPI
#export MPI_PATH=/Path/to/OpenMPI-4/ompi-gcc72-cuda10
#export OPAL_PREFIX=${MPI_PATH}
#export PATH=${MPI_PATH}/bin:${PATH}
#export cc=${MPI_PATH}/bin/mpicc
#export CC=${MPI_PATH}/bin/mpicxx
export PYTHONIOENCODING=utf8


#Create conda environment
export CONDA_ENV_DIR=/lus/scratch/${USERNAME}/condaenv_cpu_tf15
conda create -y --prefix $CONDA_ENV_DIR python=3.6 mkl mkl-include 

#activate the new conda environment
source activate $CONDA_ENV_DIR

#install some packages
conda install -y -c conda-forge scipy dask pip 
pip install tensorflow==1.15 matplotlib 
#pip install --force-reinstall pyYAML --user
conda deactivate
#When this finishes, run ./install_horovod_python3_cs.sh



