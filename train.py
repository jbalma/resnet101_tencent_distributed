from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

"""
Tencent is pleased to support the open source community by making Tencent ML-Images available.
Copyright (C) 2018 THL A29 Limited, a Tencent company. All rights reserved.
Licensed under the BSD 3-Clause License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
https://opensource.org/licenses/BSD-3-Clause
Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
"""


"""Runs a ResNet model on the ImageNet dataset."""
import os
import sys
import math
import numpy as np
import tensorflow as tf
import horovod.tensorflow as hvd
from data_processing import dataset as file_db
from data_processing import image_preprocessing as image_preprocess
from models import resnet as resnet
from flags import FLAGS


#hvd.init()
def _parse_function(parsed, im_shape, chan):
  #image_string = tf.read_file(filename)
  image = tf.reshape(parsed['image'],shape=im_shape)
  image_decoded = tf.cond(
             tf.image.is_jpeg(image),
             lambda: tf.image.decode_jpeg(image, channels=chan),
             lambda: tf.image.decode_png(image, channels=chan))
  image_resized = tf.image.resize_images(image_decoded, [226,226])
  return image_resized  


def record_parser_fn(value, is_training):
  """Parse an image record from `value`."""
  keys_to_features = {
          'width': tf.FixedLenFeature([], dtype=tf.int64, default_value=0),
          'height': tf.FixedLenFeature([], dtype=tf.int64, default_value=0),
          'image': tf.FixedLenFeature([], dtype=tf.string, default_value=''),
          'label': tf.FixedLenFeature([], dtype=tf.string, default_value=''),
          'name': tf.FixedLenFeature([], dtype=tf.string, default_value='')
  }

  parsed = tf.parse_single_example(value, keys_to_features)
  
  #image = tf.image.decode_image(tf.reshape(parsed['image'], shape=[]),
  #    FLAGS.image_channels)
  image = _parse_function(parsed, im_shape=[], chan=FLAGS.image_channels)
  image = tf.image.convert_image_dtype(image, dtype=tf.float32)
  
  bbox = tf.concat(axis=0, values=[ [[]], [[]], [[]], [[]] ])
  bbox = tf.transpose(tf.expand_dims(bbox, 0), [0, 2, 1])
  image = image_preprocess.preprocess_image(
      image=image,
      output_height=FLAGS.image_size,
      output_width=FLAGS.image_size,
      object_cover=0.7, 
      area_cover=0.7,
      is_training=is_training,
      bbox=bbox)

  label = tf.reshape(tf.decode_raw(parsed['label'], tf.float32), shape=[FLAGS.class_num,])

  return image, label

def synth_parser_fn(value, is_training):

    if FLAGS.data_format == 'NCHW':
      image_shape = [3, FLAGS.image_size + 3, FLAGS.image_size + 3]
    else:
      image_shape = [FLAGS.image_size + 3, FLAGS.image_size + 3, 3]


    keys_to_features = {
          'width': tf.FixedLenFeature([], dtype=tf.int64, default_value=0),
          'height': tf.FixedLenFeature([], dtype=tf.int64, default_value=0),
          'image': tf.FixedLenFeature([], dtype=tf.string, default_value=''),
          'label': tf.FixedLenFeature([], dtype=tf.string, default_value=''),
          'name': tf.FixedLenFeature([], dtype=tf.string, default_value='')
    }

    parsed = tf.parse_single_example(value, keys_to_features)

    #image = tf.image.decode_image(tf.reshape(parsed['image'], shape=[]),
    #    FLAGS.image_channels)
    image = _parse_function(parsed, im_shape=[], chan=FLAGS.image_channels)
    image = tf.image.convert_image_dtype(image, dtype=tf.float32)
    
    bbox = tf.concat(axis=0, values=[ [[]], [[]], [[]], [[]] ])
    bbox = tf.transpose(tf.expand_dims(bbox, 0), [0, 2, 1])
    image = image_preprocess.preprocess_image(
        image=image,
        output_height=FLAGS.image_size,
        output_width=FLAGS.image_size,
        object_cover=0.7,
        area_cover=0.7,
        is_training=is_training,
        bbox=bbox)

    #images = tf.Variable(tf.random_normal(image_shape,
    #                                      dtype=tf.float32,
    #                                      stddev=1e-1))
    #label_shape = [FLAGS.class_num,]
    #label = tf.Variable(tf.random_normal(label_shape,
    #                                      dtype=tf.float32,
    #                                      stddev=1e-1))
    #label_tensor=np.random.rand(100, 64, 64, 3).astype(np.float32)
    label = tf.reshape(tf.cast(tf.random_uniform([1], minval=0, maxval=FLAGS.class_num, dtype=tf.int8, seed=None, name=None),dtype=tf.float32), shape=[FLAGS.class_num,])
    return image, label 

