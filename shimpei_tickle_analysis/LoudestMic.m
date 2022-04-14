function LoudestMic()
% Detects which microphone caught each USV
%
% ---DESCRIPTION---
% Input via dialog: multiple audio files; label file
% Output: tab-delimited .txt file: start; end; loudestCh
%         Optionally in video time (requires NLXtime.mat) for AE JavaScript
% Additional function required: none
%
% Author: Shimpei, 2018

[startTime, endTime, callType] = readLabels();
[wavfiles, nSample, fs, y] = readWavs();

% check wavfile names for channels
for i=1:length(wavfiles)
    if ~strcmp(extractBefore(wavfiles{i}, '_'), sprintf('ch%i', i))
        error('Select audio files named "ch1", "ch2" ...');
    end
end

loudest = zeros(length(startTime),1);
loud_rank = zeros(length(startTime), length(wavfiles));

for u = 1:length(startTime)
    startSample = round(startTime(u)*fs);
    endSample = round(endTime(u)*fs);
    intensities = arrayfun(@(ch) sqrt(sum(y(startSample:endSample,ch).*y(startSample:endSample,ch))/(endSample-startSample)), ...
                            1:length(wavfiles));
    [~, loudest(u)] = max(intensities);
    loud_rank(u,:) = rank_index(intensities)';
    
end

T = table(startTime, endTime, loudest);
% writetable(T, 'loudestCh.txt', 'Delimiter', '\t', 'WriteVariableNames', false);
if strcmp(questdlg('Write a file in video time? (require trigger info)', 'Loudest Mic',...
         'Yes', 'No', 'Yes'), 'Yes')
     if ~exist('NLXtime.mat')
         error('NLXtime.mat does not exist');
     end
     load('NLXtime');
     offset = Triggers.Video_TrgStart - Triggers.Audio_TrgStart;
     durRatio = Triggers.Video_Dur/Triggers.Audio_Dur;
     
     videoStart = startTime * durRatio + offset;
     videoEnd = endTime * durRatio + offset;
     
     % JavaScript for After Effects
%      txt = strjoin(arrayfun(@(x) sprintf('[%i, %s, %s]', loudest(x), num2str(videoStart(x)), num2str(videoEnd(x))), ...
%                     1:length(videoStart), 'UniformOutput', false), ', \n');
%      txt = strcat('var usv = [', txt, ']');
%      fprintf(fopen('loudestCh_videoTimeJS.txt', 'w'),txt);
     
     % Tab-delimited text for ELAN
     rank_txt = cell(length(startTime),1);
     for i=1:length(startTime)
         rank_txt{i} = strjoin(arrayfun(@(x) sprintf('%i', loud_rank(i,x)), 1:length(wavfiles), 'UniformOutput', false), ' > ');
     end
     txt = strjoin(arrayfun(@(x) sprintf('%s\t%s\tMic-%s', num2str(videoStart(x)), num2str(videoEnd(x)),...
                    rank_txt{x}),...
                    1:length(videoStart), 'UniformOutput', false), '\n');
     fprintf(fopen('loudnessRank_videoTime.txt', 'w'),txt);
end
disp('Done!');
end

function [startTime, endTime, callType] = readLabels()
    labelfile = uigetfile({'*.txt;*.TXT', 'Text file (*.txt)';'*.*', 'All files (*.*)'}, 'Select USV label file');
    labels = readtable(labelfile, 'Delimiter', 'tab');
    startTime = labels{:,1};
    endTime = labels{:,2};
    callType = labels{:,3};
end

function [wavfiles, nSample, sampleRate, y] = readWavs()
    wavfiles = uigetfile({'*.wav;*.WAV','Audio files (*.wav, *.WAV)'; '*.*', 'All files (*.*)'}, 'Select audio files', 'MultiSelect', 'on');
    if ischar(wavfiles)
        % only 1 file
        error('Select multiple audio files');
    elseif length(wavfiles)==1
        % user cancelled
        return;
    end

    % check audio files
    nSamples = zeros(length(wavfiles),1);
    Rates = zeros(length(wavfiles),1);
    for i=1:length(wavfiles)
        info = audioinfo(wavfiles{i});
        nSamples(i) = info.TotalSamples;
        Rates(i) = info.SampleRate;
    end
    nSample = unique(nSamples);
    sampleRate = unique(Rates);
    if length(unique(nSamples)) ~= 1
        error('Audio files must have same number of samples');
    elseif length(unique(Rates)) ~= 1
        error('Audio files must have same sample rates');
    end

    % read audio
    y = zeros(unique(nSamples), length(wavfiles));

    for i=1:length(wavfiles)
        fprintf('Reading audio file %i/%i...\n', i, length(wavfiles));
        y(:,i)= audioread(wavfiles{i});
    end
end

function ranking = rank_index(data)
    sorted = sort(data,'descend');
    ranking = zeros(length(data),1);
    for i=1:length(data)
        ranking(i) = find(data==sorted(i));
    end
end

