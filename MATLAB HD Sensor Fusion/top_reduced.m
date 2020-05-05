clear;

%====Features and Label===
load('input_data.mat')
features=data_all;
f_label_a_binary=data_all(:,215);
f_label_v_binary=data_all(:,216);
met_A_accuracy = zeros(1,8);
met_V_accuracy = zeros(1,8);
for k=1:214
features(:,k)=features(:,k)-min(features(:,k));
end

for k=1:214
 features(:,k)=features(:,k)/max(features(:,k));
end

for i=1:214
 features(:,i)=features(:,i)-0.4;
end

features_GSR=features(:,1:32);
features_ECG=features(:,1+32:32+77); 
features_EEG=features(:,1+32+77:32+77+105); 

%=======HDC============
% HD_functions: uncommented, original functions (has bug)
% HD_functions_modified: early fusion w/bug fix
% HD_functions_commented: late fusion w/comments and w/bug fix 
% HD_functions_parameter_less_tempenc: HD early fusion w/parameter-less temporal encoder
HD_functions_mod_reduced;     % load HD functions
learningrate=0.25; % percentage of the dataset used to train the algorithm
acc_ngram_1=[];
acc_ngram_2=[];


channels_v=length(features_GSR(1,:));
channels_v_ECG=length(features_ECG(1,:));
channels_v_EEG=length(features_EEG(1,:));

channels_a=channels_v;
channels_a_ECG=channels_v_ECG;
channels_a_EEG=channels_v_EEG;

COMPLETE_1_v=features_GSR;
COMPLETE_1_a=features_GSR;
COMPLETE_1_v_ECG=features_ECG;
COMPLETE_1_a_ECG=features_ECG;
COMPLETE_1_v_EEG=features_EEG;
COMPLETE_1_a_EEG=features_EEG;

D_full = [2000]; %dimension of the hypervectors
for j=1:length(D_full)
learningFrac = learningrate(1); 
learningFrac;
D=D_full(j);
D
classes = 2; % level of classes
precision = 20; %no use
ngram = 3; % for temporal encode
maxL = 2; % for IM gen
 
channels_v_EXG=channels_v +channels_v_ECG+channels_v_EEG;
channels_a_EXG=channels_a+channels_a_ECG+channels_a_EEG;


[chAM1, iMch1] = initItemMemories (D, maxL, channels_v);
[chAM2, iMch2] = initItemMemories (D, maxL, channels_a);
[chAM3, iMch3] = initItemMemories (D, maxL, channels_v_ECG);
[chAM4, iMch4] = initItemMemories (D, maxL, channels_a_ECG);
[chAM5, iMch5] = initItemMemories (D, maxL, channels_v_EEG);
[chAM6, iMch6] = initItemMemories (D, maxL, channels_a_EEG);
[chAM7, iMch7] = initItemMemories (D, maxL, channels_v_EXG);
[chAM8, iMch8] = initItemMemories (D, maxL, channels_a_EXG);

