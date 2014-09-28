% Obtain ImageList & BoundingBoxList & LabelList
BoundingBoxList = importdata('./datasets/CUB_200_2011/list_bounding_boxes.txt');
BoundingBoxList(:,3) = BoundingBoxList(:,1) + BoundingBoxList(:,3)-1; %x2=x1+width
BoundingBoxList(:,4) = BoundingBoxList(:,2) + BoundingBoxList(:,4)-1; %y2=y1+height 
ImageList = importdata('./datasets/CUB_200_2011/list_images.txt'); load('CUB_Regions.mat');
Y_raw = importdata('./datasets/CUB_200_2011/list_image_class_labels.txt');
split = importdata('./datasets/CUB_200_2011/list_train_test_split.txt');

rcnn_model = rcnn_create_model(1,224, './model-defs/VGG_ILSVRC_batch_1_output_fc6.prototxt', './data/caffe_nets/cub_finetune_iter_10000.caffemodel');
rcnn_model = rcnn_load_model(rcnn_model); rcnn_model.detectors.crop_mode = 'wrap'; rcnn_model.detectors.crop_padding = 16;
  
total_time = 0; X_trn = []; Y_trn = []; N_trn = 0; X_tst = []; Y_tst = []; N_tst = 0;
Y = importdata('./datasets/CUB_200_2011/list_image_class_labels.txt');
split = importdata('./datasets/CUB_200_2011/list_train_test_split.txt');

for i = 1:11788
  fprintf('Fine-Grained VGG fc6 Features: %d\n', i);
  tot_th = tic; boxes = BoundingBoxList(i,:);
  im = imread(['./datasets/CUB_200_2011/images/' ImageList{i}]);
  th = tic; features = rcnn_features(im, boxes, rcnn_model);
  fprintf(' [features: %.3fs]\n', toc(th)); total_time = total_time + toc(tot_th);
  fprintf(' [avg time: %.3fs (total: %.3fs)]\n', total_time/i, total_time);
  if split(i,:) == 1
    N_trn = N_trn + 1;
    X_trn(N_trn,:) = features;
    Y_trn(N_trn,:) = Y(i,:);
  else
    N_tst = N_tst + 1;
    X_tst(N_tst,:) = features;
    Y_tst(N_tst,:) = Y(i,:);
  end
end

train_time = tic; model = train(Y_trn,sparse(X_trn),'-s 0');
[Y_hat, accuracy, votes]=predict(Y_tst,sparse(X_tst),model);

Check=votes; Check(:,201)=Y_hat; Check(:,202)=Y_tst; AP=[];
for class=1:200
  tot = 0; ok = 0.0;
  Check = sortrows(Check,-class);
  for i=1:N_tst
    if Check(i,202) == class
       tot = tot + 1; ok = ok + tot/i;
    end
  end
  AP(class) = ok/tot;
end
fprintf(' [time: %.3fs] mAP %f\n', toc(train_time), mean(AP));