def input_synth_fn(is_training, batch_size, num_epochs=1):

  if FLAGS.data_format == 'NCHW':
    image_shape = [100, FLAGS.batch_size, 3, FLAGS.image_size + 3, FLAGS.image_size + 3]
  else:
    image_shape = [100, FLAGS.batch_size, FLAGS.image_size + 3, FLAGS.image_size + 3, 3]

  np.random.seed(42)
  tf.set_random_seed(42)
  images = np.random.rand(image_shape[0], image_shape[1], image_shape[2], image_shape[3], image_shape[4]).astype(np.float32)

  #def get_data():
  #labels = np.random.rand(image_shape[0], FLAGS.class_num, ).astype(np.int8)
  labels = [image_shape[0], tf.cast(tf.random_uniform([FLAGS.class_num], minval=0, maxval=1, dtype=tf.int64, seed=None, name=None),dtype=tf.float32)]

  dataset = tf.data.Dataset.from_tensor_slices([images,labels])  # some initial dataset
  # ONLY DIFFERENCE IS THE BELOW LINE:
  dataset = dataset.map(lambda image: tf.image.random_hue(image, 0.04, seed=42), num_parallel_calls=1)
  # ONLY DIFFERENCE IS THE ABOVE LINE ^^^:
  #dataset = dataset.batch(batch_size)
  #x = dataset.make_one_shot_iterator().get_next()

  worker_id = hvd.rank()
  worker_num = hvd.size()


  # divide the dataset
  if is_training:
    dataset = dataset.shuffle(buffer_size=FLAGS.file_shuffle_buffer, seed=worker_num)
    dataset = dataset.shard(worker_num, worker_id)

  #dataset = dataset.flat_map(tf.data.TFRecordDataset)
  #dataset = dataset.map(lambda value: synth_parser_fn(value, is_training),
  #                       num_parallel_calls=1)
  dataset = dataset.prefetch(batch_size)

  if is_training:
    # When choosing shuffle buffer sizes, larger sizes result in better
    # randomness, while smaller sizes have better performance.
    # dataset = dataset.shuffle(buffer_size=_SHUFFLE_BUFFER, seed=worker_id)
    dataset = dataset.shuffle(buffer_size=FLAGS.shuffle_buffer)

    # We call repeat after shuffling, rather than before, to prevent separate
    # epochs from blending together.
    dataset = dataset.repeat()

  dataset = dataset.batch(batch_size)
  iterator = dataset.make_one_shot_iterator()
  images, labels = iterator.get_next()
  return images, labels


def input_fn(is_training, data_dir, batch_size, num_epochs=1):
  """Input function which provides batches for train or eval."""
  dataset = None
  if is_training:
    dataset = file_db.Dataset(os.path.join(data_dir, 'train'),record_pattern='*')
  else:
    dataset = file_db.Dataset(os.path.join(data_dir, 'val'),record_pattern='*')

  worker_id = 0 #hvd.rank()
  worker_num = 1 #hvd.size()

  dataset = tf.data.Dataset.from_tensor_slices(dataset.data_files())

  # divide the dataset
  if is_training:
    dataset = dataset.shuffle(buffer_size=FLAGS.file_shuffle_buffer, seed=worker_num)
    dataset = dataset.shard(worker_num, worker_id)

  dataset = dataset.flat_map(tf.data.TFRecordDataset)
  dataset = dataset.map(lambda value: record_parser_fn(value, is_training),
                         num_parallel_calls=1) 
  dataset = dataset.prefetch(batch_size)

  if is_training:
    # When choosing shuffle buffer sizes, larger sizes result in better
    # randomness, while smaller sizes have better performance.
    # dataset = dataset.shuffle(buffer_size=_SHUFFLE_BUFFER, seed=worker_id)
    dataset = dataset.shuffle(buffer_size=FLAGS.shuffle_buffer)

    # We call repeat after shuffling, rather than before, to prevent separate
    # epochs from blending together.
    dataset = dataset.repeat()

  dataset = dataset.batch(batch_size)
  iterator = dataset.make_one_shot_iterator()
  images, labels = iterator.get_next()
  return images, labels