%downsample the dataset using the value contained in the variable "downSampRate"
%returns downsampled data which skips every 8 of the original dataset
downSampRate = 8;
LABEL_1_v=f_label_v_binary;
LABEL_1_a=f_label_a_binary;
[TS_COMPLETE_1, L_TS_COMPLETE_1] = downSampling (COMPLETE_1_v, LABEL_1_v, downSampRate);
[TS_COMPLETE_2, L_TS_COMPLETE_2] = downSampling (COMPLETE_1_a, LABEL_1_a, downSampRate);
[TS_COMPLETE_3, L_TS_COMPLETE_3] = downSampling (COMPLETE_1_v_ECG, LABEL_1_v, downSampRate);
[TS_COMPLETE_4, L_TS_COMPLETE_4] = downSampling (COMPLETE_1_a_ECG, LABEL_1_a, downSampRate);
[TS_COMPLETE_5, L_TS_COMPLETE_5] = downSampling (COMPLETE_1_v_EEG, LABEL_1_v, downSampRate);
[TS_COMPLETE_6, L_TS_COMPLETE_6] = downSampling (COMPLETE_1_a_EEG, LABEL_1_a, downSampRate);
reduced_TS_COMPLETE_1 = TS_COMPLETE_1;
reduced_TS_COMPLETE_1(reduced_TS_COMPLETE_1 > 0) = 1;
reduced_TS_COMPLETE_1(reduced_TS_COMPLETE_1 < 0) = 2;
reduced_TS_COMPLETE_2 = TS_COMPLETE_2;
reduced_TS_COMPLETE_2(reduced_TS_COMPLETE_2 > 0) = 1;
reduced_TS_COMPLETE_2(reduced_TS_COMPLETE_2 < 0) = 2;
reduced_TS_COMPLETE_3 = TS_COMPLETE_3;
reduced_TS_COMPLETE_3(reduced_TS_COMPLETE_3 > 0) = 1;
reduced_TS_COMPLETE_3(reduced_TS_COMPLETE_3 < 0) = 2;
reduced_TS_COMPLETE_4 = TS_COMPLETE_4;
reduced_TS_COMPLETE_4(reduced_TS_COMPLETE_4 > 0) = 1;
reduced_TS_COMPLETE_4(reduced_TS_COMPLETE_4 < 0) = 2;
reduced_TS_COMPLETE_5 = TS_COMPLETE_5;
reduced_TS_COMPLETE_5(reduced_TS_COMPLETE_5 > 0) = 1;
reduced_TS_COMPLETE_5(reduced_TS_COMPLETE_5 < 0) = 2;
reduced_TS_COMPLETE_6 = TS_COMPLETE_6;
reduced_TS_COMPLETE_6(reduced_TS_COMPLETE_6 > 0) = 1;
reduced_TS_COMPLETE_6(reduced_TS_COMPLETE_6 < 0) = 2;
reduced_L_TS_COMPLETE_1 = L_TS_COMPLETE_1;
reduced_L_TS_COMPLETE_1(reduced_L_TS_COMPLETE_1 == 1) = 0;
reduced_L_TS_COMPLETE_1(reduced_L_TS_COMPLETE_1 == 2) = 1;
reduced_L_TS_COMPLETE_2 = L_TS_COMPLETE_2;
reduced_L_TS_COMPLETE_2(reduced_L_TS_COMPLETE_2 == 1) = 0;
reduced_L_TS_COMPLETE_2(reduced_L_TS_COMPLETE_2 == 2) = 1;

%Valence
valence_count_class_change = 0;
for i = 1:1:length(LABEL_1_v)-1
    if LABEL_1_v(i) ~= LABEL_1_v(i+1)
        valence_count_class_change = valence_count_class_change+1;
    end
end
%arousal
arousal_count_class_change = 0;
for i = 1:1:length(LABEL_1_a)-1
    if LABEL_1_a(i) ~= LABEL_1_a(i+1)
        arousal_count_class_change = arousal_count_class_change+1;
    end
