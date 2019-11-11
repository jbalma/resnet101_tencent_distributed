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
./download_urls_multithreading.sh

Step 3) Convert everything to tfrecords
cd data
./tfrecord.sh


Step 4) Runit


