%% Connect to Database
mysqlStatus = mysql('status')
if mysqlStatus == 1 % 1 means not connected
    username = input('Username?')
    password = input('Password?')
    mysql('open', 'mysql', username,password)
    mysql('show databases')
    mysql('USE EddyTickling')
end



%load data, experiment IDs are here the same as session IDs
ratIDs = [101 102];
sessionIDs=[];
for i = 1:length(ratIDs)
sessionIDs{i} = mysql(sprintf('SELECT experiment_id FROM Experiments WHERE rat_id = (''%s'')',num2str(ratIDs(i))))
end

%% get all data from all session IDs
% 50kHz
% allSessionIDs = vertcat(sessionIDs{:});
allSessionIDs = [101001 101014];
% allSessionIDs = [151003];

centsWithoutNaN = [];
freqValuesWithoutNaN = [];
freqDiffValuesWithoutNaN = [];

onlyCombined = input('do you want to analyze only combined USVs? 1 = yes, 0 = no');
for i = 1:length(allSessionIDs)
    if onlyCombined == 1
    centsCur = mysql(sprintf('SELECT cents FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''co''',num2str(allSessionIDs(i))));
    freqValuesCur = mysql(sprintf('SELECT freqValues FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''co''',num2str(allSessionIDs(i))));
    freqDiffValuesCur = mysql(sprintf('SELECT freqDiffValues FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''co''',num2str(allSessionIDs(i))));
    else
    centsCur = mysql(sprintf('SELECT cents FROM spectralAnalysis WHERE session_id = (''%s'') ',num2str(allSessionIDs(i))));
    freqValuesCur = mysql(sprintf('SELECT freqValues FROM spectralAnalysis WHERE session_id = (''%s'') ',num2str(allSessionIDs(i))));
    freqDiffValuesCur = mysql(sprintf('SELECT freqDiffValues FROM spectralAnalysis WHERE session_id = (''%s'') ',num2str(allSessionIDs(i))));
    end
    centIdcsWithoutNaNCur = find(isnan(centsCur));
    centsCur(centIdcsWithoutNaNCur) = [];
    centsWithoutNaN{i} = centsCur;
    
    freqValuesIdcsWithoutNaNCur = find(isnan(freqValuesCur));
    freqValuesCur(freqValuesIdcsWithoutNaNCur) = [];
    freqValuesWithoutNaN{i} = freqValuesCur;
    
    freqDiffValuesIdcsWithoutNaNCur = find(isnan(freqDiffValuesCur));
    freqDiffValuesCur(freqDiffValuesIdcsWithoutNaNCur) = [];
    freqDiffValuesWithoutNaN{i} = freqDiffValuesCur;
    
end
%% get all data from all session IDs1
% 22kHz
% allSessionIDs = [151001 151002 151004];
allSessionIDs = [151001 151002 151004];

onlyFirstUSVofBursts = input('do you want to analyse only first USVs of bursts? 1 = yes; 0 = no');
if onlyFirstUSVofBursts==1
    timeBetweenUSVs = input('how much time should be between USVs? (in seconds)');
% load only first calls of a call burst
for i = 1:length(allSessionIDs)
USVstart_times = mysql(sprintf('SELECT nlx_time FROM USVs WHERE experiment_id = (%s) AND call_type_id = ''11'' ',num2str(allSessionIDs(i))));
USVduration_times{i} = mysql(sprintf('SELECT duration FROM USVs WHERE experiment_id = (%s) AND call_type_id = ''11'' ',num2str(allSessionIDs(i))));
USVend_times = USVstart_times+USVduration_times{i};
USVstart_times = sort(USVstart_times);
USVend_times = sort(USVend_times);
USV_IDs{i} = mysql(sprintf('SELECT USV_ID_spectralAnalysis FROM USVs WHERE experiment_id = (%s) AND call_type_id = ''11'' ',num2str(allSessionIDs(i))));
USV_IDs{i} = sort(USV_IDs{i});
firstCallOfBurstIdxWithoutVeryFirst = find(USVstart_times(2:end)-USVend_times(1:end-1)>timeBetweenUSVs)+1;
firstCallOfBurstIdx{i} = vertcat(1,firstCallOfBurstIdxWithoutVeryFirst);
% USV_times(firstCallOfBurstIdx)%for checking if correct calls are selected
% allUSV_ids = mysql(sprintf('SELECT USV_ID_spectralAnalysis FROM USVs WHERE experiment_id = (%s)',num2str(allSessionIDs)));
% firstUSVsofBurst_IDs = allUSV_ids(firstCallOfBurstIdx);
end
end
%analyse
centsWithoutNaN = [];
freqValuesWithoutNaN = [];
freqDiffValuesWithoutNaN = [];
for i = 1:length(allSessionIDs)
%     centsCur = mysql(sprintf('SELECT cents FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''fc''',num2str(allSessionIDs(i))));
%     freqValuesCur = mysql(sprintf('SELECT freqValues FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''fc''',num2str(allSessionIDs(i))));
%     freqDiffValuesCur = mysql(sprintf('SELECT freqDiffValues FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''fc''',num2str(allSessionIDs(i))));
for k = 1:length(USV_IDs{i})
    USV_IDsCur = USV_IDs{i};
    centsCur = mysql(sprintf('SELECT cents FROM spectralAnalysis WHERE session_id = (''%s'') AND USV_ID = (%d) AND callType = ''fc'' ',num2str(allSessionIDs(i)),USV_IDsCur(k)));
    centsWithoutNaNCur(k) = centsCur(find(~isnan(centsCur)));
