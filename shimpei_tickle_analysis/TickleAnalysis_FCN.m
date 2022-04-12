% Since TickleAnalysis_template.m has become messy, a series of functions
% was made.
function [ELAN, Triggers, USV, ELAN_Other, NLXtimeInMilisec] = TickleAnalysis_FCN()
    [exp_type, checkbox_data] = userInput();
%     exp_type is either Standard tickling,
%                        Stimulation
%                        USV playback
%     checkbox_data for ELAN, 
%                       WAV exists, 
%                       Real frame time, 
%                       Other behavior, 
%                       Reset sessions, 
%                       USV analyzed,
%                       PB randomised,
%                       Fill with break
    addpath(genpath(pwd));
    [Triggers] = NLX_triggers();
    if checkbox_data(1) % ELAN analyzed
        [ELAN,Triggers] = loadELAN(Triggers,checkbox_data(9));
    else
        disp('What else can I do? I stop here');
        return
    end
    
    if checkbox_data(3) % Real frame time exists
        [ELAN, Triggers] = RealFrameTime(ELAN, Triggers);
        if checkbox_data(5) % Reset sessions to Baseline and Session 1
            ELAN = resetSession(ELAN);
        end
    elseif ~checkbox_data(9) % Highspeed
        disp('You will have a problem without RealFrameTime. Solve it manually. I stop here.');
        return
    end
    
    
    if checkbox_data(9) % Highspeed
        Triggers.Highspeed=1;    
    end
   
    if strcmp(exp_type, 'USV playback')
        ELAN = findPB(ELAN, Triggers);
        if checkbox_data(7) % Randomised PB
            ELAN = pbRandomised(ELAN);
        else
            ELAN = pbPhaseLabelling(ELAN); % automatically change PB phase name according to "Session change" phase
        end
        ELAN = fillWithBreak(ELAN); % fill empty time with Break phases
        getPbTimeFromNLX(ELAN, Triggers); % to comment PB phases in ELAN
        if checkbox_data(5) % Reset sessions to Baseline and Session 1
            ELAN = resetSession(ELAN);
        else
            disp('Are you sure not to reset sessions? Sessions are separated at Dorsal phases by default.');
        end
    end
    
    if strcmp(exp_type, 'Stimulation')
        ELAN = findSTIM(ELAN, Triggers);
    end
    
    if strcmp(exp_type, 'Nose-poke-tickle')
        ELAN = findPoke(ELAN, Triggers);
        ELAN = insertWait(ELAN);
        ELAN = fillWithBreak(ELAN);
        if checkbox_data(5) % Reset sessions to Baseline and Session 1
            ELAN = resetSession(ELAN);
        else
            disp('Are you sure not to reset sessions? Sessions are separated at Dorsal phases by default.');
        end
    end
    
    if strcmp(exp_type, 'Empathy')
        ELAN = empathyPB(ELAN, Triggers, checkbox_data(9));
        
        if checkbox_data(5) % Reset sessions to Baseline and Session 1
            ELAN = sessionChange(ELAN);
        end
    end
    
    if checkbox_data(8) % Fill with break
            ELAN = fillWithBreak(ELAN);
    end
    
    if checkbox_data(4) % Other behavior analyzed
        [ELAN_Other] = OtherBehaviors(ELAN, Triggers,checkbox_data(9));
%         [ELAN_Other] = SessionOther(ELAN, ELAN_Other, experiment_id);
    else
        ELAN_Other = [];
    end
    
    if checkbox_data(2) % WAV exists
        [ELAN, Triggers] = findAudioTriggers(ELAN, Triggers);
    end
    
    if checkbox_data(6) % USV analyzed
        [USV] = loadUSV(Triggers);
    else
        USV = [];
    end
    
    
    
    [NLXtimeInMilisec] = Milisec(ELAN, Triggers, USV, ELAN_Other);
end