end
%generate the training matrices using the learning rate contined in the
%variable "learningFrac"
% 1 = v + GSR
% 2 = a + GSR
% 3 = v + ECG
% 4 = a + ECG
% 5 = v + EEG
% 6 = a + EEG
% gen training data finds all the samples corresponding to labels up to 7
% (only see 1 and 2 in the data though). It allocates a certain percentage
% to training data. Then it creates a dataset with labels corresponding to
% the selected data for training. The label dataset is in order from 1-7
% and the data is also stacked one by one so that it is in order from 1-7
[L_SAMPL_DATA_1, SAMPL_DATA_1] = genTrainData (TS_COMPLETE_1, L_TS_COMPLETE_1, learningFrac, 'inorder');
[L_SAMPL_DATA_2, SAMPL_DATA_2] = genTrainData (TS_COMPLETE_2, L_TS_COMPLETE_2, learningFrac, 'inorder');
[L_SAMPL_DATA_3, SAMPL_DATA_3] = genTrainData (TS_COMPLETE_3, L_TS_COMPLETE_3, learningFrac, 'inorder');
[L_SAMPL_DATA_4, SAMPL_DATA_4] = genTrainData (TS_COMPLETE_4, L_TS_COMPLETE_4, learningFrac, 'inorder');
[L_SAMPL_DATA_5, SAMPL_DATA_5] = genTrainData (TS_COMPLETE_5, L_TS_COMPLETE_5, learningFrac, 'inorder');
[L_SAMPL_DATA_6, SAMPL_DATA_6] = genTrainData (TS_COMPLETE_6, L_TS_COMPLETE_6, learningFrac, 'inorder');
reduced_SAMPL_DATA_1 = SAMPL_DATA_1;
reduced_SAMPL_DATA_1(reduced_SAMPL_DATA_1 > 0) = 1;
reduced_SAMPL_DATA_1(reduced_SAMPL_DATA_1 < 0) = 2;
reduced_SAMPL_DATA_2 = SAMPL_DATA_2;
reduced_SAMPL_DATA_2(reduced_SAMPL_DATA_2 > 0) = 1;
reduced_SAMPL_DATA_2(reduced_SAMPL_DATA_2 < 0) = 2;
reduced_SAMPL_DATA_3 = SAMPL_DATA_3;
reduced_SAMPL_DATA_3(reduced_SAMPL_DATA_3 > 0) = 1;
reduced_SAMPL_DATA_3(reduced_SAMPL_DATA_3 < 0) = 2;
reduced_SAMPL_DATA_4 = SAMPL_DATA_4;
reduced_SAMPL_DATA_4(reduced_SAMPL_DATA_4 > 0) = 1;
reduced_SAMPL_DATA_4(reduced_SAMPL_DATA_4 < 0) = 2;
reduced_SAMPL_DATA_5 = SAMPL_DATA_5;
reduced_SAMPL_DATA_5(reduced_SAMPL_DATA_5 > 0) = 1;
reduced_SAMPL_DATA_5(reduced_SAMPL_DATA_5 < 0) = 2;
reduced_SAMPL_DATA_6 = SAMPL_DATA_6;
reduced_SAMPL_DATA_6(reduced_SAMPL_DATA_6 > 0) = 1;
reduced_SAMPL_DATA_6(reduced_SAMPL_DATA_6 < 0) = 2;
reduced_L_SAMPL_DATA_1 = L_SAMPL_DATA_1;
reduced_L_SAMPL_DATA_1(reduced_L_SAMPL_DATA_1 == 1) = 0;
reduced_L_SAMPL_DATA_1(reduced_L_SAMPL_DATA_1 == 2) = 1;
reduced_L_SAMPL_DATA_2 = L_SAMPL_DATA_2;
reduced_L_SAMPL_DATA_2(reduced_L_SAMPL_DATA_2 == 1) = 0;
reduced_L_SAMPL_DATA_2(reduced_L_SAMPL_DATA_2 == 2) = 1;

%Sparse biopolar mapping
%creates matrix of random hypervectors with element values 1, 0, and -1,
%matrix is has feature (channel) numbers of binary D size hypervectors
%Should be the S vectors
q=0.7;
projM1=projBRandomHV(D,channels_v,q);
projM2=projBRandomHV(D,channels_a,q);
projM3=projBRandomHV(D,channels_v_ECG,q);
projM4=projBRandomHV(D,channels_a_ECG,q);
projM5=projBRandomHV(D,channels_v_EEG,q);
projM6=projBRandomHV(D,channels_a_EEG,q);
projM1_neg = projM1;
projM1_pos = projM1;
projM1_neg(projM1_neg==-1) = 0;
projM1_pos(projM1_pos==1) = 0;
projM1_pos(projM1==-1) = 1;
projM2_neg = projM2;
projM2_pos = projM2;
projM2_neg(projM2==-1) = 0;
projM2_pos(projM2==1) = 0;
projM2_pos(projM2==-1) = 1;
projM3_neg = projM3;
projM3_pos = projM3;
projM3_neg(projM3==-1) = 0;
projM3_pos(projM3==1) = 0;
projM3_pos(projM3==-1) = 1;
projM4_neg = projM4;
projM4_pos = projM4;
projM4_neg(projM4==-1) = 0;
projM4_pos(projM4==1) = 0;
projM4_pos(projM4==-1) = 1;
projM5_neg = projM5;
projM5_pos = projM5;
projM5_neg(projM5==-1) = 0;
projM5_pos(projM5==1) = 0;
projM5_pos(projM5==-1) = 1;
projM6_neg = projM6;
projM6_pos = projM6;
projM6_neg(projM6==-1) = 0;
projM6_pos(projM6==1) = 0;
projM6_pos(projM6==-1) = 1;

