%% tickleSyncTime
% Requirement:
% audioTTL.txt, ELAN.txt, tickleSequence.mat, autolabels_comb.txt, *.WAV
% in the current folder

clear ELAN audioTTL

alignWithoutUSVsAnalyzed = input('are USVs already analyzed?');
%% load ELAN
ELAN_file = dir('*ELAN*.txt');
if numel(ELAN_file) ~= 1
    error('Not exactly one ELAN file');
end
ELAN_labels=readtable(ELAN_file.name,'Delimiter','tab', 'ReadVariableNames', false);
ELAN.Start = ELAN_labels{:,{'Var1'}};  % extract values from table to array
ELAN.End = ELAN_labels{:,{'Var2'}};
ELAN.PhaseNames = ELAN_labels{:,{'Var3'}};
clear ELAN_file ELAN_labels

%% convert 'Tickle' phase into body parts
load('ticklingSequence.mat'); % as randTicklingSequence
randTicklingSequence = randTicklingSequence';
db_user = 'eduard';
db_password = 'H,urGel9';
db = 'EddyTickling';
mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));
[phaseID, phaseTypes] = mysql(sprintf(['' ...
                        , ' SELECT phase_type_id, phase_type FROM EddyTickling.Phase_Types ' ...
                        ]));
mysql('close');

tickleSeq = phaseTypes(phaseID(randTicklingSequence));

% make sure there are as many TTL as in ticklingSequence.mat
if sum(strcmp(ELAN.PhaseNames, 'TTL')) ~= length(tickleSeq)
    error('Not as many TTL in ELAN as in ticklingSequence.mat');
end

thisType = 1;
for pha=1:length(ELAN.PhaseNames)
    switch ELAN.PhaseNames{pha}
        case 'TTL'
            if pha ~= find(strcmp(ELAN.PhaseNames,'TTL'),1,'first') % not first TTL
                thisType = thisType + 1;
            end
        case 'Tickle'
            ELAN.PhaseNames(pha) = tickleSeq(thisType);
        otherwise
            ELAN.PhaseNames{pha} = lower(ELAN.PhaseNames{pha});
    end        
end

clear tickleSeq randTicklingSequence phaseTypes phaseID db db_password db_user pha thisType

%% load audioTTL
audioTTL_file = dir('*audioTTL.txt');
if numel(audioTTL_file) ~= 1
    runAudioTTL = questdlg('Not exactly one audioTTL file. Do you run audioTTL?');
    if strcmp(runAudioTTL, 'Yes')
        audioTTL_result = audioTTL();
        audioTTL.Start = audioTTL_result.TTL_Up_in_s;
        audioTTL.End = audioTTL_result.TTL_Down_in_s;
        clear audioTTL_result runAudioTTL
    else
        error('No audioTTL file. I stop here.');
    end    
else
    audioTTL_labels=readtable(audioTTL_file.name,'Delimiter','tab', 'ReadVariableNames', false);
    audioTTL.Start = audioTTL_labels{:,{'Var1'}};  % extract values from table to array
    audioTTL.End = audioTTL_labels{:,{'Var2'}};
end
clear audioTTL_file audioTTL_labels

%% load USVs
if alignWithoutUSVsAnalyzed == 1
usv_file = dir('*autolabels_comb*.txt');
if numel(usv_file) ~= 1
    error('Not exactly one USV file');
end
USV.autoUSVs = 1;
mVersion = version;
mVersion = str2num(mVersion(1:3));
if  mVersion < 9.2
    USV.comb_threshold = usv_file.name((strfind(usv_file.name, 'comb_')+5):(strfind(usv_file.name, 'ms')-1));
else
    USV.comb_threshold = str2num(cell2mat(extractBetween(usv_file.name, 'comb_', 'ms.txt')));
end

Table=readtable(usv_file.name, 'Delimiter', 'tab', 'ReadVariableNames',false);
if strcmp(Table{1,{'Var1'}},'start') % Auto Call-o-matic results might have headers
    Table=readtable(usv_file.name, 'Delimiter', 'tab', 'ReadVariableNames',true);
    USV.Start=Table{:,1};
    USV.End=Table{:,2};
    USV.Type=Table{:,3};
else
    USV.Start=Table{:,{'Var1'}};
    USV.End=Table{:,{'Var2'}};
    USV.Type=Table{:,{'Var3'}};
