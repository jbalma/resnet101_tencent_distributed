# resnet101_tencent_distributed
ResNet101 Training on TenCent Images using various distributed frameworks


Step 1) Download Dataset

Use the URLS below to get the following files:

train_image_id_from_imagenet.txt
train_urls_from_openimages.txt
val_image_id_from_imagenet.txt
val_urls_from_openimages.txt

https://github.com/Tencent/tencent-ml-images#download-images

You should see output like this while its running:

tail -f logfile_downloads_full.log
url = https://c2.staticflickr.com/1/29/45599490_77967a4b38_o.jpg is finished and 26 imgs have been downloaded of all 6902811 imgs
url = https://farm2.staticflickr.com/2643/4098016552_4889ff6f3c_o.jpg is finished and 27 imgs have been downloaded of all 6902811 imgs
url = https://c1.staticflickr.com/8/7414/16265020500_92ed625670_o.jpg is finished and 28 imgs have been downloaded of all 6902811 imgs
url = https://farm3.staticflickr.com/3512/4000427904_2188f69db2_o.jpg is finished and 29 imgs have been downloaded of all 6902811 imgs
url = https://farm3.staticflickr.com/1033/604412782_b4460e461d_o.jpg is finished and 30 imgs have been downloaded of all 6902811 imgs
url = https://c4.staticflickr.com/4/3195/2423872879_73261192af_o.jpg is finished and 31 imgs have been downloaded of all 6902811 imgs
url = https://c7.staticflickr.com/9/8437/8003797404_48355074c9_o.jpg is finished and 32 imgs have been downloaded of all 6902811 imgs
url = https://c4.staticflickr.com/3/2114/2273597073_5da2fd4d0f_o.jpg is finished and 33 imgs have been downloaded of all 6902811 imgs
url = https://farm2.staticflickr.com/3077/2902341003_21f3ffcded_o.jpg is finished and 34 imgs have been downloaded of all 6902811 imgs
url = https://c6.staticflickr.com/3/2922/14459983003_72bf109461_o.jpg is finished and 35 imgs have been downloaded of all 6902811 imgs



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


