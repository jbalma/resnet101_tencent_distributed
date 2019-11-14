#!/bin/bash

#qsub -lnodes=128,walltime=7200,nodetype=BW36 ./runit_crystal.sh 
#qsub -V -N pytorch_heptrkx_gnn -lselect=4:nodetype=BW36,place=scatter runit_crystal.sh 
#qsub -N pytorch_gnn -j oe -lnodes=16,walltime=7200,nodetype=BW36 runit_crystal.sh

qsub -lwalltime=24:00:00 -N tencent_preprocessing -j oe -o myrun.out -lselect=1:class=BW:cu=36:availmem=128g:clockmhz=2100,place=scatter generate_full_dataset.sh

#              -l select=[N:]chunk[+[N:]chunk ...]

#       where N specifies how many of that chunk, and a chunk is of the form:

#              resource_name=value[:resource_name=value ...]