function [exp_type, checkbox_data] = userInput()
    d = dialog('Position', [500 200 200 300], 'Name', 'Tickle Analysis');
    txt_type = uicontrol('Parent', d, ...
                    'Style', 'text', ...
                    'Position', [25 250 150 40], ...
                    'HorizontalAlignment', 'Left', ...
                    'String', 'Select experiment type:');
    popup = uicontrol('Parent', d, ...
                    'Style', 'popup', ...
                    'Position', [25 240 150 25], ...
                    'HorizontalAlignment', 'Left', ...
                    'String', {'Standard tickling'; 'Stimulation'; 'USV playback'; 'Nose-poke-tickle'; 'Empathy'}, ...
                    'Callback', @popup_callback);
    txt_box = uicontrol('Parent', d, ...
                    'Style', 'text', ...
                    'Position', [25 180 150 40], ...
                    'HorizontalAlignment', 'Left', ...
                    'String', 'Select:');
    checkbox = uitable('Parent', d, ...
                    'ColumnFormat', {'logical', 'char'}, ...
                    'ColumnWidth', {15, 135}, ...
                    'ColumnEditable', [true, false], ...
                    'Position', [25 50 155 150], ...
                    'Units', 'norm', ...
                    'ColumnName', [], ...
                    'RowName', [], ...
                    'Data', {false 'ELAN analized'; ...
                             false 'WAV file exists'; ...
                             false 'Real frame time exists'; ...
                             false 'Other Behavior analized'; ...
                             false 'Reset sessions'; ...
                             false 'USV analyzed'; ...
                             false 'PB randomised'; ...
                             false 'Fill with break'; ...
                             false 'Highspeed video'}, ...
                    'TooltipString', sprintf('"Reset sessions" makes only 2 sessions (i.e. Baseline & Session 1)\nDisabling this creates session division at every "Dorsal" phase'), ...
                    'CellEditCallback', @checkbox_callback);
                    
    OKbtn = uicontrol('Parent', d, ...
                    'Position', [115 20 70 25], ...
                    'String', 'OK', ...
                    'Callback', 'delete(gcf)');
    exp_type = 'Standard tickling';
    uiwait(d);
    function popup_callback(popup, event)
        idx = popup.Value;
        popup_items = popup.String;
        exp_type = char(popup_items(idx, :));
    end
    function checkbox_callback(obj, callbackdata)
       tableData = get(obj, 'Data');
       checkbox_data = cell2mat(tableData(:, 1));
    end

end

function [ELAN] = sessionChange(ELAN)
    % Make sessions based on 'session change' phase
    disp('sessionChange')
    if ~exist('ELAN')
        error('ELAN does not exist')
    end
    if ~strcmp(ELAN.Video_PhaseNames, 'Baseline')
        error('The first phase name is not Baseline')
    end

    ELAN.Video_SessionNo = [];
    ELAN.Video_SessionStart_NLXtime = [];
    ELAN.Video_SessionEnd_NLXtime = [];
    keyPhase = 'Session change';
    Baseline = 'Baseline';
    SessionNo = 0;  % start with 0, so that the first baseline is session0, the first tickling session is session1.
    for i=1:length(ELAN.Video_PhaseNames)
        if strcmp(lower(ELAN.Video_PhaseNames(i)),lower(Baseline))|| strcmp(lower(ELAN.Video_PhaseNames(i)),lower(keyPhase)) || i==2
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
end

function [experiment_id] = getExpID(NLX_folder_name)
    underscore = strfind(NLX_folder_name, '_');
    rat_nr = NLX_folder_name(4:underscore(1)-1);
    exp_nr = str2double(NLX_folder_name(underscore(1)+2:underscore(2)-1));
    alphabet = 'abcdefghijklmnopqrstuvwxyz';
    rat_id = str2double(rat_nr(1:end-1))*10 + find(alphabet==rat_nr(end));
    experiment_id = rat_id*1000 + exp_nr;
end

function [Triggers] = NLX_triggers()
    disp('Finding NLX triggers ...')
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
    Interval = diff(TriggerTimeStamps);

    TTLup = [TriggerTimeStamps(1),TriggerTimeStamps(find(Interval>IgnoreTime)+1)];
    if length(TTLup) ~= 2
        warning('not exactly 2 triggers')
    end

    Triggers.NLX_TrgStart = TTLup(1);
    Triggers.NLX_TrgEnd = TTLup(2);
    Triggers.NLX_Dur = Triggers.NLX_TrgEnd - Triggers.NLX_TrgStart;

    if length(TTLup)== 2
        clear TTLup
    end

    clear microseconds TTLEvents TimeStamp TTLs Strings Channel1 Channel1Up TriggerTimeStamps NoOfEventsNeeded
    clear IgnoreTime i Interval k 
end

function [ELAN, Triggers] = loadELAN(Triggers,Highspeed)
    ELAN_file = dir('*ELAN_labeled.txt');
    if numel(ELAN_file)~=1
        disp('Not exactly one ELAN file.')
    end

    ELAN_labels=readtable(ELAN_file.name,'Delimiter','tab', 'ReadVariableNames', false);
    ELAN_labels = sortrows(ELAN_labels,'Var1','ascend');
    if Highspeed
        divBy = 4;
        ELAN_labels.Var1 = ELAN_labels.Var1/divBy;
        ELAN_labels.Var2 = ELAN_labels.Var2/divBy;
    end
    
    
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
end