end
    freqValuesCur = mysql(sprintf('SELECT freqValues FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''fc'' ',num2str(allSessionIDs(i))));
    freqDiffValuesCur = mysql(sprintf('SELECT freqDiffValues FROM spectralAnalysis WHERE session_id = (''%s'') AND callType = ''fc'' ',num2str(allSessionIDs(i))));

%     centIdcsWithoutNaNCur = find(isnan(centsCur));
%     centsCur(centIdcsWithoutNaNCur) = [];
%     if onlyFirstUSVofBursts==1
        centsWithoutNaN{i} = centsWithoutNaNCur(firstCallOfBurstIdx{i})';
%     else
%     centsWithoutNaN{i} = centsCur;
%     end
    
    freqValuesIdcsWithoutNaNCur = find(isnan(freqValuesCur));
    freqValuesCur(freqValuesIdcsWithoutNaNCur) = [];
    if onlyFirstUSVofBursts==1
        freqValuesWithoutNaN{i} = freqValuesCur(firstCallOfBurstIdx{i});
    else
    freqValuesWithoutNaN{i} = freqValuesCur;
    end
    
    freqDiffValuesIdcsWithoutNaNCur = find(isnan(freqDiffValuesCur));
    freqDiffValuesCur(freqDiffValuesIdcsWithoutNaNCur) = [];
    if onlyFirstUSVofBursts==1
        freqDiffValuesWithoutNaN{i} = freqDiffValuesCur(firstCallOfBurstIdx{i});
    else
    freqDiffValuesWithoutNaN{i} = freqDiffValuesCur;
    end
end


%% freq value analysis
figure;plotSpread(freqValuesWithoutNaN,'showMM',5)
title('1=101001; 2=101014')
ylabel('Frequency(Hz)')
savefig('absolute Frequency.fig')
%% cent analysis
edges= -1150:100:1150;
nrOfCentsInBinBelowZero = [];
nrOfCentsInBinAboveZero = [];
poolAll = input('pool all sessions? 1 = yes, 0 = no')
if poolAll == 1
centsWithoutNaN = vertcat(centsWithoutNaN{:});%pool all
nrOfCentsInBin = histcounts(centsWithoutNaN,edges);
nrOfCentsInBinBelowZero(i) = sum(nrOfCentsInBin(1:12));
nrOfCentsInBinAboveZero(i) = sum(nrOfCentsInBin(13:end));
figure;
histogram('BinEdges',edges,'BinCOunts',nrOfCentsInBin )
xlabel('cent')
ylabel('count')
else
figure; 
for i = 1:length(centsWithoutNaN)
nrOfCentsInBin = histcounts(centsWithoutNaN{i},edges);
nrOfCentsInBinBelowZero(i) = sum(nrOfCentsInBin(1:12));
nrOfCentsInBinAboveZero(i) = sum(nrOfCentsInBin(13:end));
subplot(1,length(centsWithoutNaN),i)
histogram('BinEdges',edges,'BinCOunts',nrOfCentsInBin )
xlabel('cent')
ylabel('count')
title(['Session: ',num2str(allSessionIDs(i))])
% ylim([0 25])
% centsWithoutNaN{i}
end
end
savefig('centDistributions.fig')


%% freq diff analysis
edges= -40:5:40;

figure; 
for i = 1:length(freqDiffValuesWithoutNaN)
nrOfFreqsInBin = histcounts(freqDiffValuesWithoutNaN{i},edges);

subplot(1,2,i)
histogram('BinEdges',edges,'BinCOunts',nrOfFreqsInBin )
xlabel('frequency difference (kHz)')
ylabel('count')
title(['Session: ',num2str(allSessionIDs(i))])
ylim([0 25])
% freqDiffValuesWithoutNaN{i}
end
savefig('freqDistributions.fig')

%%
% positiveNegativeRatio = nrOfCentsInBinAboveZero./nrOfCentsInBinBelowZero;
% figure;plot(positiveNegativeRatio)
% xlabel('session nr')
% ylabel('positive-negative ratio')

%% std-cv analysis
stdCentValuesOnlyPositive = [];
stdFreqDiffValuesOnlyPositive = [];
cvSquaredCents = [];
cvSquaredFreqDiffValues = [];
for i = 1:length(centsWithoutNaN)
centsCurAnalysis = centsWithoutNaN{i};
stdCentValuesOnlyPositive(i) = std(centsCurAnalysis(centsCurAnalysis>0));
cvSquaredCents(i) = (stdCentValuesOnlyPositive(i)/mean(centsCurAnalysis(centsCurAnalysis>0)))^2;

freqDiffValuesCurAnalysis = freqDiffValuesWithoutNaN{i};
stdFreqDiffValuesOnlyPositive(i) = std(freqDiffValuesCurAnalysis(freqDiffValuesCurAnalysis>0));
cvSquaredFreqDiffValues(i) = (stdFreqDiffValuesOnlyPositive(i)/mean(freqDiffValuesCurAnalysis(freqDiffValuesCurAnalysis>0)))^2;
end

figure;plotSpread({cvSquaredCents cvSquaredFreqDiffValues},'showMM',5)

%% duration vs cent change
allDurations = vertcat(USVduration_times{:});
% allCents = vertcat(centsWithoutNaN{:});
allCents = vertcat(centsWithoutNaN);

[R,P,Rsquare] = regressionLinePlot(allDurations,allCents)
histogram(vertcat(centsWithoutNaN{:}),200)

histogram(freqDiffValuesWithoutNaN{1},200)

figure;scatter(allDurations,allCents)