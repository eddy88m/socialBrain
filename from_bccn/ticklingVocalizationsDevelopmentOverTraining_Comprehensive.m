%10a = 1; 10b = 2; 11a = 3; 11b = 4; 12a = 5; 12b = 6; 12c = 7
% nrOfSessionAll = nan(7,50);
% callFrequency_HzAll = nan(7,50);
% ratioOfcombinedCallsAll = nan(7,50);
% ratioOfFlatCallsAll = nan(7,50);
% ratioOfmiscAll = nan(7,50);
% ratioOfModulatedCallsAll = nan(7,50);
% ratioOfTrillCallsAll = nan(7,50);
% save Data_All
load Data_All
n = 14;%sessions to analyze
sessionsToAnalyze = 1:n;

%test for normality
for i=sessionsToAnalyze
[hSwCallFreq(i) pSwCallFreq(i)] = swtest(callFrequency_HzAll(:,i))
end

callFrequency_HzAll_analyze = callFrequency_HzAll(:,1:n);
ratioOfcombinedCallsAll_analyze = ratioOfcombinedCallsAll(:,1:n);
ratioOfFlatCallsAll_analyze = ratioOfFlatCallsAll(:,1:n);
ratioOfmiscAll_analyze = ratioOfmiscAll(:,1:n);
ratioOfModulatedCallsAll_analyze = ratioOfModulatedCallsAll(:,1:n);
ratioOfTrillCallsAll_analyze = ratioOfTrillCallsAll(:,1:n);

mean_callFrequency_HzAll = mean(callFrequency_HzAll_analyze);
mean_ratioOfcombinedCallsAll = mean(ratioOfcombinedCallsAll_analyze);
mean_ratioOfFlatCallsAll = mean(ratioOfFlatCallsAll_analyze);
mean_ratioOfmiscAll = mean(ratioOfmiscAll_analyze);
mean_ratioOfModulatedCallsAll = mean(ratioOfModulatedCallsAll_analyze);
mean_ratioOfTrillCallsAll = mean(ratioOfTrillCallsAll_analyze);

std_callFrequency_HzAll = std(callFrequency_HzAll_analyze);
std_ratioOfcombinedCallsAll = std(ratioOfcombinedCallsAll_analyze);
std_ratioOfFlatCallsAll = std(ratioOfFlatCallsAll_analyze);
std_ratioOfmiscAll = std(ratioOfmiscAll_analyze);
std_ratioOfModulatedCallsAll = std(ratioOfModulatedCallsAll_analyze);
std_ratioOfTrillCallsAll = std(ratioOfTrillCallsAll_analyze);

sem_callFrequency_HzAll = std_callFrequency_HzAll/sqrt(n);
sem_ratioOfcombinedCallsAll = std_ratioOfcombinedCallsAll/sqrt(n);
sem_ratioOfFlatCallsAll = std_ratioOfFlatCallsAll/sqrt(n);
sem_ratioOfmiscAll = std_ratioOfmiscAll/sqrt(n);
sem_ratioOfModulatedCallsAll = std_ratioOfModulatedCallsAll/sqrt(n);
sem_ratioOfTrillCallsAll = std_ratioOfTrillCallsAll/sqrt(n);

zscore_ratioOfcombinedCallsAll_analyze = zscore(ratioOfcombinedCallsAll_analyze,[],2);
zscore_ratioOfFlatCallsAll_analyze = zscore(ratioOfFlatCallsAll_analyze,[],2);
zscore_ratioOfmiscAll_analyze = zscore(ratioOfmiscAll_analyze,[],2);
zscore_ratioOfModulatedCallsAll_analyze = zscore(ratioOfModulatedCallsAll_analyze,[],2);
zscore_ratioOfTrillCallsAll_analyze = zscore(ratioOfTrillCallsAll_analyze,[],2);