function [ELAN, Triggers] = RealFrameTime(ELAN, Triggers)
    FrameFile = dir('*frames.csv');
    if numel(FrameFile) ~= 1
        FrameFile = dir('*cam1_frames.csv');
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
end

function [ELAN] = findPB(ELAN, Triggers, Highspeed)
    disp('NLX finding USV playback');
    ms2s = 1e-6;
    [TimeStamp, ~, TTLs,~,Strings ] = MoritzNlx2MatEV('Events.nev');
    isTTLEvents = strncmp(cellstr(Strings), 'TTL Input on AcqSystem1_0 board 0 port 3', 40); % read only port 3
    if sum(isTTLEvents) == 0
        warning('cannot find a TTL event');
    end

    Channel = bitget(TTLs,1);
    TriggerTimeStamps = double(TimeStamp(isTTLEvents' & Channel)) * ms2s;

    % clear oscillation
    IgnoreTime = 0.5; % TTL shorter than this [s] is ignored
    Interval = diff(TriggerTimeStamps);
    pbStart = [TriggerTimeStamps(1),TriggerTimeStamps(find(Interval>IgnoreTime)+1)];
    pbEnd = [TriggerTimeStamps(Interval>IgnoreTime),TriggerTimeStamps(end)];
    

    % integrate playback phases in ELAN
    if ~exist('ELAN', 'var')
        error('execute Load ELAN file first');
    end
    if ~Triggers.Video_FrameTimeCorrected && ~Highspeed
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
end

function [ELAN] = empathyPB(ELAN,Triggers,Highspeed)
    % get audio PB TTL from NLX
    disp('getting Audio PB from NLX')
    ms2s = 1e-6;

    [TimeStamp, ~, TTLs,~,Strings ] = MoritzNlx2MatEV('Events.nev');
    isTTLEvents = strncmp(cellstr(Strings), 'TTL Input on AcqSystem1_0 board 0 port 3', 40); % read only port 3
    if sum(isTTLEvents) == 0
            warning('cannot find audio PB');
    end

    Channel = bitget(TTLs,1);
    TriggerTimeStamps = double(TimeStamp(isTTLEvents' & Channel)) * ms2s;
    % clear oscillation
    IgnoreTime = 0.5; % TTL shorter than this [s] is ignored
    Interval = diff(TriggerTimeStamps);
    pbApproved = 0;
    
    while ~pbApproved
        pbStart = [TriggerTimeStamps(1),TriggerTimeStamps(find(Interval>IgnoreTime)+1)];
        pbEnd = [TriggerTimeStamps(Interval>IgnoreTime),TriggerTimeStamps(end)];
        answer = questdlg(sprintf('Found %i playbacks. Continue?',length(pbStart)));
        switch answer
            case 'Cancel'
                return
            case 'Yes'
                pbApproved = 1;
            case 'No'
                IgnoreTime = str2num(cell2mat(inputdlg('New ignoring threshold [s]','Ignore time',[1 35],{num2str(IgnoreTime)})));
        end
    end
    
    % user clarify PB type (A,V,AV)
    pbTypes = cell(length(pbStart),1);
    for p=1:length(pbTypes)
        pbTypes{p} = pbTypeInput(p);
    end
    
    % insert Audio PB labels into ELAN NLXtime
    if ~exist('ELAN', 'var')
        error('execute Load ELAN file first');
    end
    if ~Triggers.Video_FrameTimeCorrected && ~Highspeed
        error('execute Real Frame Time first');
    end
    
    insert = @(a, x, n)cat(1, x(1:n-1), a,  x(n:end)); % function handle to insert a into x at nth)
    for ThisPB = 1:length(pbStart)
        if strcmp(pbTypes{ThisPB},'A')
            % get Audio PB labels
            [pbFile,pbPath] = uigetfile('*.txt',sprintf('%s PB ELAN labels',pbTypes{ThisPB}));
            pbFilePath = [pbPath,pbFile];
            pbLabels = readtable(pbFilePath,'Delimiter','\t');
            
            insertHere = numel(ELAN.Video_PhaseStart_NLXtime(ELAN.Video_PhaseStart_NLXtime < pbStart(ThisPB))) + 1;
            % align PB labels to PB start in NLX time
            pbLabels.Var1=pbLabels.Var1+pbStart(ThisPB);
            pbLabels.Var2=pbLabels.Var2+pbStart(ThisPB);
            
            %insert
            ELAN.Video_PhaseStart_NLXtime = insert(pbLabels.Var1, ELAN.Video_PhaseStart_NLXtime, insertHere);
            ELAN.Video_PhaseEnd_NLXtime = insert(pbLabels.Var2, ELAN.Video_PhaseEnd_NLXtime, insertHere);
            ELAN.Video_PhaseNames = insert(pbLabels.Var3, ELAN.Video_PhaseNames, insertHere);
        end
    end
    
    % load V/AV PB material analysis and insert into ELAN NLXtime
    for thisPB = 1:length(pbTypes)
        if ~strcmp(pbTypes{thisPB},'A')
            [pbFile,pbPath] = uigetfile('*.txt',sprintf('%s PB ELAN labels',pbTypes{thisPB}));
            pbFilePath = [pbPath,pbFile];
            pbLabels = readtable(pbFilePath,'Delimiter','\t');
            switch pbTypes{thisPB}
                case 'V'
                    repPB = 'V playback';
                case 'AV'
                    repPB = 'AV playback';
                case 'Shimpei AV'
                    repPB = 'Shimpei AV playback';
                case 'Shimpei V'
                    repPB = 'Shimpei V playback';
                case 'Lena AV'
                    repPB = 'Lena AV playback';
                case 'Lena V'
                    repPB = 'Lena V playback';
            end
            repInsert = @(a, x, n)cat(1, x(1:n-1), a,  x(n+1:end)); % function handle to insert a into x at nth)
            insertHere = find(strcmp(ELAN.Video_PhaseNames,repPB));
            
            % align PB labels to PB start in NLX time
            pbLabels.Var1=pbLabels.Var1+ELAN.Video_PhaseStart_NLXtime(insertHere);
            pbLabels.Var2=pbLabels.Var2+ELAN.Video_PhaseStart_NLXtime(insertHere);
            
            % replace and insert
            ELAN.Video_PhaseNames = repInsert(pbLabels.Var3,ELAN.Video_PhaseNames,insertHere);
            ELAN.Video_PhaseStart_NLXtime = repInsert(pbLabels.Var1,ELAN.Video_PhaseStart_NLXtime,insertHere);
            ELAN.Video_PhaseEnd_NLXtime = repInsert(pbLabels.Var2,ELAN.Video_PhaseEnd_NLXtime,insertHere);
        end
    end     
   
end

function pbType = pbTypeInput(nPB)
    % user defines PB type
    pbTypeOptions = {'A',...
                     'V',...
                     'AV',...
                     'Shimpei AV',...
                     'Shimpei V',...
                     'Lena AV',...
                     'Lena V'};
    if ~isnumeric(nPB)
        error('number of playback is invalid')
    end
    
    d = dialog('Position',[500 200 200 200] ...
             , 'Name', 'Playback Type' ...
             );
    
    bg = uibuttongroup('Parent', d ...
                     , 'Position', [0 0 150 120] ...
                     , 'SelectionChangedFcn',@bsel ...
                     );
    r1 = uicontrol(bg ...
                 , 'Style', 'radiobutton' ...
                 , 'Position', [25 140 150 20] ...
                 , 'String', pbTypeOptions{1} ...
                 , 'HandleVisibility', 'off' ...
                 );
    r2 = uicontrol(bg ...
                 , 'Style', 'radiobutton' ...
                 , 'Position', [25 120 150 20] ...
                 , 'String', pbTypeOptions{2} ...
                 );
    r3 = uicontrol(bg ...
                 , 'Style', 'radiobutton' ...
                 , 'Position', [25 100 150 20] ...
                 , 'String', pbTypeOptions{3} ...
                 );
    r4 = uicontrol(bg ...
                 , 'Style', 'radiobutton' ...
                 , 'Position', [25 80 150 20] ...
                 , 'String', pbTypeOptions{4} ...
                 );
    r5 = uicontrol(bg ...
                 , 'Style', 'radiobutton' ...
                 , 'Position', [25 60 150 20] ...
                 , 'String', pbTypeOptions{5} ...
                 );
	r6 = uicontrol(bg ...
                 , 'Style', 'radiobutton' ...
                 , 'Position', [25 40 150 20] ...
                 , 'String', pbTypeOptions{6} ...
                 );
    r7 = uicontrol(bg ...
                 , 'Style', 'radiobutton' ...
                 , 'Position', [25 20 150 20] ...
                 , 'String', pbTypeOptions{7} ...
                 );
    txt = uicontrol('Parent', d...
                  , 'Style', 'text' ...
                  , 'Position', [25 160 150 30] ...
                  , 'HorizontalAlignment', 'Left' ...
                  , 'String', sprintf('#%i playback is...',nPB) ...
                  );
    pbType = 'A'; % default
    function bsel(src,evnt)
        pbType = evnt.NewValue.String;
    end

    uiwait(d);
    

end

function [ELAN] = pbPhaseLabelling(ELAN)
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
end

function [ELAN] = pbRandomised(ELAN)
% label randomised PB phases based on their length
% note that it distinguishes Comb, WN, and FearSeries only.
% I think I do not need art50 and art22 in future.
% comb_comb_comb.wav 1.12 sec
% fearSeries.wav 2.9776 sec
% white nosie 1 sec
    disp('Randomised PB phase labeling');
    if ~exist('ELAN')
        error('ELAN structure not found')
    end
    comb_dur = 1.1210; % [s]
    WN_dur = 0.9999;
    fear_dur = 2.9775;
    errorRange = 0.05;
    
    for thisPhase = 1:length(ELAN.Video_PhaseNames)
       if strcmp(ELAN.Video_PhaseNames(thisPhase), 'playback') | regexp(ELAN.Video_PhaseNames{thisPhase}, regexptranslate('wildcard', 'PB*'))
           thisDur = ELAN.Video_PhaseEnd_NLXtime(thisPhase) - ELAN.Video_PhaseStart_NLXtime(thisPhase);
           if thisDur > comb_dur - errorRange && thisDur < comb_dur + errorRange
               ELAN.Video_PhaseNames(thisPhase) = {'PB Comb'};
           elseif thisDur > WN_dur - errorRange && thisDur < WN_dur + errorRange
               ELAN.Video_PhaseNames(thisPhase) = {'PB White noise'};
           elseif thisDur > fear_dur - errorRange && thisDur < fear_dur + errorRange
               ELAN.Video_PhaseNames(thisPhase) = {'PB Fear'};
           end
       end
    end

end

function [ELAN] = fillWithBreak(ELAN)
    % for PB experiments, add break phases on non-labelled periods
    % do this after PB import, Real Frame Time, before NLXtimeInMilisec
    
    disp('Fill with break')
    if ~exist('ELAN')
        error('ELAN structure not found')
    elseif sum(ismember(ELAN.Video_PhaseNames, 'Baseline')) ~= 1
        error('No Baseline phase found')
    end

    [break_start,break_end] = intervalBreak(ELAN.Video_PhaseStart_NLXtime,ELAN.Video_PhaseEnd_NLXtime);
    

    insert = @(a, x, n)cat(2, x(1:n-1), a,  x(n:end)); % function handle to insert a into x at nth) 
    phase_name = {'Break'};
    for this_break = 1:length(break_start)
        insert_here = numel(ELAN.Video_PhaseStart_NLXtime(ELAN.Video_PhaseStart_NLXtime < break_start(this_break))) + 1;
        ELAN.Video_PhaseStart_NLXtime = insert(break_start(this_break), ELAN.Video_PhaseStart_NLXtime', insert_here)';
        ELAN.Video_PhaseEnd_NLXtime = insert(break_end(this_break), ELAN.Video_PhaseEnd_NLXtime', insert_here)';
        ELAN.Video_PhaseNames = insert(phase_name, ELAN.Video_PhaseNames', insert_here)';
    end
    clear phase phase_name insert interval ans idx this_break break_start break_end insert_here
end

function getPbTimeFromNLX(ELAN, Triggers)
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
end

function [ELAN] = resetSession(ELAN)
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
end

function [ELAN] = findSTIM(ELAN, Triggers)
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
end

function [ELAN] = findPoke(ELAN, Triggers)
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
end

function [ELAN] = insertWait(ELAN)
    % for nose-poke-tickle experiments, add break phases on non-labeled
    % periods. Particularly for the period between nose-poke and the
    % subsequent tickle event, fill with Wait phase.
    disp('Insert Wait phase before Nose-poke')
    if ~exist('ELAN')
        error('ELAN structure not found')
    elseif sum(ismember(ELAN.Video_PhaseNames, 'Baseline')) ~= 1
        error('No Baseline phase found')
    end
    
    wait_start = [];
    wait_end = [];
    idx = 1;

    for phase = 1:length(ELAN.Video_PhaseStart_NLXtime)-1
        if strcmp(ELAN.Video_PhaseNames(phase), 'nose-poke')
            wait_start(idx,1) = ELAN.Video_PhaseEnd_NLXtime(phase); % start at the end of nose-poke
            wait_end(idx,1) = ELAN.Video_PhaseStart_NLXtime(phase+1); % end at the beginning of next phase
            idx = idx + 1;
        end
    end
    insert = @(a, x, n)cat(2, x(1:n-1), a,  x(n:end)); % function handle to insert a into x at nth) 
    phase_name = {'Wait'};
    for this_wait = 1:length(wait_start)
        insert_here = numel(ELAN.Video_PhaseStart_NLXtime(ELAN.Video_PhaseStart_NLXtime < wait_start(this_wait))) + 1;
        ELAN.Video_PhaseStart_NLXtime = insert(wait_start(this_wait), ELAN.Video_PhaseStart_NLXtime', insert_here)';
        ELAN.Video_PhaseEnd_NLXtime = insert(wait_end(this_wait), ELAN.Video_PhaseEnd_NLXtime', insert_here)';
        ELAN.Video_PhaseNames = insert(phase_name, ELAN.Video_PhaseNames', insert_here)';
    end
            
    
    
    
end

function [ELAN_Other] = OtherBehaviors(ELAN, Triggers, Highspeed)
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
    if ~Triggers.Video_FrameTimeCorrected && ~Highspeed
        error('execute Real Frame Time first');
    end

    ELAN_labels=readtable(ELAN_file.name,'Delimiter','tab', 'ReadVariableNames', false);
    if Highspeed
        divBy = 4;
        ELAN_labels.Var1 = ELAN_labels.Var1/divBy;
        ELAN_labels.Var2 = ELAN_labels.Var2/divBy;
    end
    ELAN_Other.Video_PhaseStart = ELAN_labels{:,{'Var1'}};  % extract values from table to array
    ELAN_Other.Video_PhaseEnd = ELAN_labels{:,{'Var2'}};
    ELAN_Other.Video_PhaseNames = ELAN_labels{:,{'Var3'}};
    disp('ELAN Other Behaviors file is loaded')
    % Triggers.Video_TrgStart = ELAN_Other.Video_PhaseStart(1); % the beginning of Baseline should be the first LED lighting time i.e. beginning of the recording
    % Triggers.Video_TrgEnd = ELAN_Other.Video_PhaseEnd(end); % the end of the last Baseline should be the second LED lighting time i.e. the end of the recording
    % Triggers.Video_Dur = Triggers.Video_TrgEnd - Triggers.Video_TrgStart;
    % Triggers.Video_NlxOffset = Triggers.NLX_TrgStart - Triggers.Video_TrgStart;    % To convert time in NLX time, add Offset to the time
    % Triggers.Video_Error = Triggers.NLX_Dur - Triggers.Video_Dur;
    clear ELAN_labels ELAN_file

    % Align to NLX time
    if ~isfield(Triggers,'Video_NlxOffset')
        Triggers.Video_NlxOffset = Triggers.NLX_TrgStart - Triggers.Video_TrgStart;
    end
    ELAN_Other.Video_PhaseStart_NLXtime=ELAN_Other.Video_PhaseStart+Triggers.Video_NlxOffset;
    ELAN_Other.Video_PhaseEnd_NLXtime=ELAN_Other.Video_PhaseEnd+Triggers.Video_NlxOffset;
    % correct NLX time
    IFI = 1/30;
    if Highspeed
        IFI = 1/240;
    end
    PhaseStartFrames = round(ELAN_Other.Video_PhaseStart / IFI);
    for i=1:length(PhaseStartFrames)
        ELAN_Other.Video_PhaseStart_NLXtime(i) = ELAN_Other.Video_PhaseStart(i) + Triggers.Video_NlxOffset;
        ELAN_Other.Video_PhaseEnd_NLXtime(i) = ELAN_Other.Video_PhaseEnd(i) + Triggers.Video_NlxOffset;
    end
    clear IFI PhaseStartFrames i
    if ismember('Freezing', ELAN_Other.Video_PhaseNames)
        % Adjust the ends of Freezing that are overlapping with next
        % tickling phase
        % Gaps between the ends of Freezing and next tickling that are
        % shorter than threshold are also filled
        freezing_threshold = 0.1; %[s]
        f_index = find(strcmp(ELAN_Other.Video_PhaseNames, 'Freezing'));
        for f=1:numel(f_index)
            f_end = ELAN_Other.Video_PhaseEnd_NLXtime(f_index(f));
            % get closest phase start to this f_end
            [~, closest_i] = min(abs(ELAN.Video_PhaseStart_NLXtime - f_end));
            phase_start = ELAN.Video_PhaseStart_NLXtime(closest_i);
            if strcmp(ELAN.Video_PhaseNames(closest_i), 'Dorsal') || strcmp(ELAN.Video_PhaseNames(closest_i), 'Flip')
                if phase_start - f_end < 0 % overlapping
                    ELAN_Other.Video_PhaseEnd_NLXtime(f_index(f)) = phase_start;
                elseif phase_start - f_end < freezing_threshold
                    ELAN_Other.Video_PhaseEnd_NLXtime(f_index(f)) = phase_start;
                end
            end 
            
        end
    end

end

function [ELAN_Other] = SessionOther(ELAN, ELAN_Other, experiment_id)
    ELAN_Other.session_id = zeros(length(ELAN_Other.Video_PhaseStart), 1);
    for thisSes = 1:length(ELAN.Video_SessionNo)
        thisSes_id = experiment_id*1000 + ELAN.Video_SessionNo(thisSes);
        in_session = find(ELAN_Other.Video_PhaseStart_NLXtime ...
                >= ELAN.Video_SessionStart_NLXtime(thisSes) ...
                & ELAN_Other.Video_PhaseStart_NLXtime ...
                < ELAN.Video_SessionEnd_NLXtime(thisSes));
        ELAN_Other.session_id(in_session) = thisSes_id;    
    end
    % WARNING
    % There might be Other_Behaviors entries out of session (before
    % baseline).
    % For practice, I label such entries with baseline session_id
    ELAN_Other.session_id(find(ELAN_Other.session_id == 0)) = experiment_id*1000 + ELAN.Video_SessionNo(1);
    clear in_session thisSes thisSes_id
end

function [ELAN, Triggers] = findAudioTriggers(ELAN, Triggers)
    disp('Audio finding triggers')
    wavfile=dir('*.wav');  % Do not use filtered (*f.wav) file, which may contain many triggers for some reasons.
    % exclude *_f.wav from dir list
    for i=1:length(wavfile)
        if regexp(wavfile(i).name,regexptranslate('wildcard','*_f.WAV'))==1
            wavfile(i)=[];
        end
    end
    % also remove ch2-4 in case of multi mic
    for i=1:length(wavfile)
        if regexp(wavfile(i).name,regexptranslate('wildcard','ch4*.WAV'))==1
            wavfile(i)=[];
        end
    end
    for i=1:length(wavfile)
        if regexp(wavfile(i).name,regexptranslate('wildcard','ch3*.WAV'))==1
            wavfile(i)=[];
        end
    end
    for i=1:length(wavfile)
        if regexp(wavfile(i).name,regexptranslate('wildcard','ch2*.WAV'))==1
            wavfile(i)=[];
        end
    end
    if numel(wavfile) ~= 1
        wavfile=dir('ch1*.wav');
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

    IgnoreShorterThan = 75000; % triggers <125000 samples (500 ms) are excluded

    if length(SampleCandDur)~=length(SampleCandidates)
        error('length of SampleCandDur and SampleCandidates do not match.')
    end
    
    trgApproved = 0;
    while ~trgApproved
        TriggerUpSamples = [];
        k=1;
        for i=1:length(SampleCandDur)
            if SampleCandDur(i)>= IgnoreShorterThan
                TriggerUpSamples(k,1) = SampleCandidates(i);
                k=k+1;
            end
        end
        answer = questdlg(sprintf('Found %i triggers. Accept?',length(TriggerUpSamples)),'Audio Trigger');
        switch answer
            case 'Cancel'
                return
            case 'Yes'
                trgApproved = 1;
            case 'No'
                IgnoreShorterThan = str2num(cell2mat(inputdlg('New ignoring threshold [samples]','Ignore sample',[1 35],{num2str(IgnoreShorterThan)})));
        end
    end
    if length(TriggerUpSamples)~= 2
        warning('not exactly 2 triggers\nThe 1st and the last one are taken')
    end
    clear i TriggerSampleCount k IgnoreShorterThan Ups SampleCandDur
    disp('Audio triggers are found')

    Triggers.Audio_TrgStart = TriggerUpSamples(1) / Fs;
    Triggers.Audio_TrgEnd = TriggerUpSamples(end)/Fs;
    Triggers.Audio_Dur = Triggers.Audio_TrgEnd - Triggers.Audio_TrgStart;
    Triggers.Audio_NlxOffset = Triggers.NLX_TrgStart - Triggers.Audio_TrgStart; % To convert time in NLX time, add Offset to the time

    Triggers.Audio_Error = Triggers.NLX_Dur - Triggers.Audio_Dur;
    disp(['Audio_Dur error (vs. NLX) ' num2str(Triggers.Audio_Error) ' s'])

    Triggers.Audio_RealSampleRate = (TriggerUpSamples(end)-TriggerUpSamples(1)) / Triggers.NLX_Dur;

    clear i k wavfile USV TriggerBit SoundTrigger SampleCandidates Fs TriggerUpSamples info
end

function USV = loadUSV(Triggers)
    % requires .txt file from manual Call-o-matic analysis
    
    [usvFileName,usvFileDir] = uigetfile('*.txt','Select USV label file');
    if ~usvFileName
        error('no USV label is loaded')
    end
    USVfile = [usvFileDir,usvFileName];
    USV.autoUSVs = 0;
    if contains(usvFileName,'autolabels')
        USV.autoUSVs = 1;
        USV.comb_threshold = str2num(cell2mat(extractBetween(usvFileName,'comb_','ms')));
    end

    Table=readtable(USVfile, 'Delimiter', 'tab', 'ReadVariableNames',false);
    if strcmp(Table{1,{'Var1'}},'start') % Auto Call-o-matic results might have headers
        Table=readtable(USVfile, 'Delimiter', 'tab', 'ReadVariableNames',true);
        USV.USV_Start=Table{:,1};
        USV.USV_End=Table{:,2};
        USV.USV_Type=Table{:,3};
    else
        USV.USV_Start=Table{:,{'Var1'}};
        USV.USV_End=Table{:,{'Var2'}};
        USV.USV_Type=Table{:,{'Var3'}};
    end

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
    
    % Emitter excel file exists
    doEmitter = questdlg('Include Emitter data?', 'Tickle Analysis', 'yes', 'no', 'yes');
    if strcmp(doEmitter, 'yes')
        emitterfile = dir('*USV_Emitter*');
        if ~isempty(emitterfile)
            [~,USV.emitter] = xlsread(emitterfile.name,1,'A:A');
        end
    end
    
    clear Table USVfile UnIndex FcIndex NoIndex emitterfile doEmitter
end

function [NLXtimeInMilisec] = Milisec(ELAN, Triggers, USV, ELAN_Other)
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
%     NLXtimeInMilisec.Video_PhaseNamesStr = char(NLXtimeInMilisec.Video_PhaseNames);
    NLXtimeInMilisec.Video_PhaseStart = ELAN.Video_PhaseStart_NLXtime * s2ms;
    NLXtimeInMilisec.Video_PhaseEnd = ELAN.Video_PhaseEnd_NLXtime * s2ms;
    NLXtimeInMilisec.Video_SessionNo = ELAN.Video_SessionNo;
    NLXtimeInMilisec.Video_SessionStart = ELAN.Video_SessionStart_NLXtime * s2ms;
    NLXtimeInMilisec.Video_SessionEnd = ELAN.Video_SessionEnd_NLXtime * s2ms;
    if ~isempty(USV)
        NLXtimeInMilisec.USV_Type = USV.USV_Type;
        NLXtimeInMilisec.USV_Start = USV.USV_Start_NLXtime_Norm * s2ms;
        NLXtimeInMilisec.USV_End = USV.USV_End_NLXtime_Norm * s2ms;
        NLXtimeInMilisec.autoUSVs = USV.autoUSVs;
        if USV.autoUSVs
            NLXtimeInMilisec.USV_wavStart = USV.USV_Start * s2ms;
            NLXtimeInMilisec.USV_wavEnd = USV.USV_End * s2ms;
            NLXtimeInMilisec.comb_thr = USV.comb_threshold;
        end
    end
    NLXtimeInMilisec.NLX_Start=Triggers.NLX_TrgStart * s2ms;
    NLXtimeInMilisec.NLX_End=Triggers.NLX_TrgEnd * s2ms;
    NLXtimeInMilisec.NLX_Dur = Triggers.NLX_Dur * s2ms;
    NLXtimeInMilisec.Video_Dur = Triggers.Video_Dur * s2ms;
    NLXtimeInMilisec.Audio_Dur = Triggers.Audio_Dur * s2ms;
    if ~isempty(ELAN_Other)
        NLXtimeInMilisec.Video_Other_PhaseNames = lower(ELAN_Other.Video_PhaseNames);
        NLXtimeInMilisec.Video_Other_PhaseStart = ELAN_Other.Video_PhaseStart_NLXtime * s2ms;
        NLXtimeInMilisec.Video_Other_PhaseEnd = ELAN_Other.Video_PhaseEnd_NLXtime * s2ms;
    end

    if any(strcmp('Video_FrameTimeCorrected', fieldnames(Triggers)))
        NLXtimeInMilisec.Video_FrameTimeCorrected=Triggers.Video_FrameTimeCorrected;
    else
        NLXtimeInMilisec.Video_FrameTimeCorrected=0;
    end
    if any(strcmp('Highspeed',fieldnames(Triggers)))
        NLXtimeInMilisec.Highspeed = Triggers.Highspeed;
    end
    disp('Converted to NLX time in ms')
    clear s2ms 
end