def resnet_model_fn(features, labels, mode, params):
  """Our model_fn for ResNet to be used with our Estimator."""
  #tf.summary.image('images', features, max_outputs=6)

  # build model
  net = resnet.ResNet(features, is_training=(mode == tf.estimator.ModeKeys.TRAIN))
  logits = net.build_model() 
  predictions = {
      'classes': tf.argmax(logits, axis=1),
      'probabilities': tf.nn.softmax(logits, name='softmax_tensor')
  }

  if mode == tf.estimator.ModeKeys.PREDICT:
    return tf.estimator.EstimatorSpec(mode=mode, predictions=predictions)

  # Calculate loss, which includes softmax cross entropy and L2 regularization.
  # a. get loss coeficiente
  pos_mask = tf.reduce_sum(
               tf.cast(
                 tf.greater_equal(
                   labels, tf.fill(tf.shape(labels), FLAGS.mask_thres)), 
                   tf.float32), 
             0)
  pos_curr_count = tf.cast(tf.greater(   pos_mask, 0), tf.float32)
  neg_curr_count = tf.cast(tf.less_equal(pos_mask, 0), tf.float32)
  pos_count = tf.Variable(tf.zeros(shape=[FLAGS.class_num,]),  trainable=False)
  neg_count = tf.Variable(tf.zeros(shape=[FLAGS.class_num,]),  trainable=False)
  neg_select = tf.cast(
                 tf.less_equal(
                    tf.random_uniform(
                      shape=[FLAGS.class_num,], 
                      minval=0, maxval=1,
                      seed = FLAGS.random_seed),
                    FLAGS.neg_select), 
                 tf.float32)
  #tf.compat.v1.summary.histogram('pos_curr_count', pos_curr_count)
  #tf.compat.v1.summary.histogram('neg_curr_count', neg_curr_count)
  #tf.compat.v1.summary.histogram('neg_select', neg_select)
  with tf.control_dependencies([pos_curr_count, neg_curr_count, neg_select]):
    pos_count = tf.assign_sub(
                   tf.assign_add(pos_count, pos_curr_count),
                   tf.multiply(pos_count, neg_curr_count))
    neg_count = tf.assign_sub(
                   tf.assign_add(neg_count, tf.multiply(neg_curr_count, neg_select)),
                   tf.multiply(neg_count, pos_curr_count))
    #tf.compat.v1.summary.histogram('pos_count', pos_count)
    #tf.compat.v1.summary.histogram('neg_count', neg_count)
  pos_loss_coef = -1 * (tf.log((0.01 + pos_count)/10)/tf.log(10.0))
  pos_loss_coef = tf.where(
                    tf.greater(pos_loss_coef, tf.fill(tf.shape(pos_loss_coef), 0.01)),
                    pos_loss_coef,
                    tf.fill(tf.shape(pos_loss_coef), 0.01))
  pos_loss_coef = tf.multiply(pos_loss_coef, pos_curr_count)
  #tf.compat.v1.summary.histogram('pos_loss_coef', pos_loss_coef)
  neg_loss_coef = -1 * (tf.log((8 + neg_count)/10)/tf.log(10.0))
  neg_loss_coef = tf.where(
                   tf.greater(neg_loss_coef, tf.fill(tf.shape(neg_loss_coef), 0.01)),
                   neg_loss_coef,
                   tf.fill(tf.shape(neg_loss_coef), 0.001))
  neg_loss_coef = tf.multiply(neg_loss_coef, tf.multiply(neg_curr_count, neg_select))
  #tf.compat.v1.summary.histogram('neg_loss_coef', neg_loss_coef)
  loss_coef = tf.add(pos_loss_coef, neg_loss_coef)
  #tf.compat.v1.summary.histogram('loss_coef', loss_coef)

  # b. get non-negative mask
  non_neg_mask = tf.fill(tf.shape(labels), -1.0, name='non_neg')
  non_neg_mask = tf.cast(tf.not_equal(labels, non_neg_mask), tf.float32)
  #tf.compat.v1.summary.histogram('non_neg', non_neg_mask)

  # cal loss
  cross_entropy = tf.nn.weighted_cross_entropy_with_logits(
       logits=logits, labels=labels, pos_weight=12, name='sigmod_cross_entropy')
  #tf.compat.v1.summary.histogram('sigmod_ce', cross_entropy)
  cross_entropy_cost = tf.reduce_sum(tf.reduce_mean(cross_entropy * non_neg_mask, axis=0) * loss_coef)

  # Create a tensor named cross_entropy for logging purposes.
  tf.identity(cross_entropy_cost, name='cross_entropy')
  #tf.summary.scalar('cross_entropy', cross_entropy_cost)
  #tf.compat.v1.summary.scalar('cross_entropy', cross_entropy_cost)

  # Add weight decay to the loss. We exclude the batch norm variables because
  # doing so leads to a small improvement in accuracy.
  loss = cross_entropy_cost + FLAGS.weight_decay * tf.add_n(
    [tf.nn.l2_loss(v) for v in tf.trainable_variables() if 'batch_normalization' not in v.name])

  if mode == tf.estimator.ModeKeys.TRAIN:
    # Scale the learning rate linearly with the batch size. When the batch size
    # is 256, the learning rate should be 0.1.
    lr_warmup = FLAGS.lr_warmup
    warmup_step = FLAGS.warmup
    warmup_decay_step = FLAGS.lr_warmup_decay_step
    warmup_decay_factor = FLAGS.lr_warmup_decay_factor
    #global_step = tf.train.get_or_create_global_step()
    global_step = tf.compat.v1.train.get_or_create_global_step()
    boundaries = [
        int(FLAGS.lr_decay_step * epoch) for epoch in [1, 2, 3, 4]]
    values = [
        FLAGS.lr * decay for decay in [1, 0.1, 0.01, 1e-3, 1e-4]]
    #learning_rate = tf.train.piecewise_constant(
    learning_rate = tf.compat.v1.train.piecewise_constant(
        tf.cast(global_step, tf.int32), boundaries, values)

    # Linear Scaling Rule and Gradual Warmup 
    lr = tf.cond(
                global_step < warmup_step,
                #lambda: tf.train.exponential_decay(
                lambda: tf.compat.v1.train.exponential_decay(
                    lr_warmup, 
                    global_step,
                    warmup_decay_step,
                    warmup_decay_factor,
                    staircase=True
                    ),
                lambda: learning_rate
                )

    # Create a tensor named learning_rate for logging purposes.
    tf.identity(lr, name='learning_rate')
    #tf.summary.scalar('learning_rate', lr)
    #tf.compat.v1.summary.scalar('learning_rate', lr)


    #optimizer = tf.train.MomentumOptimizer(
    #    learning_rate=lr,
    #    momentum=FLAGS.opt_momentum)
    optimizer = tf.compat.v1.train.MomentumOptimizer(
        learning_rate=lr,
        momentum=FLAGS.opt_momentum)

    optimizer = hvd.DistributedOptimizer(optimizer)#, device_sparse='/cpu:0')
    # Batch norm requires update_ops to be added as a train_op dependency.
    update_ops = tf.get_collection(tf.GraphKeys.UPDATE_OPS)
    with tf.control_dependencies(update_ops):
      train_op = optimizer.minimize(loss, global_step)
  else:
    train_op = None

  # Build evaluate metrics
  accuracy = tf.metrics.accuracy(
      tf.argmax(labels, axis=1), predictions['classes'])
  metrics = {'accuracy': accuracy}
  tf.identity(accuracy[1], name='train_accuracy')
  #tf.summary.scalar('train_accuracy', accuracy[1])
  #tf.compat.v1.summary.scalar('train_accuracy', accuracy[1])


  return tf.estimator.EstimatorSpec(
      mode=mode,
      predictions=predictions,
      loss=loss,
      train_op=train_op,
      eval_metric_ops=metrics)