for N = 3:ngram
% creates ngram for data, rotates through and 
N

% Arousal
%generate ngram bundles for each data stream
fprintf ('HDC for A\n');
%[numpat_2, hdc_model_2] = hdctrainproj (reduced_L_SAMPL_DATA_2, reduced_SAMPL_DATA_2, chAM8, iMch2, D, N, precision, channels_a,projM2_pos,projM2_neg); 
%[numpat_4, hdc_model_4] = hdctrainproj (reduced_L_SAMPL_DATA_2, reduced_SAMPL_DATA_4, chAM8, iMch4, D, N, precision, channels_a_ECG,projM4_pos,projM4_neg); 
%[numpat_6, hdc_model_6] = hdctrainproj (reduced_L_SAMPL_DATA_2, reduced_SAMPL_DATA_6, chAM8, iMch6, D, N, precision, channels_a_EEG,projM6_pos,projM6_neg); 
[numpat, hdc_model_2] = hdctrainproj (classes, reduced_L_SAMPL_DATA_2, reduced_L_SAMPL_DATA_2, reduced_L_SAMPL_DATA_2,reduced_SAMPL_DATA_2, reduced_SAMPL_DATA_4, reduced_SAMPL_DATA_6, chAM8, iMch1, iMch3, iMch5, D, N, precision, channels_a, channels_a_ECG, channels_a_EEG,projM1_pos, projM1_neg, projM3_pos, projM3_neg, projM5_pos, projM5_neg); 

%uncomment following for late fusion
%bundle all the sensors (this is the fusion point)
% %class 1
%hdc_model_2(1)=mode([hdc_model_2(1); hdc_model_4(1); hdc_model_6(1)]);
% %class 2
%hdc_model_2(2)=mode([hdc_model_2(2); hdc_model_4(2); hdc_model_6(2)]);

for i=1:channels_a
iMch8(i)=iMch2(i);
end
for i=channels_a+1:channels_a+channels_a_ECG
iMch8(i)=iMch4(i-channels_a);
end
for i=channels_a+channels_a_ECG+1:channels_a+channels_a_ECG+channels_a_EEG
iMch8(i)=iMch6(i-channels_a-channels_a_ECG);
end

%hdc_model_2 -> hdc_model for early fusion
[acc_ex2, acc2, pl2, al2, all_error] = hdcpredictproj  (reduced_L_TS_COMPLETE_2, reduced_TS_COMPLETE_2, reduced_L_TS_COMPLETE_2, reduced_TS_COMPLETE_4, reduced_L_TS_COMPLETE_2, reduced_TS_COMPLETE_6,hdc_model_2, chAM8, iMch1, iMch3, iMch5, D, N, precision, classes, channels_a,channels_a_ECG,channels_a_EEG, projM1_pos, projM1_neg, projM3_pos, projM3_neg, projM5_pos, projM5_neg);

accuracy(N,2) = acc2;
acc2
 
%acc_ngram_1(N,j)=acc1;
acc_ngram_A(N,j)=acc2;

% Valence

