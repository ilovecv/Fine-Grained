load('73.9.mat'); [wt,td,E] = plsa([X_trn;X_tst]',129,3); X=td';
model = train(Y_trn,sparse(X(1:5994,:)),'-s 0');
[Y_hat, accuracy, votes]=predict(Y_tst,sparse(X(5995:11788,:)),model);
