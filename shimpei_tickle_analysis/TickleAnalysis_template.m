% Tickle Analysis - Shimpei June 2014
% 
% 1. NLX finding trigers
%     Detect TTL triggers (Start/End) in NLX. This must be executed first.
%     Set the current folder to the NLX data folder.
%     Products: "Triggers" structure: NLX_TrgStart, NLX_TrgEnd, NLX_Dur
% 
% 2. Load ELAN file
%     Load .txt file exported by ELAN.
%     It extracts trigger information (start = onset of the first baseline; end = offset of the last baseline)
%     It also extracts phase/session start/end.
%     It then converts ELAN phase time to NLX time.
%     Prerequisite: Run 1. NLX finding triggers, .txt file from ELAN
%     Products: "ELAN" structure: Video_PhaseStart/End/Names, Video_PhaseStart/End_NLXtime
%                                 Video_SessionStart/End_NLXtime,
%                                 Video_SessionNo
%               "Triggers" structure: Video_TrgStart/End/Dur,
%                                     Video_NlxOffset, Video_Error
% 
% 2.2 NLX finding stim
%    since August 2015, stimulation timing can be logged in the event file via
%    TTL port 2
% 
% 2.3 NLX finding USB playback
%     USB playback timing in TTL port 3 from UltraSoundGate Player 116
% 
% 
% 
% 3. Real Time Frame
%     VirtualDub exports actual captured time for each frame. In case I
%     have this "*frames.txt" file, this script corrects Phase times.
%     Prerequisites: Run 1&2; *frames.txt file from VirtualDub.
%     Products: ELAN.Video_PhaseStart/End (updated),
%               ELAN.Video_PhaseStart/End_NLXtime (updated)
% 
% 4. Audio finding triggers
%     Detect TTL triggers (saved in LSB) in .wav file. Note that filtered
%     *_f.wav file cannot be used.
%     Prerequisites: *.wav file
%     Products: "Triggers" structure: Audio_TrgStart/End, Audio_Dur,
%                                     Audio_NlxOffset, Audio_Error
% 
% 5. Load USVs
%     Load USV labels/times from .txt file exported by Falk's call-o-matic
%     analysis.
%     Prerequisites: *USV_Labels.txt
%     Products: "USV" structure: USV_Start/End/Type
%                                USV_Start/End_NLXtime
%                                USV_Start/End_NLXtime_Norm
% 6. USV raster plot
%     This script plots USVs (black lines) over phases (colourd boxes) with
%     session borders (dashed red lines). It also creates USV-type
%     distribution.
%     Products: two figures
% 
% 7. NLX times in [ms]
%     Converts NLX times into [ms] for uploading to the database
%     Products: NLXtimeInMilisec structure
% 
% 8.Make tickle phase event file
%     For raw trace navigation in Neuraview.
%     Prepare: NLXtimeInMilisec
%     Products: TicklePhases.nev in the current folder


%% 1. NLX finding triggers

disp('NLX finding triggers')
microseconds = 1e-6;
[TimeStamp, ~, TTLs,~,Strings ] = MoritzNlx2MatEV('Events.nev');
TTLEvents = strncmp(cellstr(Strings), 'Digital Lynx Parallel Input Port TTL', 35);
% In case recorded with Digital Lynx SX, the description in the event file
% is different.
if sum(TTLEvents) == 0
    TTLEvents = strncmp(cellstr(Strings), 'TTL Input on AcqSystem1_0 board 0 port 0', 40); % read only port 0
end
if sum(TTLEvents) == 0
    warning('cannot find a TTL event');
