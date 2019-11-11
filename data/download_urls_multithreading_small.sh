#!/bin/bash
source /cray/css/users/jbalma/bin/env_python.sh 
#Make sure you're using python2.7
which python

srun -n 1 -N 1 python ./download_urls_multithreading.py --url_list=train_urls_tiny.txt --im_list=train_im_list_tiny.txt --num_threads=20 --save_dir='./images-tiny'
