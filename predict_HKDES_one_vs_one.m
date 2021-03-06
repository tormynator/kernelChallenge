addpath(genpath(pwd))

%% Load Data

x_test = csvread('Xte.csv');
x_test = x_test(:,1:end-1);
x_train_total = csvread('Xtr.csv');
x_train_total = x_train_total(:,1:end-1);
y_train_total = csvread('Ytr.csv');

%Moving input data to grayscale
x_train_total = reshape(x_train_total, [5000,1024,3]);
x_train_total = mean(x_train_total,3);

%Moving input data to grayscale
x_test = reshape(x_test, [2000,1024,3]);
x_test = mean(x_test,3);

%x = [x_train_total; x_test];

% Preprocess data
%[x_patches_all, x_statistics_all] = processKDES(x,5,3,6,2,0.8,0.2,8,2,200,50,200);
%save('x_all.mat','x_patches_all');
%save('x_statistics_all.mat','x_statistics_all');

%[X_G,X_C,X_S] = create_basis(x_patches_all,8,2,200,50,200,1000);
%save('x_basis_all.mat', 'X_G','X_C','X_S');

%x_all = processHKDES(x_patches_all,x_statistics_all,X_G,X_C,X_S,1,1,1,1,0.5,8,2,1000,200,1000);
%save('x_HKDES_all.mat', 'x_all');

%Load features
load('x_HKDES_all.mat');

%% Select features
n_features = [750,20,750];

x_train_cut = x_all(1:size(x_train_total,1),[1:n_features(1), 1000+(1:n_features(2)), 1200+(1:n_features(3))]);
x_test_cut = x_all(size(x_train_total,1)+(1:size(x_test,1)),[1:n_features(1), 1000+(1:n_features(2)), 1200+(1:n_features(3))]);

%% Kernel

gram_train = x_train_cut*x_train_cut';
gram_test = x_train_cut*x_test_cut';
C = 1;

%% Train SVM

addpath ./SVM

% train one-against-one models
numLabels = length(unique(y_train_total(:,2)));
model_diy = cell(numLabels*(numLabels-1)/2,1);
model_index = zeros(numLabels*(numLabels-1)/2,2);
i = 1;
for k=1:numLabels
    for l=k+1:numLabels
        model_index(i,:) = [k,l];
        i = i+1;
    end
end

parfor i=1:size(model_index,1)
    k = model_index(i,1);
    l = model_index(i,2);
    fprintf('Computing SVM for class %i vs %i\n',k-1,l-1);
    selection = (y_train_total(:,2) == k-1) | (y_train_total(:,2) == l-1);
    index = (1:size(y_train_total,1));
    index = index(selection);
    gram_train_partial = gram_train(index,index);
    y_train_partial = y_train_total(index,:);
    y_bin = zeros(size(y_train_partial,1),1);
    y_bin(y_train_partial(:,2)==k-1)=1;
    y_bin(y_train_partial(:,2)==l-1)=-1;
    [alpha_y, bias] = fitcsvm_kernel(gram_train_partial, y_bin, C);
    [A, B] = fit_svm_posterior(gram_train_partial, y_bin, C, 4);
    model_diy{i}.alpha_y = alpha_y;
    model_diy{i}.bias = bias;
    model_diy{i}.A = A;
    model_diy{i}.B = B;
end

%% Get the posterior probability matrix for the predictions

% get probability estimates of test instances using each model
numTest = size(x_test_cut,1);
prob_diy = zeros(numTest,numLabels,numLabels);
for i=1:size(model_index,1)
    k = model_index(i,1);
    l = model_index(i,2);
    fprintf('Computing posteriors for class %i vs %i\n',k-1,l-1);
    selection = (y_train_total(:,2) == k-1) | (y_train_total(:,2) == l-1);
    index = (1:size(y_train_total,1));
    index = index(selection);
    [~, score] = predict_svm(gram_test(index,:), model_diy{i}.alpha_y, model_diy{i}.bias);
    post_proba = get_posterior(score, model_diy{i}.A, model_diy{i}.B);
    prob_diy(:,k,l) = post_proba(:,1)>0.5;    %# probability of class==k
    prob_diy(:,l,k) = post_proba(:,1)<=0.5;
end

%% Do the prediction

% predict the class with the max vote
[~,pred] = max(sum(prob_diy,3),[],2);
pred_diy = pred-1;
pred_diy = [(1:numTest)' pred_diy];

% write prediction to file
path = './results/Yte_HKDES_750_20_750_C1_1vs1.csv';
csvfile = fopen(path,'w');
fprintf(csvfile,'Id,Prediction\n');
fclose(csvfile);
dlmwrite (path, pred_diy, '-append');