differenceCombined = diff(zscore_ratioOfcombinedCallsAll_analyze,1,2);
differenceFlat = diff(zscore_ratioOfFlatCallsAll_analyze,1,2);
differenceMisc = diff(zscore_ratioOfmiscAll_analyze,1,2);
differenceModulated = diff(zscore_ratioOfModulatedCallsAll_analyze,1,2);
differenceTrill = diff(zscore_ratioOfTrillCallsAll_analyze,1,2);

meanSlopeCombined = mean(differenceCombined*100,2);% in per cent per cent change per session
meanSlopeFlat = mean(differenceFlat*100,2);% in per cent chang per session
meanSlopeMisc = mean(differenceMisc*100,2);% in per cent chang per session
meanSlopeModulated = mean(differenceModulated*100,2);% in per cent chang per session
meanSlopeTrill = mean(differenceTrill*100,2);% in per cent chang per session


% plotSpread({meanSlopeCombined, meanSlopeFlat, meanSlopeMisc, meanSlopeModulated, meanSlopeTrill},'showMM',4)
[pSlope,tSlopw,statsSlope] = anova1([meanSlopeMisc, meanSlopeFlat, meanSlopeModulated, meanSlopeCombined, meanSlopeTrill]);
[cSlope,mSlope,hSlope,nms] = multcompare(statsSlope);
figure;plot(ones(7,14).*linspace(1,14,14),zscore_ratioOfcombinedCallsAll_analyze,'o')
[rCorrCombined pCorrCombined] = corrcoef(ones(7,14).*linspace(1,14,14),zscore_ratioOfcombinedCallsAll_analyze)
[rCorrFlat pCorrFlat] = corrcoef(ones(7,14).*linspace(1,14,14),zscore_ratioOfFlatCallsAll_analyze)
[rCorrMisc pCorrMisc] = corrcoef(ones(7,14).*linspace(1,14,14),zscore_ratioOfmiscAll_analyze)
[rCorrModulated pCorrModulated] = corrcoef(ones(7,14).*linspace(1,14,14),zscore_ratioOfModulatedCallsAll_analyze)
[rCorrTrill pCorrTrill] = corrcoef(ones(7,14).*linspace(1,14,14),zscore_ratioOfTrillCallsAll_analyze)
[rCorrCallFreq pCorrCallFreq] = corrcoef(ones(7,14).*linspace(1,14,14),callFrequency_HzAll_analyze)

[rCorrTrillPercent pCorrTrillPercent] = corrcoef(ones(7,14).*linspace(1,14,14),ratioOfTrillCallsAll_analyze)

figure;
boxplot([meanSlopeMisc, meanSlopeFlat, meanSlopeModulated, meanSlopeCombined, meanSlopeTrill])

figure;
plot(sessionsToAnalyze,mean_callFrequency_HzAll,'k')
hold on
errorbar(sessionsToAnalyze,mean_callFrequency_HzAll,sem_callFrequency_HzAll,'k')
xlabel('#session')
ylabel('USV rate (Hz)')
title('USV rate')
savefig('Data_All_USVfreq.fig')