end
Channel1 = bitget(TTLs, 1);
% Channel1Up = cat(2, false, diff(Channel1) == 1);
TriggerTimeStamps = double(TimeStamp(TTLEvents' & Channel1)) * microseconds;
% There might be many short triggers when releasing the button, which
% should be excluded. I assume time between start and end is >2 sec, and
% duration of pressing the button is <2 sec. Triggers within 2 sec after a
% trigger will be ignored.
IgnoreTime = 2;
TrgTimeStamps_Screened(1,1)=TriggerTimeStamps(1);
Interval = diff(TriggerTimeStamps);
k=2;
for i=1:length(Interval)
    if Interval(i) >= IgnoreTime
        TrgTimeStamps_Screened(k,1) = TriggerTimeStamps(i+1);
        k=k+1;
    end
end
if length(TrgTimeStamps_Screened)~= 2
    warning('not exactly 2 triggers')
end


Triggers.NLX_TrgStart = TrgTimeStamps_Screened(1);
Triggers.NLX_TrgEnd = TrgTimeStamps_Screened(2);
Triggers.NLX_Dur = Triggers.NLX_TrgEnd - Triggers.NLX_TrgStart;

%TickleTimer_Dur=30+(7+1+7+15+15+15+15+15)*NoOfSessions+15;

if length(TrgTimeStamps_Screened)== 2
    clear TrgTimeStamps_Screened
end

clear microseconds TTLEvents TimeStamp TTLs Strings Channel1 Channel1Up TriggerTimeStamps NoOfEventsNeeded
clear IgnoreTime i Interval k 

%% 2. Load ELAN file
% requires .txt file from ELAN

ELAN_file = dir('*ELAN_labeled.txt');
if numel(ELAN_file)~=1
    disp('Not exactly one ELAN file.')
end

ELAN_labels=readtable(ELAN_file.name,'Delimiter','tab', 'ReadVariableNames', false);
ELAN.Video_PhaseStart = ELAN_labels{:,{'Var1'}};  % extract values from table to array
ELAN.Video_PhaseEnd = ELAN_labels{:,{'Var2'}};
ELAN.Video_PhaseNames = ELAN_labels{:,{'Var3'}};
Triggers.Video_TrgStart = ELAN.Video_PhaseStart(1); % the beginning of Baseline should be the first LED lighting time i.e. beginning of the recording
Triggers.Video_TrgEnd = ELAN.Video_PhaseEnd(end); % the end of the last Baseline should be the second LED lighting time i.e. the end of the recording
Triggers.Video_Dur = Triggers.Video_TrgEnd - Triggers.Video_TrgStart;
Triggers.Video_NlxOffset = Triggers.NLX_TrgStart - Triggers.Video_TrgStart;    % To convert time in NLX time, add Offset to the time

Triggers.Video_Error = Triggers.NLX_Dur - Triggers.Video_Dur;
disp('ELAN file is loaded')
disp(['Video_Dur error (vs. NLX) ' num2str(Triggers.Video_Error) ' s'])

clear ELAN_labels ELAN_file

% Align to NLX time
ELAN.Video_PhaseStart_NLXtime=ELAN.Video_PhaseStart+Triggers.Video_NlxOffset;
ELAN.Video_PhaseEnd_NLXtime=ELAN.Video_PhaseEnd+Triggers.Video_NlxOffset;

% ELAN session time
% check start, end and names have the same length
NoOfPhases = length(ELAN.Video_PhaseStart_NLXtime);
same_length = isequal(NoOfPhases,length(ELAN.Video_PhaseEnd_NLXtime),length(ELAN.Video_PhaseNames));
if same_length == 0
    error('length of PhaseStart, PhaseEnd and PhaseNames should be the same. I stop here.')
end

keyPhase = 'Dorsal'; % the first phase in a session
% keyPhase = 'Session change'; % For playback experiments
Baseline = 'Baseline';

SessionNo = 0;  % start with 0, so that the first baseline is session0, the first tickling session is session1.
for i=1:NoOfPhases
    if strcmp(lower(ELAN.Video_PhaseNames(i)),lower(Baseline))|| strcmp(lower(ELAN.Video_PhaseNames(i)),lower(keyPhase))
        ELAN.Video_SessionStart_NLXtime(SessionNo+1,:)=ELAN.Video_PhaseStart_NLXtime(i);
        % bug ELAN.Video_SessionEnd_NLXtime(SessionNo+1,:)=ELAN.Video_PhaseEnd_NLXtime(i);
        ELAN.Video_SessionNo(SessionNo+1,:)=SessionNo;
        SessionNo=SessionNo+1;
    end
end
for i=1:length(ELAN.Video_SessionNo)
    if i ~= length(ELAN.Video_SessionNo)
        ELAN.Video_SessionEnd_NLXtime(i,1) = ELAN.Video_SessionStart_NLXtime(i+1);
    else
        ELAN.Video_SessionEnd_NLXtime(i,1) = ELAN.Video_PhaseEnd_NLXtime(end);
    end
end

Triggers.Video_FrameTimeCorrected=0;        
disp('ELAN session time was extracted')

clear same_length NoOfPhases keyPhase Baseline i SessionNo

%% Reset Session
% Make sessions just baseline and session 1
disp('Reset Session')
if ~exist('ELAN')
    error('ELAN does not exist')
end
if max(ELAN.Video_SessionNo) < 2
%     error('There are no more than 2 sessions')
end
if ~strcmp(ELAN.Video_PhaseNames, 'Baseline')
    error('The first phase name is not Baseline')
end
ELAN.Video_SessionNo = [];
ELAN.Video_SessionStart_NLXtime = [];
ELAN.Video_SessionEnd_NLXtime = [];

ELAN.Video_SessionStart_NLXtime(1,1) = ELAN.Video_PhaseStart_NLXtime(1);
ELAN.Video_SessionEnd_NLXtime(1,1) = ELAN.Video_PhaseEnd_NLXtime(1);
ELAN.Video_SessionStart_NLXtime(2,1) = ELAN.Video_PhaseStart_NLXtime(2);
ELAN.Video_SessionEnd_NLXtime(2,1) = ELAN.Video_PhaseEnd_NLXtime(end);
ELAN.Video_SessionNo = [0 1]';


%% 2.2 NLX finding stim
% since August 2015, stimulation timing can be logged in the event file via
% TTL port 2
disp('NLX finding stim')
microseconds = 1e-6;
[TimeStamp, ~, TTLs,~,Strings ] = MoritzNlx2MatEV('Events.nev');
TTLEvents = strncmp(cellstr(Strings), 'TTL Input on AcqSystem1_0 board 0 port 2', 40); % read only port 2
if sum(TTLEvents) == 0
    warning('cannot find a TTL event');
end
Channel1 = bitget(TTLs, 1);
% Channel1Up = cat(2, false, diff(Channel1) == 1);
% Channel1Down = ~Channel1Up;
% StimStart = double(TimeStamp(TTLEvents' & Channel1Up)) * microseconds;
% StimEnd = double(TimeStamp(TTLEvents' & Channel1Down)) * microseconds;
% Since Playback TTL is opposite, there will be the same TTL one after the
% other (e.g. 1 1 or 0 0). Due to this, Channel1Up / Down system does not
% work properly. 
StimStart = double(TimeStamp(TTLEvents' & Channel1)) * microseconds;
StimEnd = double(TimeStamp(TTLEvents' & ~Channel1)) * microseconds;

% delete stimulation phases if exist (in case imported from ELAN)
% for thisPhase = 1:length(

% integrate stim phases in ELAN
if ~exist('ELAN', 'var')
    error('execute Load ELAN file first');
end
if Triggers.Video_FrameTimeCorrected ~= 1;
    error('execute Real Frame Time first');
end
StimName = {'stimulation'};
insert = @(a, x, n)cat(2, x(1:n-1), a,  x(n:end)); % function handle to insert a into x at nth)
for ThisStim = 1:length(StimStart)
    InsertHere = numel(ELAN.Video_PhaseStart_NLXtime(ELAN.Video_PhaseStart_NLXtime < StimStart(ThisStim))) + 1;
    ELAN.Video_PhaseStart_NLXtime = insert(StimStart(ThisStim), ELAN.Video_PhaseStart_NLXtime', InsertHere)';
    ELAN.Video_PhaseEnd_NLXtime = insert(StimEnd(ThisStim), ELAN.Video_PhaseEnd_NLXtime', InsertHere)';
    ELAN.Video_PhaseNames = insert(StimName, ELAN.Video_PhaseNames', InsertHere)';
end



clear microseconds TTLEvents TimeStamp TTLs Strings Channel1 Channel1Up TriggerTimeStamps NoOfEventsNeeded
clear IgnoreTime i Interval k Channel1Down OnsetTimeStamps OffsetTimeStamps ans StimName insert ThisStim
clear InsertHere StimStart StimEnd

%% 2.3 NLX finding USV playback
% finding start / end time of USB playback in TTL port 3
% note that bit 0 is start, bit 1 is end
disp('NLX finding USB playback');
microseconds = 1e-6;
[TimeStamp, ~, TTLs,~,Strings ] = MoritzNlx2MatEV('Events.nev');
TTLEvents = strncmp(cellstr(Strings), 'TTL Input on AcqSystem1_0 board 0 port 3', 40); % read only port 3
if sum(TTLEvents) == 0
    warning('cannot find a TTL event');
end

TimeStamp = double(TimeStamp(TTLEvents)); % get port 3 event timestamp
TTLs = ~logical(TTLs(TTLEvents)); % get port 3 TTL (TTL from the PB device is "flipped")
% clear oscillation
IgnoreTime = 100000; % 100 ms
TimeStamp_screened(1,1) = TimeStamp(1);
TTLs_screened = TTLs(1);
k=2;
counted = 0;
for i=2:length(TimeStamp)
    if i ~= length(TimeStamp)
        if TimeStamp(i+1) - TimeStamp(i) >= IgnoreTime % long interval ahead
            TimeStamp_screened(k, 1) = TimeStamp(i);
            TTLs_screened(k, 1) = TTLs(i);
            counted = 1;
            k=k+1;
        elseif counted == 1; % long interval before
            TimeStamp_screened(k, 1) = TimeStamp(i);
            TTLs_screened(k, 1) = TTLs(i);
            counted = 0;
            k=k+1;
        end
    else % the last point
        TimeStamp_screened(k, 1) = TimeStamp(i);
        TTLs_screened(k, 1) = TTLs(i);
    end
end
% figure
% hold on
% plot(TimeStamp, TTLs)
% plot(TimeStamp_screened, TTLs_screened+1)
% hold off
pbStart = TimeStamp_screened(TTLs_screened) * microseconds;
pbEnd = TimeStamp_screened(~TTLs_screened) * microseconds;

% integrate playback phases in ELAN
if ~exist('ELAN', 'var')
    error('execute Load ELAN file first');
end
if Triggers.Video_FrameTimeCorrected ~= 1;
    error('execute Real Frame Time first');
end
StimName = {'playback'};
insert = @(a, x, n)cat(2, x(1:n-1), a,  x(n:end)); % function handle to insert a into x at nth)
for ThisStim = 1:length(pbStart)
    InsertHere = numel(ELAN.Video_PhaseStart_NLXtime(ELAN.Video_PhaseStart_NLXtime < pbStart(ThisStim))) + 1;
    ELAN.Video_PhaseStart_NLXtime = insert(pbStart(ThisStim), ELAN.Video_PhaseStart_NLXtime', InsertHere)';
    ELAN.Video_PhaseEnd_NLXtime = insert(pbEnd(ThisStim), ELAN.Video_PhaseEnd_NLXtime', InsertHere)';
    ELAN.Video_PhaseNames = insert(StimName, ELAN.Video_PhaseNames', InsertHere)';
end



clear microseconds TTLEvents TimeStamp TTLs Strings Channel1 Channel1Up TriggerTimeStamps NoOfEventsNeeded
clear IgnoreTime i Interval k Channel1Down OnsetTimeStamps OffsetTimeStamps ans StimName insert ThisStim
clear InsertHere pbStart pbEnd
clear counted TimeStamp_screened TTLs_screened

%% NLX finding nose-poke
disp('NLX finding nose-poke');
microseconds = 1e-6;
[TimeStamp, ~, TTLs,~,Strings ] = MoritzNlx2MatEV('Events.nev');
TTLEvents = strncmp(cellstr(Strings), 'TTL Input on AcqSystem1_0 board 0 port 3', 40); % read only port 3
if sum(TTLEvents) == 0
    warning('cannot find a TTL event');
end

TimeStamp = double(TimeStamp(TTLEvents)); % get port 3 event timestamp
TTLs = logical(TTLs(TTLEvents)-128); % get port 3 TTL (129 at "on", 1 at "off")

pokeStart = TimeStamp(TTLs) * microseconds;
pokeEnd = TimeStamp(~TTLs) * microseconds;

% integrate playback phases in ELAN
if ~exist('ELAN', 'var')
    error('execute Load ELAN file first');
end
if Triggers.Video_FrameTimeCorrected ~= 1;
    error('execute Real Frame Time first');
end
pokeName = {'nose-poke'};
insert = @(a, x, n)cat(2, x(1:n-1), a,  x(n:end)); % function handle to insert a into x at nth)
for ThisPoke = 1:length(pokeStart)
    InsertHere = numel(ELAN.Video_PhaseStart_NLXtime(ELAN.Video_PhaseStart_NLXtime < pokeStart(ThisPoke))) + 1;
    ELAN.Video_PhaseStart_NLXtime = insert(pokeStart(ThisPoke), ELAN.Video_PhaseStart_NLXtime', InsertHere)';
    ELAN.Video_PhaseEnd_NLXtime = insert(pokeEnd(ThisPoke), ELAN.Video_PhaseEnd_NLXtime', InsertHere)';
    ELAN.Video_PhaseNames = insert(pokeName, ELAN.Video_PhaseNames', InsertHere)';
end



clear microseconds TTLEvents TimeStamp TTLs Strings Channel1 Channel1Up TriggerTimeStamps NoOfEventsNeeded
clear IgnoreTime i Interval k Channel1Down OnsetTimeStamps OffsetTimeStamps ans StimName insert ThisStim
clear InsertHere pbStart pbEnd
clear counted TimeStamp_screened TTLs_screened ThisPoke pokeName pokeStart pokeEnd

%% 2.3.2 Playback phase labelling
% semi-automated labeling of what kind of USV PB according to Section
disp('Playback phase labeling');
if ~exist('ELAN')
    error('ELAN structure not found')
end
if sum(ismember(ELAN.Video_PhaseNames, 'Session change')) == 0
    error('No ''Session change'' phase found!')
end
PB_sessions = [{'PB Comb'} {'PB Artificial'} {'PB Fear'}];
PB_Art = [{'PB White noise'} {'PB Art 50'} {'PB Art 22'}];
PB_Art_idx = 1;
this_session = 1;
this_PB = '';
for i=1:length(ELAN.Video_PhaseNames)
    if strcmp(ELAN.Video_PhaseNames(i), 'Session change')
        this_session = this_session + 1;
    end
    if strcmp(ELAN.Video_PhaseNames(i), 'playback') | regexp(ELAN.Video_PhaseNames{i}, regexptranslate('wildcard', 'PB*'))
        if strcmp(PB_sessions(this_session), 'PB Artificial') % rotation in PB_Art
            this_PB = PB_Art(PB_Art_idx);
            PB_Art_idx = PB_Art_idx + 1;
            if PB_Art_idx > length(PB_Art)
                PB_Art_idx = 1;
            end
        else
            this_PB = PB_sessions(this_session);
        end
        ELAN.Video_PhaseNames(i) = this_PB; % re-label PB phases
    end
    ELAN.Video_PhaseNames(i);
end

clear ans i PB_Art PB_Art_idx PB_sessions this_session this_PB
%% Fill with break
% for PB experiments, add break phases on non-labelled periods
% do this after PB import, Real Frame Time, before NLXtimeInMilisec
clc
disp('Fill with break')
if ~exist('ELAN')
    error('ELAN structure not found')
elseif sum(ismember(ELAN.Video_PhaseNames, 'Baseline')) ~= 1
    error('No Baseline phase found')
end

interval = 0.5; % [s] non-labeled periods longer than this will be lableled as Break
break_start = [];
break_end =[];
idx = 1;
for phase = 1:length(ELAN.Video_PhaseStart_NLXtime)-1
    if ELAN.Video_PhaseStart_NLXtime(phase+1) - ELAN.Video_PhaseEnd_NLXtime(phase) > interval
        break_start(idx,1) = ELAN.Video_PhaseEnd_NLXtime(phase);
        break_end(idx,1) = ELAN.Video_PhaseStart_NLXtime(phase+1);
        idx = idx + 1;
     end
end

insert = @(a, x, n)cat(2, x(1:n-1), a,  x(n:end)); % function handle to insert a into x at nth) 
phase_name = {'Break'};
for this_break = 1:length(break_start)
    insert_here = numel(ELAN.Video_PhaseStart_NLXtime(ELAN.Video_PhaseStart_NLXtime < break_start(this_break))) + 1;
    ELAN.Video_PhaseStart_NLXtime = insert(break_start(this_break), ELAN.Video_PhaseStart_NLXtime', insert_here)';
    ELAN.Video_PhaseEnd_NLXtime = insert(break_end(this_break), ELAN.Video_PhaseEnd_NLXtime', insert_here)';
    ELAN.Video_PhaseNames = insert(phase_name, ELAN.Video_PhaseNames', insert_here)';
    
end

    

clear phase phase_name insert interval ans idx this_break break_start break_end insert_here
%% 2.4 ELAN Other_Behaviors
% run after loading standard ELAN result
ELAN_file = dir('*ELAN_other_labeled.txt');
if numel(ELAN_file)~=1
    disp('Not exactly one ELAN file.')
end
if ~exist('ELAN')
    error('prepare ELAN structure in the Workspace')
end
if ~exist('Triggers')
    error('prepare Triggers structure in the Workspace')
end
if Triggers.Video_FrameTimeCorrected ~= 1;
    error('execute Real Frame Time first');
end

ELAN_labels=readtable(ELAN_file.name,'Delimiter','tab', 'ReadVariableNames', false);
ELAN_Other.Video_PhaseStart = ELAN_labels{:,{'Var1'}};  % extract values from table to array
ELAN_Other.Video_PhaseEnd = ELAN_labels{:,{'Var2'}};
ELAN_Other.Video_PhaseNames = ELAN_labels{:,{'Var3'}};
disp('ELAN file is loaded')
% Triggers.Video_TrgStart = ELAN_Other.Video_PhaseStart(1); % the beginning of Baseline should be the first LED lighting time i.e. beginning of the recording
% Triggers.Video_TrgEnd = ELAN_Other.Video_PhaseEnd(end); % the end of the last Baseline should be the second LED lighting time i.e. the end of the recording
% Triggers.Video_Dur = Triggers.Video_TrgEnd - Triggers.Video_TrgStart;
% Triggers.Video_NlxOffset = Triggers.NLX_TrgStart - Triggers.Video_TrgStart;    % To convert time in NLX time, add Offset to the time

% Triggers.Video_Error = Triggers.NLX_Dur - Triggers.Video_Dur;
clear ELAN_labels ELAN_file

% Align to NLX time
ELAN_Other.Video_PhaseStart_NLXtime=ELAN_Other.Video_PhaseStart+Triggers.Video_NlxOffset;
ELAN_Other.Video_PhaseEnd_NLXtime=ELAN_Other.Video_PhaseEnd+Triggers.Video_NlxOffset;
% correct NLX time
IFI = 1/30;
PhaseStartFrames = round(ELAN_Other.Video_PhaseStart / IFI);
for i=1:length(PhaseStartFrames)
    ELAN_Other.Video_PhaseStart_NLXtime(i) = ELAN_Other.Video_PhaseStart(i) + Triggers.Video_NlxOffset;
    ELAN_Other.Video_PhaseEnd_NLXtime(i) = ELAN_Other.Video_PhaseEnd(i) + Triggers.Video_NlxOffset;
end
clear IFI PhaseStartFrames i

%% 3. Real Frame Time
% VirtualDub can export time (in [ms]) when a frame was captured for each frame.
% ELAN can export only times but not frames.
% ELAN times are divided by IFI (0.033 s) to get frame numbers
% Then access to the real frame time.

% Load real frame times (.txt file)
% FrameFile = dir('*frames.txt');
% if numel(FrameFile) ~= 1
%     error('not exactly one frames.txt file')
% end
% Table = readtable(FrameFile.name, 'Delimiter','tab','ReadVariableNames',true);
% RealFrameTime = Table{:,{'VCapTime'}};
% Load real frame times (.csv file)
FrameFile = dir('*frames.csv');
if numel(FrameFile) ~= 1
    FrameFile = dir('*cam1_frames.csv')
    if numel(FrameFile) ~= 1
        error('not exactly one frames.csv file')
    end
end
Table = csvread(FrameFile.name, 1);
RealFrameTime = Table(:,2); % in [ms]

% start from 0 ms
RealFrameTime = RealFrameTime - RealFrameTime(1);

% ELAN times -> frames
IFI = 1/30;
PhaseStartFrames = round(ELAN.Video_PhaseStart / IFI);
PhaseEndFrames = round(ELAN.Video_PhaseEnd / IFI);

% getting real frame times and overwrite
milisecond = 1e-3;
for i=1:length(PhaseStartFrames)
    ELAN.Video_PhaseStart(i) = RealFrameTime(PhaseStartFrames(i))*milisecond;
    ELAN.Video_PhaseEnd(i) = RealFrameTime(PhaseEndFrames(i))*milisecond;
end

% update Triggers
Triggers.Video_TrgStart = ELAN.Video_PhaseStart(1); % the beginning of Baseline should be the first LED lighting time i.e. beginning of the recording
Triggers.Video_TrgEnd = ELAN.Video_PhaseEnd(end); % the end of the last Baseline should be the second LED lighting time i.e. the end of the recording
Triggers.Video_Dur = Triggers.Video_TrgEnd - Triggers.Video_TrgStart;
Triggers.Video_NlxOffset = Triggers.NLX_TrgStart - Triggers.Video_TrgStart;    % To convert time in NLX time, add Offset to the time

Triggers.Video_Error = Triggers.NLX_Dur - Triggers.Video_Dur;
disp('Video phase times are corrected to actual captured time')
disp(['Video_Dur error (vs. NLX) ' num2str(Triggers.Video_Error) ' s'])

% update NLX time
for i=1:length(PhaseStartFrames)
    ELAN.Video_PhaseStart_NLXtime(i) = ELAN.Video_PhaseStart(i) + Triggers.Video_NlxOffset;
    ELAN.Video_PhaseEnd_NLXtime(i) = ELAN.Video_PhaseEnd(i) + Triggers.Video_NlxOffset;
end

% update session time
% check start, end and names have the same length
NoOfPhases = length(ELAN.Video_PhaseStart_NLXtime);
same_length = isequal(NoOfPhases,length(ELAN.Video_PhaseEnd_NLXtime),length(ELAN.Video_PhaseNames));
if same_length == 0
    error('length of PhaseStart, PhaseEnd and PhaseNames should be the same. I stop here.')
end

keyPhase = 'Dorsal'; % the first phase in a session
Baseline = 'Baseline';

SessionNo = 0;  % start with 0, so that the first baseline is session0, the first tickling session is session1.
for i=1:NoOfPhases
    if strcmp(lower(ELAN.Video_PhaseNames(i)),lower(Baseline))|| strcmp(lower(ELAN.Video_PhaseNames(i)),lower(keyPhase))
        ELAN.Video_SessionStart_NLXtime(SessionNo+1,:)=ELAN.Video_PhaseStart_NLXtime(i);
        % bug ELAN.Video_SessionEnd_NLXtime(SessionNo+1,:)=ELAN.Video_PhaseEnd_NLXtime(i);
        ELAN.Video_SessionNo(SessionNo+1,:)=SessionNo;
        SessionNo=SessionNo+1;
    end
end
for i=1:length(ELAN.Video_SessionNo)
    if i ~= length(ELAN.Video_SessionNo)
        ELAN.Video_SessionEnd_NLXtime(i,1) = ELAN.Video_SessionStart_NLXtime(i+1);
    else
        ELAN.Video_SessionEnd_NLXtime(i,1) = ELAN.Video_PhaseEnd_NLXtime(end);
    end
end

Triggers.Video_FrameTimeCorrected=1;
        
clear same_length NoOfPhases keyPhase Baseline i SessionNo
clear FrameFile Table IFI RealFrameTime PhaseStartFrames PhaseEndFrames milisecond i 

%% Get video phase time from NLX time
% For playback experiment, phase comments needs to be added ("hand still",
% "hand moving" etc.). To do it, you need to go back to the video with
% referencing PB time.
disp('Get video phase time for PB comments');
if ~exist('ELAN')
    error('prepare ELAN structure in the Workspace')
end
if ~exist('Triggers')
    error('prepare Triggers structure in the workspace')
end
VideoPhaseTime = [ELAN.Video_PhaseNames num2cell(ELAN.Video_PhaseStart_NLXtime - Triggers.Video_NlxOffset) num2cell(ELAN.Video_PhaseEnd_NLXtime - Triggers.Video_NlxOffset)];
cell2csv('VideoPhaseTime.csv', VideoPhaseTime);

%% Write nose-poke times in JavaScript for AE
if ~exist('ELAN','var')
    throw(MException('MATLAB:DataNotFound','workspace variable ''ELAN'' not found!'));
end
video_starts = ELAN.Video_PhaseStart_NLXtime - Triggers.Video_NlxOffset;
video_ends = ELAN.Video_PhaseEnd_NLXtime - Triggers.Video_NlxOffset;

phase2export = {'nose-poke', 'Nose poke failed'};
phases = ELAN.Video_PhaseNames(ismember(ELAN.Video_PhaseNames, phase2export));
if isempty(phases)
    throw(MException('MATLAB:DataNotFound','No nose-poke phases found'));
end
starts = video_starts(ismember(ELAN.Video_PhaseNames, phase2export));
ends = video_ends(ismember(ELAN.Video_PhaseNames, phase2export));

% export text
txt = strjoin(arrayfun(@(x) sprintf('[''%s'', %s, %s]',phases{x},num2str(starts(x)),num2str(ends(x))),1:length(phases),'UniformOutput',false)...
             , ',\n');
txt = strcat('var phases = [', txt, ']');
fprintf(fopen('nose-poke_times.txt','w'),txt);


clear phase2export video_starts video_ends
%% Write freezing times in JavaScript for AE
if ~exist('ELAN_Other','var')
    throw(MException('MATLAB:DataNotFound','workspace variable ''ELAN'' not found!'));
end
video_starts = ELAN_Other.Video_PhaseStart_NLXtime - Triggers.Video_NlxOffset;
video_ends = ELAN_Other.Video_PhaseEnd_NLXtime - Triggers.Video_NlxOffset;

phase2export = {'Freezing'};
phases = ELAN_Other.Video_PhaseNames(ismember(ELAN_Other.Video_PhaseNames, phase2export));
if isempty(phases)
    throw(MException('MATLAB:DataNotFound','No freezing phases found'));
end
starts = video_starts(ismember(ELAN_Other.Video_PhaseNames, phase2export));
ends = video_ends(ismember(ELAN_Other.Video_PhaseNames, phase2export));

% export text
txt = strjoin(arrayfun(@(x) sprintf('[''%s'', %s, %s]',phases{x},num2str(starts(x)),num2str(ends(x))),1:length(phases),'UniformOutput',false)...
             , ',\n');
txt = strcat('var phases = [', txt, ']');
fprintf(fopen('freezing_times.txt','w'),txt);


%% 4. Audio finding triggers

disp('Audio finding triggers')
wavfile=dir('*.wav');  % Do not use filtered (*f.wav) file, which may contain many triggers for some reasons.
% exclude *_f.wav from dir list
for i=1:length(wavfile)
    if regexp(wavfile(i).name,regexptranslate('wildcard','*_f.WAV'))==1
        wavfile(i)=[];
    end
end 
if numel(wavfile) ~= 1
    ls('*.wav')
    error('not exactly one .wav file')
end
if ~exist(wavfile.name)
    error('wav file not found');
end
USV=audioread(wavfile.name,'native');
info = audioinfo(wavfile.name);
Fs = info.SampleRate;

TriggerBit = 1;
SoundTrigger=bitget(USV,TriggerBit);

SampleCandidates = find(diff(SoundTrigger) == +1)+1;

% calculate duration of triggers
Ups=find(SoundTrigger==1);
TriggerSampleCount=1;
k=1;
for i=1:length(Ups)-1
    if  i~=length(Ups)-1 && Ups(i+1)==Ups(i)+1
        TriggerSampleCount = TriggerSampleCount +1;
    elseif i==length(Ups)-1 && Ups(i)+1 ==Ups(end)
        TriggerSampleCount = TriggerSampleCount +1;
        SampleCandDur(k,1)=TriggerSampleCount;
    elseif i==length(Ups)-1 && Ups(i)+1 ~= Ups(end)
        SampleCandDur(k+1,1)=1;
    else
        SampleCandDur(k,1)=TriggerSampleCount;
        k=k+1;
        TriggerSampleCount=1; % reset
    end
end

IgnoreShorterThan = 2500; % triggers <2500 samples (10 ms) are excluded
if length(SampleCandDur)~=length(SampleCandidates)
    error('length of SampleCandDur and SampleCandidates do not match.')
end
k=1;
for i=1:length(SampleCandDur)
    if SampleCandDur(i)>= IgnoreShorterThan
        TriggerUpSamples(k,1) = SampleCandidates(i);
        k=k+1;
    end
end
if length(TriggerUpSamples)~= 2
    error('not exactly 2 triggers')
end
clear i TriggerSampleCount k IgnoreShorterThan Ups SampleCandDur
disp('Audio triggers are found')

Triggers.Audio_TrgStart = TriggerUpSamples(1) / Fs;
Triggers.Audio_TrgEnd = TriggerUpSamples(2)/Fs;
Triggers.Audio_Dur = Triggers.Audio_TrgEnd - Triggers.Audio_TrgStart;
Triggers.Audio_NlxOffset = Triggers.NLX_TrgStart - Triggers.Audio_TrgStart; % To convert time in NLX time, add Offset to the time

Triggers.Audio_Error = Triggers.NLX_Dur - Triggers.Audio_Dur;
disp(['Audio_Dur error (vs. NLX) ' num2str(Triggers.Audio_Error) ' s'])
    
Triggers.Audio_RealSampleRate = (TriggerUpSamples(2)-TriggerUpSamples(1)) / Triggers.NLX_Dur;

clear i k wavfile USV TriggerBit SoundTrigger SampleCandidates Fs TriggerUpSamples info



%% 5. Load USVs
% requires .txt file from manual Call-o-matic analysis

USVfile = dir('*USV_Labels.txt');
if numel(USVfile)~=1
    error('not exactly one USV_Lablels.txt file')
end

Table=readtable(USVfile.name, 'Delimiter', 'tab', 'ReadVariableNames',false);
USV.USV_Start=Table{:,{'Var1'}};
USV.USV_End=Table{:,{'Var2'}};
USV.USV_Type=Table{:,{'Var3'}};

% In case there is 'un' (unanalyzed) or 'no' (noise: I do not use)
UnIndex = find(strcmpi(USV.USV_Type, 'un'));
if ~isempty(UnIndex)
    warning('You have %d UN types at %s', length(UnIndex), strjoin(arrayfun(@(id) sprintf('%i', id), UnIndex, 'Un', 0)', ','));
end
NoIndex = find(strcmpi(USV.USV_Type, 'no'));
if ~isempty(NoIndex)
    warning('You have %d NO types at %s', length(NoIndex), strjoin(arrayfun(@(id) sprintf('%i', id), NoIndex, 'Un', 0)', ','));
end
% notice if there is 'fc'
FcIndex = find(strcmpi(USV.USV_Type, 'fc'));
if ~isempty(FcIndex)
    warning('You have %d Fear calls at %s', length(FcIndex), strjoin(arrayfun(@(id) sprintf('%i', id), FcIndex, 'Un', 0)', ','));
end
% find duplicates
[C, ia, ic] = unique(USV.USV_Start);
Dup_ID = find(not(ismember(1:numel(C), ia)));
if ~isempty(Dup_ID)
    warning('You have a duplicate at #%s.', strjoin(arrayfun(@(id) sprintf('%i', id), Dup_ID, 'Un', 0)', ','));
end
clear C ia ic Dup_ID

% Align to NLX time
USV.USV_Start_NLXtime = USV.USV_Start + Triggers.Audio_NlxOffset;
USV.USV_End_NLXtime = USV.USV_End + Triggers.Audio_NlxOffset;
disp('USVs are loaded')

% USV time normalize to NLX_Dur
USV.USV_Start_NLXtime_Norm = USV.USV_Start * (Triggers.NLX_Dur/Triggers.Audio_Dur) + Triggers.Audio_NlxOffset;
USV.USV_End_NLXtime_Norm = USV.USV_End * (Triggers.NLX_Dur/Triggers.Audio_Dur) + Triggers.Audio_NlxOffset;

clear Table USVfile UnIndex FcIndex NoIndex



%% 6. USV raster plot
% Check required files
if ~exist('ELAN')
    error('prepare ELAN structure in the Workspace')
end
% Get colours from Database    
db.user = 'shimpei';
db.password = 'tickle';
db.db = 'shimpei_rita';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));
[Phase_type, Hex_color] = mysql('SELECT phase_type, color_code FROM Phase_Types');
for ThisPhase = 1:length(Hex_color)
    Phase_color{ThisPhase,1} = hex2rgb(Hex_color(ThisPhase))/255;
end
mysql('close');

% Plot phases
set(0,'DefaultFigureWindowStyle','docked')
figure
hold on

for ThisPhase = 1:length(ELAN.Video_PhaseNames)
    ColorIndices(ThisPhase,1) = find(strcmpi(Phase_type,ELAN.Video_PhaseNames{ThisPhase}));
    Rect = rectangle('Position', [ELAN.Video_PhaseStart_NLXtime(ThisPhase), 0, ...
                                    ELAN.Video_PhaseEnd_NLXtime(ThisPhase)-ELAN.Video_PhaseStart_NLXtime(ThisPhase), 1]);
    set(Rect, 'FaceColor', Phase_color{ColorIndices(ThisPhase,1)}, ...
                'EdgeColor', 'None')
end

% Legend
uniqIndices = unique(ColorIndices);
for ThisPhase = 1:length(uniqIndices)
    Legend_labels(ThisPhase,1) = Phase_type(uniqIndices(ThisPhase));
    Legend_plot(ThisPhase) = plot(nan, nan, 's', 'markerfacecolor', Phase_color{uniqIndices(ThisPhase)}, 'markeredgecolor', 'none');
end
legend(Legend_plot, Legend_labels, 'Location', 'SouthEastOutside');
    
%Plot the beginning of sessions
for i=1:size(ELAN.Video_SessionStart_NLXtime,1)
    Rect=line([ELAN.Video_SessionStart_NLXtime(i) ELAN.Video_SessionStart_NLXtime(i)], [0 1]);
    set(Rect,'Color','r','LineStyle',':','LineWidth',1)
end
xlabel('NLX time [s]')
% USV types organize
[USV_Categories,~,USV_CatIndex]=unique(USV.USV_Type(:));    % 'bw', 'co', 'fc' etc.
% I wanna have fear call at the top, misc at the second, others are
% anti-alphabetical order
OldCategory=USV_Categories;
USV_Categories=flipud(USV_Categories);
FearCell = find(strcmp(USV_Categories,'fc'));
if isempty(FearCell)~=1 && FearCell~=1
    USV_Categories = ['fc'; USV_Categories(1:FearCell-1); USV_Categories(FearCell+1:end)];
end    
MiscCell = find(strcmp(USV_Categories,'mc'));
if ~isempty(MiscCell)
    if isempty(FearCell)
        if MiscCell~=1
            USV_Categories = ['mc';USV_Categories(1:MiscCell-1); USV_Categories(MiscCell+1:end)];
        end            
    else
        if MiscCell~=2
            USV_Categories = ['fc';'mc';USV_Categories(2:MiscCell-1); USV_Categories(MiscCell+1:end)];
        end
    end
end


NoOfCategories = length(USV_Categories);
for i=1:NoOfCategories
    switch USV_Categories{i}
        case 'tr'
            Ticks{i,1}='Trill';
        case 'sh'
            Ticks{i,1}='Short';
        case 'ru'
            Ticks{i,1}='Ramp up';
        case 'rd'
            Ticks{i,1}='Ramp down'; 
        case 'mt'
            Ticks{i,1}='M-Trill';
        case 'md'
            Ticks{i,1}='Modulated';
        case 'mc'
            Ticks{i,1}='Misc.';
        case 'fl'
            Ticks{i,1}='Flat';
        case 'fc'
            Ticks{i,1}='Fear (22 kHz)';
        case 'co'
            Ticks{i,1}='Combined';
        case 'bw'
            Ticks{i,1}='Bow';
        otherwise
            Ticks{i,1}=USV_Categories{i};
    end
            
end
% Plot USVs (normalized NLX time)
for i=1:size(USV.USV_Start_NLXtime_Norm,1)
    for ThisType=1:NoOfCategories
      switch char(USV.USV_Type(i))
       case char(USV_Categories(ThisType))
           % Option A: as thick as USV length
%         Rect=rectangle('Position',[USV.USV_Start_NLXtime_Norm(i),(ThisType-1)/NoOfCategories,USV.USV_End_NLXtime_Norm(i)-USV.USV_Start_NLXtime_Norm(i),1/NoOfCategories]);
           % Option B: as thick as hairline
%           Rect=rectangle('Position',[USV.USV_Start_NLXtime_Norm(i),(ThisType-1)/NoOfCategories,1,1/NoOfCategories]);
           % Option C: line
           Rect = line([USV.USV_Start_NLXtime_Norm(i) USV.USV_Start_NLXtime_Norm(i)], [(ThisType-1)/NoOfCategories (ThisType)/NoOfCategories]);
           set(Rect, 'Color', [0 0 0], 'LineWidth', 1)

%         set(Rect,'FaceColor',[0/255, 0/255, 0/255])   %black
%         set(Rect,'EdgeColor','None')
      end
    end
end

set(gca,'YLim',[0 1], 'YTick', 0.5/NoOfCategories:1/NoOfCategories:1, 'yticklabel',Ticks)
set(gca,'layer','top') % Axis and ticks in front of the other objects
title('USV')
hold off

% flip the categories for next graph
USV_Categories=flipud(USV_Categories);
Ticks=flipud(Ticks);
% Correct Category Indices
for i=1:length(USV_CatIndex)
    USV_CatIndex(i,1) = find(strcmp(USV_Categories,OldCategory(USV_CatIndex(i))));
end
USVcolor=[150/255, 167/255, 177/255];
% Plot USV types in another graph
% Bar = accumarray(USV_CatIndex, 1, [], @sum); % number of events
Bar = accumarray(USV_CatIndex, 100/length(USV_CatIndex), [], @sum); % fraction
figure
bar(Bar,'facecolor',USVcolor)
set(gca,'XTickLabel',Ticks)
% ylabel('Number of events')
ylabel('Frequency (%)')
% pie chart
figure
for i=1:length(Ticks)
    Ticks{i}=sprintf('%s \n(%.2f%%)', Ticks{i}, Bar(i));
end
pie(Bar,Ticks)
hold off
set(0,'DefaultFigureWindowStyle','normal')
% Cleaning
    clear db Hex_color ThisPhase Rect Bar ColorIndices FearCell i Legend_labels Legend_plot MiscCell NoOfCategories OldCategory Phase_color Phase_type ThisType Ticks uniqIndices
    clear USV_Categories USV_CatIndex USVcolor line


%% 7. NLX times in [ms]
% for database
s2ms = 1e3;
if ~exist('ELAN','var')
    error('prepare ELAN structure')
end
if ~exist('Triggers','var')
    error('prepare Triggers structure')
end
% if ~exist('USV','var')
%     error('prepare USV structure')
% end

NLXtimeInMilisec.Video_PhaseNames = lower(ELAN.Video_PhaseNames);
NLXtimeInMilisec.Video_PhaseNamesStr = char(NLXtimeInMilisec.Video_PhaseNames);
NLXtimeInMilisec.Video_PhaseStart = ELAN.Video_PhaseStart_NLXtime * s2ms;
NLXtimeInMilisec.Video_PhaseEnd = ELAN.Video_PhaseEnd_NLXtime * s2ms;
NLXtimeInMilisec.Video_SessionNo = ELAN.Video_SessionNo;
NLXtimeInMilisec.Video_SessionStart = ELAN.Video_SessionStart_NLXtime * s2ms;
NLXtimeInMilisec.Video_SessionEnd = ELAN.Video_SessionEnd_NLXtime * s2ms;
if exist('USV', 'var')
    NLXtimeInMilisec.USV_Type = USV.USV_Type;
    NLXtimeInMilisec.USV_Start = USV.USV_Start_NLXtime_Norm * s2ms;
    NLXtimeInMilisec.USV_End = USV.USV_End_NLXtime_Norm * s2ms;
end
NLXtimeInMilisec.NLX_Start=Triggers.NLX_TrgStart * s2ms;
NLXtimeInMilisec.NLX_End=Triggers.NLX_TrgEnd * s2ms;
NLXtimeInMilisec.NLX_Dur = Triggers.NLX_Dur * s2ms;
NLXtimeInMilisec.Video_Dur = Triggers.Video_Dur * s2ms;
NLXtimeInMilisec.Audio_Dur = Triggers.Audio_Dur * s2ms;
if exist('ELAN_Other', 'var')
    NLXtimeInMilisec.Video_Other_PhaseNames = lower(ELAN_Other.Video_PhaseNames);
    NLXtimeInMilisec.Video_Other_PhaseStart = ELAN_Other.Video_PhaseStart_NLXtime * s2ms;
    NLXtimeInMilisec.Video_Other_PhaseEnd = ELAN_Other.Video_PhaseEnd_NLXtime * s2ms;
end

if any(strcmp('Video_FrameTimeCorrected', fieldnames(Triggers)))
    NLXtimeInMilisec.Video_FrameTimeCorrected=1;
else
    NLXtimeInMilisec.Video_FrameTimeCorrected=0;
end
disp('Converted to NLX time in ms')
clear s2ms 
%% 8. Make tickle phase event file
% prepare NLXtimeInMilisec
ms2stamp = 1e3;
Timestamps = NLXtimeInMilisec.Video_PhaseStart' * ms2stamp;
Timestamps(end+1)=NLXtimeInMilisec.Video_PhaseEnd(end)*ms2stamp;
EventStrings = NLXtimeInMilisec.Video_PhaseNames';
EventStrings{end+1}='Finish';
FieldSelectionFlags = [1 0 0 0 1 0];
FileName = 'TicklePhases.nev';
Mat2NlxEV(FileName, 0, 1, [], FieldSelectionFlags, Timestamps, EventStrings(:));

clear ms2stamp FileName Timestamps EventStrings FieldSelectionFlags

%% Make USV onset event file
% Prepare NLXtimeInMilisec in the workspace
ms2stamp = 1e3;
Timestamps = NLXtimeInMilisec.USV_Start' * ms2stamp;
EventStrings = NLXtimeInMilisec.USV_Type';
FieldSelectionFlags = [1 0 0 0 1 0];
FileName = 'USV_events.nev';
Mat2NlxEV(FileName, 0, 1, [], FieldSelectionFlags, Timestamps, EventStrings(:));

clear ms2stamp FileName Timestamps EventStrings FieldSelectionFlags
%% Make Other behavior event file
% prepare NLXtimeInMilisec
ms2stamp = 1e3;
Timestamps = NLXtimeInMilisec.Video_Other_PhaseStart' * ms2stamp;
Timestamps(end+1)=NLXtimeInMilisec.Video_Other_PhaseEnd(end)*ms2stamp;
EventStrings = NLXtimeInMilisec.Video_Other_PhaseNames';
EventStrings{end+1}='Finish';
FieldSelectionFlags = [1 0 0 0 1 0];
FileName = 'OtherPhases.nev';
Mat2NlxEV(FileName, 0, 1, [], FieldSelectionFlags, Timestamps, EventStrings(:));

clear ms2stamp FileName Timestamps EventStrings FieldSelectionFlags