# resnet101_tencent_distributed
ResNet101 Training on TenCent Images using various distributed frameworks


Step 1) Download Dataset

Use the URLS below to get the following files:

train_image_id_from_imagenet.txt
train_urls_from_openimages.txt
val_image_id_from_imagenet.txt
val_urls_from_openimages.txt

https://github.com/Tencent/tencent-ml-images#download-images


Step 2) Download the actual data from each of those lists
cd data
Change relevant paths
./download_urls_multithreading.sh

Step 3) Convert everything to tfrecords

Use the imagenet ids from above, and the openimage ids generated from 2 to create tf records. Do this for each of these lists by putting them all in the directory image_lists_full and point the tfrecords.sh script to them:

train_image_id_from_imagenet.txt
val_image_id_from_imagenet.txt
train_image_id_from_openimages.txt
val_image_id_from_openimages.txt


cd data
./tfrecord.sh


Step 4) Runit