figure;
subplot(1,5,4)
plot(sessionsToAnalyze,mean_ratioOfcombinedCallsAll*100,'k')
hold on
errorbar(sessionsToAnalyze,mean_ratioOfcombinedCallsAll*100,sem_ratioOfcombinedCallsAll*100,'k')
xlabel('#session')
ylabel('combined (%)')
title('combined')
subplot(1,5,2)
plot(sessionsToAnalyze,mean_ratioOfFlatCallsAll*100,'k')
hold on
errorbar(sessionsToAnalyze,mean_ratioOfFlatCallsAll*100,sem_ratioOfFlatCallsAll*100,'k')
xlabel('#session')
ylabel('flat (%)')
title('flat')
subplot(1,5,1)
plot(sessionsToAnalyze,mean_ratioOfmiscAll*100,'k')
hold on
errorbar(sessionsToAnalyze,mean_ratioOfmiscAll*100,sem_ratioOfmiscAll*100,'k')
xlabel('#session')
ylabel('misc (%)')
title('misc')
subplot(1,5,3)
plot(sessionsToAnalyze,mean_ratioOfModulatedCallsAll*100,'k')
hold on
errorbar(sessionsToAnalyze,mean_ratioOfModulatedCallsAll*100,sem_ratioOfModulatedCallsAll*100,'k')
xlabel('#session')
ylabel('modulated (%)')
title('modulated')
subplot(1,5,5)
plot(sessionsToAnalyze,mean_ratioOfTrillCallsAll*100,'k')
hold on
errorbar(sessionsToAnalyze,mean_ratioOfTrillCallsAll*100,sem_ratioOfTrillCallsAll*100,'k')
xlabel('#session')
ylabel('trill (%)')
title('trill')
savefig('Data_All_callTypes.fig')

figure;
shadedErrorBar(sessionsToAnalyze,callFrequency_HzAll(:,1:n),{@mean,@std})
xlabel('#session')
ylabel('USV rate (Hz)')
title('USV rate')
savefig('Data_All_USVfreq_shadedSTD.fig')

figure;
subplot(1,5,4)
shadedErrorBar(sessionsToAnalyze,ratioOfcombinedCallsAll(:,1:n)*100,{@mean,@std})
xlabel('#session')
ylabel('combined (%)')
title('combined')
subplot(1,5,2)
shadedErrorBar(sessionsToAnalyze,ratioOfFlatCallsAll(:,1:n)*100,{@mean,@std})
xlabel('#session')
ylabel('flat (%)')
title('flat')
subplot(1,5,1)
shadedErrorBar(sessionsToAnalyze,ratioOfmiscAll(:,1:n)*100,{@mean,@std})
xlabel('#session')
ylabel('misc (%)')
title('misc')
subplot(1,5,3)
shadedErrorBar(sessionsToAnalyze,ratioOfModulatedCallsAll(:,1:n)*100,{@mean,@std})
xlabel('#session')
ylabel('modulated (%)')
title('modulated')
subplot(1,5,5)
shadedErrorBar(sessionsToAnalyze,ratioOfTrillCallsAll(:,1:n)*100,{@mean,@std})
xlabel('#session')
ylabel('trill (%)')
title('trill')
linkaxes([subplot(1,5,1) subplot(1,5,2) subplot(1,5,3) subplot(1,5,4) subplot(1,5,5)],'xy')
savefig('Data_All_shadedSTD.fig')

figure;
subplot(1,5,4)
shadedErrorBar(sessionsToAnalyze,zscore_ratioOfcombinedCallsAll_analyze,{@mean,@std})
xlabel('#session')
ylabel('combined z-score')
title('combined')
subplot(1,5,2)
shadedErrorBar(sessionsToAnalyze,zscore_ratioOfFlatCallsAll_analyze,{@mean,@std})
xlabel('#session')
ylabel('flat z-score')
title('flat')
subplot(1,5,1)
shadedErrorBar(sessionsToAnalyze,zscore_ratioOfmiscAll_analyze,{@mean,@std})
xlabel('#session')
ylabel('misc z-score')
title('misc')
subplot(1,5,3)
shadedErrorBar(sessionsToAnalyze,zscore_ratioOfModulatedCallsAll_analyze,{@mean,@std})
xlabel('#session')
ylabel('modulated z-score')
title('modulated')
subplot(1,5,5)
shadedErrorBar(sessionsToAnalyze,zscore_ratioOfTrillCallsAll_analyze,{@mean,@std})
xlabel('#session')
ylabel('trill z-score')
title('trill')
linkaxes([subplot(1,5,1) subplot(1,5,2) subplot(1,5,3) subplot(1,5,4) subplot(1,5,5)],'xy')
savefig('Data_All_shadedSTD_zscore.fig')


save 'Data_All'



