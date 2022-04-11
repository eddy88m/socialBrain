function audioTTL_result = audioTTL(filename,userSetting)
%{
audioTTL gets time when TTL input switched from 0 to 1 in LSB of .wav files
Multiple files can be selected.
It can take filename and userSetting as arguments.
userSetting is 1x3 cell of writeTxt,ignoreShort,ignoreShorterThan
e.g. {false,true,100}

%}

if ~exist('filename','var') || isempty(filename)
    [filename] = uigetfile('*.wav', 'Select wav file', 'MultiSelect', 'on');
end
if ~filename
    return % user cancel
end
if ischar(filename)
    filename = {filename};
end

if exist('userSetting','var')
    writeTxt = userSetting{1};
    ignoreShort = userSetting{2};
    ignoreShorterThan = userSetting{3};
    if ~islogical(writeTxt) ||...
            ~islogical(ignoreShort) || ...
            ~isnumeric(ignoreShorterThan)
        error('Invalid userSetting')
    end
else
    [writeTxt, ignoreShort, ignoreShorterThan] = userInput();
end
if ischar(ignoreShorterThan)
    ignoreShorterThan = str2double(ignoreShorterThan);
end

wait = waitbar(0, 'Getting TTL from audio files');
audioTTL_result = struct();

% get TTL
for i=1:length(filename)
    waitbar(i/length(filename), wait);
    [USV,Fs] = audioread(filename{i}, 'native');
    
    TriggerBit = 1;
    SoundTrigger = bitget(USV, TriggerBit); 
    if ignoreShort
        upSampleCandidates = find(diff(SoundTrigger) == -1) + 1;
        Ups = find(SoundTrigger==0);
        TriggerSampleCount = 1;
        SampleCandDur = [];
        k=1;
        for s=1:length(Ups)-1
            if s~=length(Ups)-1 && Ups(s+1)==Ups(s)+1 % next Up = next sample
                TriggerSampleCount = TriggerSampleCount +1;
            elseif s==length(Ups)-1 && Ups(s)+1==Ups(end)
                TriggerSampleCount = TriggerSampleCount +1;
                SampleCandDur(k,1) = TriggerSampleCount;
            elseif s==length(Ups)-1 && Ups(s)+1 ~= Ups(end)
                SampleCandDur(k+1,1) = 1;
            else
                SampleCandDur(k,1) = TriggerSampleCount;
                k=k+1;
                TriggerSampleCount=1; % reset
            end
        end
        ms2s = 1e-3;
        ignoreSamples = ignoreShorterThan * ms2s * Fs;
        if length(SampleCandDur)~=length(upSampleCandidates)
            error('length of SampleCandDur and SampleCandidates do not match.')
        end
        k=1;
        TriggerUpSamples = [];
        for s=1:length(SampleCandDur)
            if SampleCandDur(s) >= ignoreSamples
                TriggerUpSamples(k,1) = upSampleCandidates(s);
                k=k+1;
            end
        end
        TriggerDownSamples = [];
        for s=1:length(TriggerUpSamples)
            thisDur = SampleCandDur(find(upSampleCandidates==TriggerUpSamples(s)));
            TriggerDownSamples(s,1) = TriggerUpSamples(s,1) + SampleCandDur(find(upSampleCandidates==TriggerUpSamples(s)));
        end
    else
        TriggerUpSamples = find(diff(SoundTrigger) == +1) + 1;
        TriggerDownSamples = find(diff(SoundTrigger) == -1);
    end
    
    audioTTL_result(i).filename = filename{i};
    audioTTL_result(i).TTL_Up_in_s = TriggerUpSamples / Fs;
    audioTTL_result(i).TTL_Down_in_s = TriggerDownSamples / Fs;
    audioTTL_result(i).SoundTrigger = SoundTrigger;
    
    % write to tab-delimited text file
    if writeTxt
         tbl = table(audioTTL_result(i).TTL_Up_in_s, audioTTL_result(i).TTL_Down_in_s);
         writetable(tbl, strrep(filename{i}, '.wav', '_audioTTL.txt')...
             , 'Delimiter', 'tab'...
             , 'WriteVariableNames', false...
         );
    end
end
close(wait);
end

function [writeTxt, ignoreShort, ignoreShorterThan] = userInput()
    d = dialog('Position', [500 200 200 150], 'Name', 'audioTTL');
    checkbox = uitable('Parent', d...
                       , 'ColumnFormat', {'logical', 'char'}...
                       , 'ColumnWidth', {15, 135}...
                       , 'ColumnEditable', [true, false]...
                       , 'Position', [25 90 160 40]...
                       , 'Units', 'norm'...
                       , 'ColumnName', []...
                       , 'RowName', []...
                       , 'Data', {false 'Save results as .txt files'...
                                ; false 'Ignore short pulses'...
                       }...
                       , 'TooltipString', sprintf(['TTL inputs can have ringing artifacts. ' ...
                                        , 'Here you can specify the threshold in ms, ' ...
                                        , 'and TTL pulses shorter than it will be excluded from the result.'...
                                        ])...
                       , 'CellEditCallback', @checkbox_callback...
    );
    txt = uicontrol('Parent', d...
                       , 'Style', 'text'...
                       , 'Position', [25 50 130 20]...
                       , 'HorizontalAlignment', 'Left'...
                       , 'String', 'Ignore shorter than [ms]: '...
    );
    writeTxt = false;
    ignoreShort = false;
    ignoreShorterThan = '100';
    txtbox = uicontrol('Parent', d...
                       , 'Style', 'edit'...
                       , 'Position', [150 52 40 20]...
                       , 'String', ignoreShorterThan...
                       , 'callback', @txt_callback...
    );
    OKbtn = uicontrol('Parent', d...
                       , 'Position', [115 20 70 25]...
                       , 'String', 'OK'...
                       , 'Callback', 'delete(gcf)'...
    );
    uiwait(d);
    function checkbox_callback(obj, callbackdata)
        tableData = get(obj, 'Data');
        checkboxData = cell2mat(tableData(:,1));
        writeTxt = checkboxData(1);
        ignoreShort = checkboxData(2);
    end
    function txt_callback(obj, callbackdata)
        ignoreShorterThan = str2double(obj.String);
    end
end