fprintf ('HDC for V\n');
 %[numpat_1, hdc_model_1] = hdctrainproj (reduced_L_SAMPL_DATA_1, reduced_SAMPL_DATA_1, chAM8, iMch1, D, N, precision, channels_v,projM1_pos,projM1_neg); 
 %[numpat_3, hdc_model_3] = hdctrainproj (reduced_L_SAMPL_DATA_1, reduced_SAMPL_DATA_3, chAM8, iMch3, D, N, precision, channels_v_ECG,projM3_pos,projM3_neg); 
 %[numpat_5, hdc_model_5] = hdctrainproj (reduced_L_SAMPL_DATA_1, reduced_SAMPL_DATA_5, chAM8, iMch5, D, N, precision, channels_v_EEG,projM5_pos,projM5_neg); 
 [numpat, hdc_model_1] = hdctrainproj (classes, reduced_L_SAMPL_DATA_1, reduced_L_SAMPL_DATA_1, reduced_L_SAMPL_DATA_1,reduced_SAMPL_DATA_1, reduced_SAMPL_DATA_3, reduced_SAMPL_DATA_5, chAM8, iMch1, iMch3, iMch5, D, N, precision, channels_v, channels_v_ECG, channels_v_EEG,projM1_pos,projM1_neg, projM3_pos,projM3_neg, projM5_pos,projM5_neg); 


%class 1
%hdc_model_1(1)=mode([hdc_model_1(1); hdc_model_3(1); hdc_model_5(1)]);
%class 2
%hdc_model_1(2)=mode([hdc_model_1(2); hdc_model_3(2); hdc_model_5(2)]);

for i=1:channels_v
iMch7(i)=iMch1(i);
end
for i=channels_v+1:channels_v+channels_v_ECG
iMch7(i)=iMch3(i-channels_v);
end
for i=channels_v+channels_v_ECG+1:channels_v+channels_v_ECG+channels_v_EEG
iMch7(i)=iMch5(i-channels_v-channels_v_ECG);
end

%hdc_model_1 -> hdc_model for early fusion
[acc_ex1, acc1, pl1, al1, all_error] = hdcpredictproj  (reduced_L_TS_COMPLETE_1, reduced_TS_COMPLETE_1, reduced_L_TS_COMPLETE_1, reduced_TS_COMPLETE_3, reduced_L_TS_COMPLETE_1, reduced_TS_COMPLETE_5,hdc_model_1, chAM8, iMch1, iMch3, iMch5, D, N, precision, classes, channels_v,channels_v_ECG,channels_v_EEG,projM1_pos,projM1_neg,projM3_pos,projM3_neg,projM5_pos,projM5_neg);
%for verification
%[acc_ex1, acc1, pl1, al1, all_error] = hdcpredictproj  (L_SAMPL_DATA_1, SAMPL_DATA_1, L_SAMPL_DATA_3, SAMPL_DATA_3, L_SAMPL_DATA_5, SAMPL_DATA_5,hdc_model, chAM8, iMch1, iMch3, iMch5, D, N, precision, classes, channels_v,channels_v_ECG,channels_v_EEG,projM1,projM3,projM5);

accuracy(N,2) = acc1;
acc1

%acc_ngram_1(N,j)=acc1;
acc_ngram_V(N,j)=acc1;
end

for i = 1:1:length(1:ngram)
    if acc_ngram_A(i,j) > 0.684
        met_A_accuracy(j) = 1;
    else
        
    end
    if acc_ngram_V(i,j) > 0.801
        met_V_accuracy(j) = 1;
    end
end

end

iMfull = [];
for i = 1:1:iMch7.Count
    iMfull = [iMfull iMch7(i)]; %#ok<AGROW>
end

projM_pos_full = [];
projM_pos_temp = [projM1_pos; projM3_pos; projM5_pos];
x = size(projM_pos_temp);
dim = x(1);
for i = 1:1:dim
    projM_pos_full = [projM_pos_full projM_pos_temp(i,:)]; %#ok<AGROW>
end

projM_neg_full = [];
projM_neg_temp = [projM1_neg; projM3_neg; projM5_neg];
x = size(projM_neg_temp);
dim = x(1);
for i = 1:1:dim
    projM_neg_full = [projM_neg_full projM_neg_temp(i,:)]; %#ok<AGROW>
end

