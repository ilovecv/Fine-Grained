% Obtain ImageList & BoundingBoxList & LabelList
BoundingBoxList = importdata('./datasets/CUB_200_2011/list_bounding_boxes.txt');
BoundingBoxList(:,3) = BoundingBoxList(:,1) + BoundingBoxList(:,3)-1; %x2=x1+width
BoundingBoxList(:,4) = BoundingBoxList(:,2) + BoundingBoxList(:,4)-1; %y2=y1+height 
ImageList = importdata('./datasets/CUB_200_2011/list_images.txt'); load('CUB_Regions.mat');
Y_raw = importdata('./datasets/CUB_200_2011/list_image_class_labels.txt');
split = importdata('./datasets/CUB_200_2011/list_train_test_split.txt');

for iter=4:4
  rcnn_model = rcnn_create_model(32,'./model-defs/CUB_batch_32_output_fc6.prototxt', ['./data/caffe_nets/cub_finetune_train_iter_' num2str(iter*10000)]);
  rcnn_model = rcnn_load_model(rcnn_model); rcnn_model.detectors.crop_mode = 'wrap'; rcnn_model.detectors.crop_padding = 16;

%Extract CNN_pool6_features for CUB_200_2011
%  for i = 1:11788
%    boxes = BoundingBoxList(i,:);
%    im = imread(['./datasets/CUB_200_2011/images/' ImageList{i}]);
%    X(i,:) = rcnn_features(im, boxes, rcnn_model);
%  end

  X_trn = []; Y_trn = []; N_trn = 0; X_tst = []; Y_tst = []; N_tst = 0; N_ROI = 32; K_means = 3;
  for i = 1:11788
    fprintf('%s: CNN Feature: #%d\n', procid(), i);
    for j=1:N_ROI
      boxes(j,1)=Regions(i,j,1);
      boxes(j,2)=Regions(i,j,2);
      boxes(j,3)=Regions(i,j,3);
      boxes(j,4)=Regions(i,j,4);
    end
    im = imread(['./datasets/CUB_200_2011/images/' ImageList{i}]); label = Y_raw(i,:);
    features = rcnn_features(im, boxes, rcnn_model)';
    [means, covariances, priors] = vl_gmm(features,K_means);
    feat = vl_fisher(features, means, covariances, priors)'; 
    if split(i,:) == 1
      N_trn = N_trn + 1;
      X_trn(N_trn,:)=feat;
      Y_trn(N_trn,:)=label;
    else
      N_tst = N_tst + 1;
      X_tst(N_tst,:)=feat;
      Y_tst(N_tst,:)=label;
    end
  end

%Train and test LibLinearSVM
  model = train(Y_trn,sparse(X_trn));
  [Y_hat,accuracy, votes]=predict(Y_tst,sparse(X_tst),model);

%Calculate mAP
  Check=votes; Check(:,201)=Y_hat; Check(:,202)=Y_tst; AP=[];
  for class=1:200
    tot = 0;
    ok = 0.0;
    Check = sortrows(Check,-class);
    for i=1:N_tst
      if Check(i,202) == class
         tot = tot + 1;
         ok = ok + tot/i;
      end
    end
    AP(class) = ok/tot;
  end
  fprintf('#iter %d: mAP %f\n', iter,mean(AP));
end