def main(_):
  # Using the Winograd non-fused algorithms provides a small performance boost.
  os.environ['TF_ENABLE_WINOGRAD_NONFUSED'] = '1'

  # Horovod: initialize Horovod.
  hvd.init()

  # Horovod: pin GPU to be used to process local rank (one GPU per process)
  #config.gpu_options.per_process_gpu_memory_fraction
  
  config = tf.ConfigProto(inter_op_parallelism_threads=int(os.getenv('OMP_NUM_THREADS')),intra_op_parallelism_threads=0) #, device_count = {'CPU': 18})
  if(0):
  
        #session config
        config=tf.ConfigProto(inter_op_parallelism_threads=1,
                                   intra_op_parallelism_threads=1,
                                   log_device_placement=False,
                                   allow_soft_placement=False)
        if (tf.test.is_built_with_cuda()):
            config=tf.ConfigProto(log_device_placement=False,
                                       allow_soft_placement=True)

        #plugin additions
        if (tf.test.is_built_with_cuda()):
            print("%%%%%%%%%%%%%%%% RANK " + str(hvd.rank()) + " %%%%%%%%%%%%%% USING GPU " + str(hvd.local_rank()) +" %%%%")
            config.gpu_options.visible_device_list = str(hvd.local_rank())
            config.gpu_options.per_process_gpu_memory_fraction = 0.7
        #hooks = [hvd.BroadcastGlobalVariablesHook(0)]

  #config.gpu_options.allow_growth = True 
  #config.intra_op_parallelism_threads = 0
  #config.inter_op_parallelism_threads = 0
  #config.gpu_options.visible_device_list = str(hvd.local_rank())
  #sess = tf.Session(config=config)
  #K.set_session(tf.Session(config=config))
  #FLAGS.snapshot = FLAGS.snapshot if hvd.rank() == 0 else 0
  model_path = FLAGS.model_dir if hvd.rank() == 0 else None
  max_ckp_num = (FLAGS.max_to_keep)
  log_interval = FLAGS.log_interval if hvd.rank()==0 else None
  run_config = tf.estimator.RunConfig(save_checkpoints_steps=FLAGS.snapshot,
                                      keep_checkpoint_max=max_ckp_num,
                                      session_config=config,
                                      save_summary_steps=0)

  resnet_classifier = tf.estimator.Estimator(
      model_fn=resnet_model_fn, 
      model_dir=model_path, 
      config=run_config,
      params={
          'resnet_size': FLAGS.resnet_size,
          'data_format': FLAGS.data_format,
          'batch_size': FLAGS.batch_size,
      }
  )
  tensors_to_log = {
      'learning_rate': 'learning_rate',
      'cross_entropy': 'cross_entropy',
      'train_accuracy': 'train_accuracy'
  }

  #if hvd.rank()!=0:
  #tensors_to_log = {}

  logging_hook = tf.train.LoggingTensorHook(
      tensors=tensors_to_log, every_n_iter=100000000, at_end=True)

  print('Total run steps = {}'.format(FLAGS.max_iter))

  
  #jbalma added broadcast
  bcast_hook = hvd.BroadcastGlobalVariablesHook(0)
  hook_list = [logging_hook,bcast_hook]
  #tf.get_default_session().run(hvd.broadcast_global_variables(0))
  #hook_list = []
  #if hvd.rank() == 0:
    #hook_list.append(keras.callbacks.ModelCheckpoint('./checkpoint-{epoch}.h5'))
    #hook_list.append(logging_hook)
  if(1):
      tencent_input_fn = lambda: input_fn(True, FLAGS.data_dir, FLAGS.batch_size)
  else: 
      tencent_input_fn = lambda: input_synth_fn(True, FLAGS.batch_size)

  resnet_classifier.train(
    input_fn=tencent_input_fn,
    steps=FLAGS.max_iter,
    hooks=hook_list
  )

if __name__ == '__main__':
  tf.logging.set_verbosity(tf.logging.INFO)
  tf.app.run()
