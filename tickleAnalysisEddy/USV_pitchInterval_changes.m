%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Call analyzer   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%     This script enables specific selection of different timepoints within
%     a call and performs a FFT on that time section. The maximum of the
%     FFT is extracted, where only data outlined in red rectangles are
%     taken into consideration. NEVER input more than 3 rectangles (we
%     assume that single calls only consist of max 3 elements (which is not
%     always true, of course)

%% mysql connect
mysqlStatus = mysql('status')
if mysqlStatus == 1 % 1 means not connected
    username = input('Username?') 
    password = input('Password?') 
    mysql('open', 'mysql', username,password)
    mysql('show databases')
    mysql('USE EddyTickling')
end

%% load analyzed calls
dsOrCoM = input('deep squeak or call-o-matic? 1 = deep squeak, 2 = call-o-matic')
%   deep squeak
if dsOrCoM == 1
[exlTable,path] = uigetfile('*.xlsx','Select deep squeak exported table');
exlTable = importdata(exlTable);
textData = exlTable.textdata.Sheet1;
firstRow = textData(1,:);
USVstartColumn = find(strcmp('Begin Time (s)', firstRow));
USVstopColumn = find(strcmp('End Time (s)', firstRow));
data = exlTable.data.Sheet1;
%get all USVs
USVstart = data(1:end,USVstartColumn)*1000;% ms
USVstop = data(1:end,USVstopColumn)*1000;% ms
% callTypeColumn = textData(2:end,find(strcmp('Label',firstRow)));
% longIdx =  find(strcmp('Long',callTypeColumn));
% trillsIdx = find(strcmp('Trill',callTypeColumn));
% combinedTrillsIdx = find(strcmp('Combinedtrill',callTypeColumn));
% %get combinedTrill USVs
% USVstartCombinedTrills = USVstart(combinedTrillsIdx);
% USVstopCombinedTrills = USVstop(combinedTrillsIdx);
end
% call-o-matic
if dsOrCoM == 2
[tableName,path] = uigetfile('*.txt','Select call-o-matic exported table');
autolabels = strcat(path, tableName);
autolabels = readtable(autolabels, 'Delimiter', 'tab');
USVstart = autolabels{:,1}*1000;% ms
USVstop = autolabels{:,2}*1000;% ms
callType = autolabels{:,3};
end
    
%%
%load audioData
[audioData, Fs] = audioread(uigetfile('*.wav','Select audio file'));
USVs = [];
selectedTimeRange=[];


% prepare loop
firstOrContinuing = input('first analysis (=1) or continuing(=2)?');
if firstOrContinuing == 1
loopVector = 1:length(USVstart);

% insert rat, experiment and session IDs (session ID = expId because only 1
% session per day)
ratID = input('what is the rat ID?');
ratIDstring = num2str(ratID);
expID = input('what is the exp ID?');
expIDstring = num2str(expID);
expNr = str2double(expIDstring(length(ratIDstring)+1:end));
sessionID = expID;
mysql(sprintf('DELETE from Rats WHERE rat_id = (%s)',num2str(ratID)))
mysql(sprintf('INSERT INTO Rats(rat_id) VALUES (%s)',num2str(ratID)))
dateWithMinuses = tableName(9:18);
dateForDatabase = [dateWithMinuses(1:4) dateWithMinuses(6:7) dateWithMinuses(9:10)];
mysql(sprintf('DELETE from Experiments WHERE experiment_id = (%s)',num2str(expID)))
mysql(sprintf('INSERT INTO Experiments(experiment_id,rat_id,date,experiment_nr) VALUES (%s,%s,%s,%s)',num2str(expID),num2str(ratID),num2str(dateForDatabase),num2str(expNr)))
mysql(sprintf('DELETE from Sessions WHERE session_id = (%s)',num2str(sessionID)))
mysql(sprintf('INSERT INTO Sessions(experiment_id,session_id) VALUES (%s,%s)',num2str(expID),num2str(sessionID)))

end
%%
if firstOrContinuing == 2
[USVchangeName,path] = uigetfile('*.txt','Select call-o-matic exported table');
load([USVchangeName,'.mat'])

    correctMalDetections = input('continue full analysis = 1; correctMalDetections = 2')
    if correctMalDetections == 2
        loopVector = input('insert USV numbers that are mal-detected in brackets: [...]')
    else
loopVector = length(USVchange)+1:length(USVstart);
    end
end


%loop
figure('units','normalized','outerposition',[0 0 1 1])
%%%now decide if analysis should be done semi-or fully automatically
semiOrFullyAutomatic = input('analysis: semiautomatic = 1; fully automatic (only beginning and end call selection) = 2');    
for i = loopVector
    cents = [];
    freqDifference = [];
    beforeAndAfterDatapoints = 10000;%10000 datapoints (40 ms) before and after call has been detected
    audioTraceSingleUSVs = audioData(USVstart(i)/1000*Fs-beforeAndAfterDatapoints:USVstop(i)/1000*Fs+beforeAndAfterDatapoints);
    [specPower,specFrequency,specTime] = usv_time_resolved_spectrogram_eddyEdit(audioTraceSingleUSVs, Fs);
    title(['call nr: ',num2str(i),'/',num2str(loopVector(end))])
    analysisRangeDatapoints = 5000;% corresponds to 20 ms
    if semiOrFullyAutomatic==2 %-->fully automatic
    
        for k = 1:2
        if k == 1 %beginning of call
            if correctMalDetections == 2%correct malDetected USVs
            [x,y] = ginput(2);
            if y(2)>y(1)
            rectangle('Position',[x(1)  y(1) x(2)-x(1) y(2)-y(1)],'EdgeColor','r')
            else
            rectangle('Position',[x(1)  y(2) x(2)-x(1) y(1)-y(2)],'EdgeColor','r')
            end
            selectedTimeRange(k) = (x(2)-x(1))*1000;%ms
            diffToX1 = abs(specTime-x(1));%x1/x2 can (by clicking) happen to be a number between specTime variables...
            diffToX2 = abs(specTime-x(2));%...therefore find the closest specTime variable in the next line...
            selectedData{k} = specPower(:,find(diffToX1==min(diffToX1)):find(diffToX2==min(diffToX2)));%...and find power spectrum during that time
            averagedSelectedData{k} = mean(selectedData{k}');
            averagedSelectedDataCur = averagedSelectedData{k};
            if y(2)>y(1)
            maxPowerOfUSVCur(k) = max(averagedSelectedDataCur(:,round(y(1)/specFrequency(end)*length(averagedSelectedDataCur)):round(y(2)/specFrequency(end)*length(averagedSelectedDataCur))));%this ugly term is to get the correctly scaled numbers. had to scale from actual frequency to index
            else
            maxPowerOfUSVCur(k) = max(averagedSelectedDataCur(:,round(y(2)/specFrequency(end)*length(averagedSelectedDataCur)):round(y(1)/specFrequency(end)*length(averagedSelectedDataCur))));%this ugly term is to get the correctly scaled numbers. had to scale from actual frequency to index    
            end
        
            idxOfMaxPowerFrequencyOfUSV = find(averagedSelectedDataCur == maxPowerOfUSVCur(k));
            USVchange(i).maxPowerFrequencyOfUSV(k) = specFrequency(idxOfMaxPowerFrequencyOfUSV);%

            subplot(2,3,3+k)
            plot(specFrequency,averagedSelectedData{k},'k')
            hold on
            plot(USVchange(i).maxPowerFrequencyOfUSV(k), maxPowerOfUSVCur(k), 'r.')
            xlim([USVchange(i).maxPowerFrequencyOfUSV(k)-1000 USVchange(i).maxPowerFrequencyOfUSV(k)+1000])
            title(['max: ',num2str(USVchange(i).maxPowerFrequencyOfUSV(k)),' Hz'])

            elseif correctMalDetections == 1%continue full analysis
            selectedTimeRange(k) = analysisRangeDatapoints/Fs;%seconds;
            diffSpecTimeCallOnset = abs(specTime-(beforeAndAfterDatapoints/Fs));
            callTimeOnsetIdx = find(diffSpecTimeCallOnset == min(diffSpecTimeCallOnset));
            diffSpecTimeCallOnsetPlusAnalysisWindow = abs(specTime-((beforeAndAfterDatapoints + analysisRangeDatapoints)/Fs));
            callTimeOnsetPlusAnalysisWindowIdx = find(diffSpecTimeCallOnsetPlusAnalysisWindow == min(diffSpecTimeCallOnsetPlusAnalysisWindow));
            
            selectedData{k} = specPower(:, callTimeOnsetIdx: callTimeOnsetPlusAnalysisWindowIdx);
            averagedSelectedData{k} = mean(selectedData{k}');
            averagedSelectedDataCur = averagedSelectedData{k};

            maxPowerOfUSVCur(k) = max(averagedSelectedDataCur);

            idxOfMaxPowerFrequencyOfUSVOnset = find(averagedSelectedDataCur == maxPowerOfUSVCur(k));
            USVchange(i).maxPowerFrequencyOfUSV(k) = specFrequency(idxOfMaxPowerFrequencyOfUSVOnset)%
            subplot(2,3,3+k)
            plot(specFrequency,averagedSelectedData{k},'k')
            hold on
            plot(USVchange(i).maxPowerFrequencyOfUSV(k), maxPowerOfUSVCur(k), 'r.')
            xlim([USVchange(i).maxPowerFrequencyOfUSV(k)-1000 USVchange(i).maxPowerFrequencyOfUSV(k)+1000])
            title(['max: ',num2str(USVchange(i).maxPowerFrequencyOfUSV(k)),' Hz'])
            else
                error('Choose if you want to continue full analysis or only malDetected USVs')
            end
        end
        if k ==2 %end of call
            if correctMalDetections == 2% correct malDetected USVs
            [x,y] = ginput(2);
            [x,y] = ginput(2);
            if y(2)>y(1)
            rectangle('Position',[x(1)  y(1) x(2)-x(1) y(2)-y(1)],'EdgeColor','r')
            else
            rectangle('Position',[x(1)  y(2) x(2)-x(1) y(1)-y(2)],'EdgeColor','r')
            end
            selectedTimeRange(k) = (x(2)-x(1))*1000;%ms
            diffToX1 = abs(specTime-x(1));%x1/x2 can (by clicking) happen to be a number between specTime variables...
            diffToX2 = abs(specTime-x(2));%...therefore find the closest specTime variable in the next line...
            selectedData{k} = specPower(:,find(diffToX1==min(diffToX1)):find(diffToX2==min(diffToX2)));%...and find power spectrum during that time
            averagedSelectedData{k} = mean(selectedData{k}');
            averagedSelectedDataCur = averagedSelectedData{k};
            if y(2)>y(1)
            maxPowerOfUSVCur(k) = max(averagedSelectedDataCur(:,round(y(1)/specFrequency(end)*length(averagedSelectedDataCur)):round(y(2)/specFrequency(end)*length(averagedSelectedDataCur))));%this ugly term is to get the correctly scaled numbers. had to scale from actual frequency to index
            else
            maxPowerOfUSVCur(k) = max(averagedSelectedDataCur(:,round(y(2)/specFrequency(end)*length(averagedSelectedDataCur)):round(y(1)/specFrequency(end)*length(averagedSelectedDataCur))));%this ugly term is to get the correctly scaled numbers. had to scale from actual frequency to index    
            end
        
            idxOfMaxPowerFrequencyOfUSV = find(averagedSelectedDataCur == maxPowerOfUSVCur(k));
            USVchange(i).maxPowerFrequencyOfUSV(k) = specFrequency(idxOfMaxPowerFrequencyOfUSV);%

            subplot(2,3,3+k)
            plot(specFrequency,averagedSelectedData{k},'k')
            hold on
            plot(USVchange(i).maxPowerFrequencyOfUSV(k), maxPowerOfUSVCur(k), 'r.')
            xlim([USVchange(i).maxPowerFrequencyOfUSV(k)-1000 USVchange(i).maxPowerFrequencyOfUSV(k)+1000])
            title(['max: ',num2str(USVchange(i).maxPowerFrequencyOfUSV(k)),' Hz'])
            
            elseif correctMalDetections == 1%continue with full analysis
            selectedTimeRange(k) = analysisRangeDatapoints/Fs; % in this condition both values of that vector should be always equal the values of the variable "beforeAndAfterDatapoints"
            diffSpecTimeCallOffset = abs(specTime-(length(audioTraceSingleUSVs)/Fs-beforeAndAfterDatapoints/Fs));
            callTimeOffsetIdx = find(diffSpecTimeCallOffset == min(diffSpecTimeCallOffset));
            diffSpecTimeCallOffsetMinusAnalysisWindow = abs(specTime-(length(audioTraceSingleUSVs)/Fs-(beforeAndAfterDatapoints+analysisRangeDatapoints)/Fs));
            callTimeOffsetMinusAnalysisWindowIdx = find(diffSpecTimeCallOffsetMinusAnalysisWindow == min(diffSpecTimeCallOffsetMinusAnalysisWindow));

            selectedData{k} = specPower(:,callTimeOffsetMinusAnalysisWindowIdx:callTimeOffsetIdx);
            averagedSelectedData{k} = mean(selectedData{k}');
            averagedSelectedDataCur = averagedSelectedData{k};

            maxPowerOfUSVCur(k) = max(averagedSelectedDataCur);

                        
            idxOfMaxPowerFrequencyOfUSVOffset = find(averagedSelectedDataCur == maxPowerOfUSVCur(k));
            USVchange(i).maxPowerFrequencyOfUSV(k) = specFrequency(idxOfMaxPowerFrequencyOfUSVOffset)%
            subplot(2,3,3+k)
            plot(specFrequency,averagedSelectedData{k},'k')
            hold on
            plot(USVchange(i).maxPowerFrequencyOfUSV(k), maxPowerOfUSVCur(k), 'r.')
            xlim([USVchange(i).maxPowerFrequencyOfUSV(k)-1000 USVchange(i).maxPowerFrequencyOfUSV(k)+1000])
            title(['max: ',num2str(USVchange(i).maxPowerFrequencyOfUSV(k)),' Hz'])
            else
                error('Choose if you want to continue full analysis or only malDetected USVs')
            end 
            saveas(gcf,[tableName,num2str(i),'.png'])
            subplot(2,3,[1,2,3])
            rectangle('Position',[specTime(callTimeOffsetMinusAnalysisWindowIdx)  specFrequency(1) specTime(callTimeOffsetIdx)-specTime(callTimeOffsetMinusAnalysisWindowIdx) specFrequency(end)],'EdgeColor','b')
            line([specTime(1) specTime(callTimeOffsetIdx)'],[specFrequency(idxOfMaxPowerFrequencyOfUSVOffset) specFrequency(idxOfMaxPowerFrequencyOfUSVOffset)],'Color','red')
            rectangle('Position',[specTime(callTimeOnsetIdx)  specFrequency(1) specTime(callTimeOnsetPlusAnalysisWindowIdx)-specTime(callTimeOnsetIdx) specFrequency(end)],'EdgeColor','b')
            line([specTime(1) specTime(callTimeOnsetPlusAnalysisWindowIdx)'],[specFrequency(idxOfMaxPowerFrequencyOfUSVOnset) specFrequency(idxOfMaxPowerFrequencyOfUSVOnset)],'Color','red')
    
            saveas(gcf,[tableName,num2str(i),'withIndications.png'])
            
            %calculate cents
            cents(k-1) = 1200*log(USVchange(i).maxPowerFrequencyOfUSV(k)/USVchange(i).maxPowerFrequencyOfUSV(k-1))/log(2);
            freqDifference(k-1) = USVchange(i).maxPowerFrequencyOfUSV(k)-USVchange(i).maxPowerFrequencyOfUSV(k-1);
        end
        end
    elseif semiOrFullyAutomatic==1 %-->semi automatic, see following lines
    k=1;
    while k<10 % k will be set >10 whenever x and y are equal (clicked two times the same spot); if no interval is visible in the call click two times the same sport and this call will be ignored
        [x,y] = ginput(2);

        if x(1) == x(2) & y(1) == y(2) % if clicked two times the same spot this will end the while condition
            k = k+10;
        else  
        if y(2)>y(1)
        rectangle('Position',[x(1)  y(1) x(2)-x(1) y(2)-y(1)],'EdgeColor','r')
        else
        rectangle('Position',[x(1)  y(2) x(2)-x(1) y(1)-y(2)],'EdgeColor','r')
        end
        selectedTimeRange(k) = (x(2)-x(1))*1000;%ms
        diffToX1 = abs(specTime-x(1));%x1/x2 can (by clicking) happen to be a number between specTime variables...
        diffToX2 = abs(specTime-x(2));%...therefore find the closest specTime variable in the next line...
        selectedData{k} = specPower(:,find(diffToX1==min(diffToX1)):find(diffToX2==min(diffToX2)));%...and find power spectrum during that time
        averagedSelectedData{k} = mean(selectedData{k}');
        averagedSelectedDataCur = averagedSelectedData{k};
        if y(2)>y(1)
        maxPowerOfUSVCur(k) = max(averagedSelectedDataCur(:,round(y(1)/specFrequency(end)*length(averagedSelectedDataCur)):round(y(2)/specFrequency(end)*length(averagedSelectedDataCur))));%this ugly term is to get the correctly scaled numbers. had to scale from actual frequency to index
        else
        maxPowerOfUSVCur(k) = max(averagedSelectedDataCur(:,round(y(2)/specFrequency(end)*length(averagedSelectedDataCur)):round(y(1)/specFrequency(end)*length(averagedSelectedDataCur))));%this ugly term is to get the correctly scaled numbers. had to scale from actual frequency to index    
        end
        
        idxOfMaxPowerFrequencyOfUSV = find(averagedSelectedDataCur == maxPowerOfUSVCur(k));
        USVchange(i).maxPowerFrequencyOfUSV(k) = specFrequency(idxOfMaxPowerFrequencyOfUSV);%

        subplot(2,3,3+k)
        plot(specFrequency,averagedSelectedData{k},'k')
        hold on
        plot(USVchange(i).maxPowerFrequencyOfUSV(k), maxPowerOfUSVCur(k), 'r.')
        xlim([USVchange(i).maxPowerFrequencyOfUSV(k)-1000 USVchange(i).maxPowerFrequencyOfUSV(k)+1000])
        title(['max: ',num2str(USVchange(i).maxPowerFrequencyOfUSV(k)),' Hz'])
        %calculate cents
            if k>1
                cents(k-1) = 1200*log(USVchange(i).maxPowerFrequencyOfUSV(k)/USVchange(i).maxPowerFrequencyOfUSV(k-1))/log(2);
                freqDifference(k-1) = USVchange(i).maxPowerFrequencyOfUSV(k)-USVchange(i).maxPowerFrequencyOfUSV(k-1);
            end
        k = k+1;
        end
    end
    
        else
        error('Choose semi- or fully automatic analysis')
    end
    
    clf
    if isempty(cents)==0
        USVchange(i).USVcents = cents;
        USVchange(i).USVfreqDiff = freqDifference;
    else
        USVchange(i).USVcents = [];
        USVchange(i).USVfreqDiff = [];
    end
    if isempty(selectedTimeRange)==0
        USVpartDuration{i} = selectedTimeRange;
    else
        USVpartDuration{i} = [];
    end
save([tableName,'.mat'],'USVchange','tableName','USVpartDuration','ratID','expID','sessionID','callType')
end

%% pitch analysis
centValues = horzcat(USVchange(:).USVcents);
stdCentValuesOnlyPositive = std(centValues(centValues>0));
cvSquaredCents = (stdCentValuesOnlyPositive/mean(centValues(centValues>0)))^2;

freqDiffValues = horzcat(USVchange(:).USVfreqDiff);
stdFreqDiffValues = std(freqDiffValues(freqDiffValues>0));
cvSquaredFreqDiffValues = (stdFreqDiffValues/mean(freqDiffValues(freqDiffValues>0)))^2;

freqValues = horzcat(USVchange(:).maxPowerFrequencyOfUSV);

%% pre-processing for database upload and upload itself
USVsylableID = [];
USV_ID = [];
callTypeTerm = [];
for i = 1:length(USVchange)
amountOfSegmentVectorCurCall = 1:length(USVchange(i).maxPowerFrequencyOfUSV);
for k=amountOfSegmentVectorCurCall
    callTypeTerm{i} = repmat(callType(i),1,k);
    USV_ID{i} = repmat((sessionID*10^6+(10*i)),1,k);
    USVsylableID{i} = (sessionID*10^6+(10*i))+[1:k];%will generate an ID with the structure: [zzzzzz (e.g. 10a with first session = 101001; session_id) xxxxx(1 to max 99999; nrOfCallInThisSession) y(1 to 3, nr of sylables);  
end 
end

% allUSV_ids = NaN(1,length(horzcat(USVsylableID{:})));
allFreqValuesCells = num2cell(NaN(1,length(USVchange)));
allCentValuesCells = num2cell(NaN(1,length(USVchange)));
allFreqDiffValuesCells = num2cell(NaN(1,length(USVchange)));

for i=1:length(USVchange)
if ~isempty(USVchange(i).maxPowerFrequencyOfUSV)
allFreqValuesCells{i} = USVchange(i).maxPowerFrequencyOfUSV;
end
if ~isempty(USVchange(i).USVcents)
allCentValuesCells{i} = [NaN(1) USVchange(i).USVcents];%insert one NaN for the first part of the sylable (there is no cent for the first sylable)
end
if ~isempty(USVchange(i).USVfreqDiff)
allFreqDiffValuesCells{i} = [NaN(1) USVchange(i).USVfreqDiff];%insert one NaN for the first part of the sylable (there is no frequency difference for the first sylable)
end
end

allCallTypeTerm = horzcat(callTypeTerm{:});
allUSV_ID = horzcat(USV_ID{:});
allUSVsylableID = horzcat(USVsylableID{:});
allFreqValues = horzcat(allFreqValuesCells{:});
allFreqDiffValues = horzcat(allFreqDiffValuesCells{:});
allCentValues = horzcat(allCentValuesCells{:});

nanIdcs = find(isnan(allFreqDiffValues));
allFreqDiffValuesUnroledCell = num2cell(allFreqDiffValues);%have to re-convert to cell in order to insert 'Null' at desired places
allCentValuesUnroledCell = num2cell(allCentValues);%have to re-convert to cell in order to insert 'Null' at desired places
for i = nanIdcs
allFreqDiffValuesUnroledCell{i}='NULL';%have to re-convert to cell in order to insert 'Null' at desired places
end
for i = nanIdcs
allCentValuesUnroledCell{i}='NULL';%have to re-convert to cell in order to insert 'Null' at desired places
end


%upload to database && TO DO: ADD CALL TYPES!!! AND APPLY UPLOAD TO ALL CURRENT ANALYZED DATA%%
mysql(sprintf('DELETE from spectralAnalysis WHERE session_id = (%s)',num2str(sessionID)))
for i = 1:length(allFreqValues)
mysql(sprintf('INSERT INTO spectralAnalysis(session_id,USV_ID, callType, USVsylableID, freqValues, freqDiffValues, cents) VALUES (%s,%s,''%s'',%s,%s,%s,%s)',num2str(sessionID),...
    num2str(allUSV_ID(i)),allCallTypeTerm{i},num2str(allUSVsylableID(i)),num2str(allFreqValues(i)),num2str(allFreqDiffValuesUnroledCell{i}),num2str(allCentValuesUnroledCell{i})))
end

%% further analysis
meanPosCents = mean(centValues(centValues>0));
meanNegCents = mean(centValues(centValues<0));

% maxBinCentValue = edges(find(nrOfCentsInBin == max(nrOfCentsInBin)));

posCentCount = length(centValues(centValues>0));
negCentCount = length(centValues(centValues<0));

posToNegCentCountRatio = posCentCount/negCentCount;
% save('USVcents_USVFreqDifferenceANDdurations.mat','USVchange','USVpartDuration','cvSquaredCents','cvSquaredFreqDiffValues')
%Plot
edges= -1350:100:1350;
nrOfCentsInBin = histcounts(centValues,edges);
figure;
histogram('BinEdges',edges,'BinCOunts',nrOfCentsInBin )
hold on
line([meanPosCents meanPosCents], [0 max(nrOfCentsInBin)],'Color',[1 0 0])
xlabel('cent intervals')
ylabel('total occurence')
title(['combined-calls, mean (positives) = ', num2str(meanPosCents),'mean (negatives) = ' num2str(meanNegCents),'n = ',num2str(length(centValues))])
savefig([tableName,'.fig'])

%  segment length analysis
USVpartDurationOneVocElement = USVpartDuration(find(cellfun("length",USVpartDuration)==1));
firstVocElementDurationOneElement = cellfun(@(v)v(1),USVpartDurationOneVocElement);

USVpartDurationTwoVocElements = USVpartDuration(find(cellfun("length",USVpartDuration)==2));
firstVocElementDurationTwoElements = cellfun(@(v)v(1),USVpartDurationTwoVocElements);
secondVocElementDurationTwoElements = cellfun(@(v)v(2),USVpartDurationTwoVocElements);

USVpartDurationThreeVocElements = USVpartDuration(find(cellfun("length",USVpartDuration)==3));
firstVocElementDurationThreeElements = cellfun(@(v)v(1),USVpartDurationThreeVocElements);
secondVocElementDurationThreeElements = cellfun(@(v)v(2),USVpartDurationThreeVocElements);
thirdVocElementDurationThreeElements = cellfun(@(v)v(3),USVpartDurationThreeVocElements);

median_firstVocElementDurationOneElement = median(firstVocElementDurationOneElement);
median_firstVocElementDurationTwoElements = median(firstVocElementDurationTwoElements);
median_secondVocElementDurationTwoElements = median(secondVocElementDurationTwoElements);
median_firstVocElementDurationThreeElements = median(firstVocElementDurationThreeElements);
median_secondVocElementDurationThreeElements = median(secondVocElementDurationThreeElements);
median_thirdVocElementDurationThreeElements = median(thirdVocElementDurationThreeElements);

figure;
subplot(1,3,1)
plotSpread({firstVocElementDurationOneElement},'showMM',4)
xlabel('# USV element within call')
ylabel('duration (ms)')
title(['USVs with 1 elements; n = ',num2str(length(firstVocElementDurationOneElement))])
subplot(1,3,2)
plotSpread({firstVocElementDurationTwoElements,secondVocElementDurationTwoElements},'showMM',4)
xlabel('# USV element within call')
ylabel('duration (ms)')
title(['USVs with 2 elements; n = ',num2str(length([firstVocElementDurationTwoElements secondVocElementDurationTwoElements]))])
subplot(1,3,3)
plotSpread({firstVocElementDurationThreeElements,secondVocElementDurationThreeElements,thirdVocElementDurationThreeElements},'showMM',4)
xlabel('# USV element within call')
ylabel('duration (ms)')
title(['USVs with 3 elements; n = ',num2str(length([firstVocElementDurationThreeElements secondVocElementDurationThreeElements thirdVocElementDurationThreeElements]))])
linkaxes([subplot(1,3,1),subplot(1,3,2),subplot(1,3,3)],'y')

savefig([tableName,'DURATIONS','.fig'])

save([tableName,'MORE_VARS','.mat'],'tableName','callType','USVchange','USVpartDuration','cvSquaredCents','cvSquaredFreqDiffValues','meanPosCents', 'meanNegCents','posToNegCentCountRatio','ratID','expID','sessionID',...
    'median_firstVocElementDurationOneElement',...
    'median_firstVocElementDurationTwoElements',...
    'median_secondVocElementDurationTwoElements',...
    'median_firstVocElementDurationThreeElements',...
    'median_secondVocElementDurationThreeElements',...
    'median_thirdVocElementDurationThreeElements')
