addpath(genpath(pwd))

%% Load x_train_total_p from file x_HKDES.mat
load('x_HKDES_all.mat')

%% Load data
y_train_total = csvread('Ytr.csv');

%% Cross validation of HKDES features
params = [[850,20,850]; [800,20,800]];

accs = zeros(size(params,1),10);
mean_accs = zeros(size(params,1),1);
%%

for l=1:length(params)
	x_train_cut = x_all(1:5000,[1:params(l,1), 1000+(1:params(l,2)), 1200+(1:params(l,3))]);
    [accs(l,:),mean_accs(l)] = validateHKDES_one_vs_one(x_train_cut, y_train_total, params(l,:));
end

%% Extract best parameters
[best_acc,p] = max(mean_accs(:));
fprintf('Best accuracy (%f) obtained with set of parameters %i',best_acc, p);
disp(params(p,:));