end
clear usv_file Table mVersion
end
%% Align and normalize video & USV time to audio time
% Plot video vs. audio
figure;
subplot(1,2,1);
line([0 max(ELAN.Start)], [0 max(ELAN.Start)],'Color','red');
hold on
scatter(ELAN.Start(strcmp(ELAN.PhaseNames,'TTL')),audioTTL.Start,'k');
hold off
xlabel('Video TTL start time [s]')
ylabel('Audio TTL start time [s]')
legend('X=Y', 'TTL','Location','northwest')
linfit = fitlm(ELAN.Start(strcmp(ELAN.PhaseNames,'TTL')),audioTTL.Start);
R2 = linfit.Rsquared.Ordinary;
title(strcat('Pre-Normalization: R-squared = ', num2str(R2)));
% Normalize
% If ELAN times are on y axis, then y intercept has to be substracted from ELAN times.
% If ELAN times are on x axis, then x intercept has to be substracted from ELAN times.
% It is important, that first intercept has to be substracted and
% AFTERWARDS slope multiplication!
slope = (audioTTL.Start(end) - audioTTL.Start(1)) / (ELAN.Start(find(strcmp(ELAN.PhaseNames, 'TTL'), 1, 'last'))-...
    ELAN.Start(find(strcmp(ELAN.PhaseNames, 'TTL'), 1, 'first')));
y_intercept = audioTTL.Start(1)-slope*ELAN.Start(find(strcmp(ELAN.PhaseNames, 'TTL'), 1, 'first'));
x_intercept = -y_intercept/slope;
ELAN.Start = ELAN.Start - x_intercept;
ELAN.End = ELAN.End - x_intercept;
videoDur = ELAN.Start(strcmp(ELAN.PhaseNames,'TTL'));
videoDur = videoDur(end) - videoDur(1);
audioDur = audioTTL.Start(end) - audioTTL.Start(1);
videoError = audioDur - videoDur;
ELAN.Start = ELAN.Start * slope;
ELAN.End = ELAN.End * slope;

% Plot video vs. audio
subplot(1,2,2);
line([0 max(ELAN.Start)], [0 max(ELAN.Start)],'Color','red');
hold on
scatter(ELAN.Start(strcmp(ELAN.PhaseNames,'TTL')),audioTTL.Start,'k');
hold off
xlabel('Video TTL start time [s]')
ylabel('Audio TTL start time [s]')
legend('X=Y', 'TTL','Location','northwest')
linfit = fitlm(ELAN.Start(strcmp(ELAN.PhaseNames,'TTL')),audioTTL.Start);
R2 = linfit.Rsquared.Ordinary;
title(strcat('Post-Normalization: R-squared = ', num2str(R2)));
savefig('syncTest.fig')
% everything in ms
s2ms = 1e3;
ELAN.Start = ELAN.Start * s2ms;
ELAN.End = ELAN.End * s2ms;
videoError = videoError * s2ms;
if alignWithoutUSVsAnalyzed == 1
USV.Start = USV.Start * s2ms;
USV.End = USV.End * s2ms;
end
clear videoDur audioDur audioTTL videoOffset linfit R2

%% Fill empty time with baseline and break
% get audio duration
wavFile = dir('*.WAV');
if numel(wavFile) ~= 1
    ls('*.wav')
    error('not exactly one .wav file')
end
wavFile = audioinfo(wavFile.name);
wavDur = wavFile.Duration; % [s]
wavDur = wavDur * s2ms;

interval = 500; % [ms] non-labeled periods longer than this will be labeled as break
break_start = [];
break_end = [];
idx = 1;
for phase=1:length(ELAN.Start)-1
    if ELAN.Start(phase+1) - ELAN.End(phase) > interval
        break_start(idx,1) = ELAN.End(phase);
        break_end(idx,1) = ELAN.Start(phase+1);
        idx=idx+1;
    end
end
insert = @(a,x,n)cat(2,x(1:n-1),a,x(n:end)); % function handle to insert a into x at nth
brk = {'break'};
for thisBreak = 1:length(break_start)
    insert_here = numel(ELAN.Start(ELAN.Start < break_start(thisBreak))) + 1;
    ELAN.Start = insert(break_start(thisBreak), ELAN.Start', insert_here)';
    ELAN.End = insert(break_end(thisBreak), ELAN.End', insert_here)';
    ELAN.PhaseNames = insert(brk, ELAN.PhaseNames', insert_here)';
end
% insert baseline at the beginning
ELAN.PhaseNames = insert({'baseline'},ELAN.PhaseNames',1)';
ELAN.Start = insert(0,ELAN.Start',1)';
ELAN.End = insert(ELAN.Start(2),ELAN.End',1)';
% insert break at the end
ELAN.PhaseNames(end+1) = brk;
ELAN.Start(end+1) = ELAN.End(end);
ELAN.End(end+1) = wavDur;

clear wavFile s2ms brk insert idx break_start break_end interval wavDur

%% write phase labels for audacity
tbl = table(ELAN.Start/1000, ELAN.End/1000,ELAN.PhaseNames);
writetable(tbl, 'phasesInAudioTime.txt'...
, 'Delimiter', 'tab'...
, 'WriteVariableNames', false...
)

if alignWithoutUSVsAnalyzed ==1
save SyncTime.mat USV ELAN videoError
end
clear

% for i = 1:20
% x(i) = USV.Start(i+150)-ELAN.Start(i)
% end