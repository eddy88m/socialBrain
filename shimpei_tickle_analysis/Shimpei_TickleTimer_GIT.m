function Shimpei_TickleTimer_GIT(varargin)
% tickle timer displays elapsed time and when you should apply which
% tickling tasks.
% It is based on STOPWATCH written by Joseph Kirk.
% Audio guides are from http://www.fromtexttospeech.com/
%               see also https://acapela-box.com/AcaBox/index.php
%
% Requirement:
% Run Shimpei_NI.m in advance (managing trigger to the sound device, Neuralynx device, and
% a LED via NI PCI card)
%
% Current bugs:
% - pause/resume causes error.
% - error happenes when it finishes.
% - it does not start again after finished.
%
% Shimpei, March, 2014.
%
%
%STOPWATCH  Displays elapsed time from keyboard or button inputs
% STOPWATCH(TIME) Initializes the stopwatch with a time offset
%     TIME should be a real (positive or negative) scalar in units of seconds
% STOPWATCH(CLK) Starts the stopwatch running in clock mode
%     CLK should be a 6 element vector in CLOCK format
%
%   Controls:
%     Press the START button to begin the timer (or press any key except L, R, or X)
%         If the timer has already been activated, press the PAUSE button to
%           stop the timer (or press any key except L, R, or X)
%         If the timer has been paused, press the RESUME button to continue from
%           the paused time (or press any key except L, R, or X)
%         If the timer is in lap mode, press the RESUME button to continue as though
%           the lap time had not been activated (or press any key except L, R, or X)
%     Press the LAP button to view lap times (or press the L key)
%         The LAP button can be pressed successively to view mulitple laps
%     Press the RESET button to restore the timer (or press the R key)
%     Press the EXIT button to close the timer window (or press the X key)
%
%   Example:
%     % start the stopwatch
%     stopwatch;
%
%   Example:
%     % start the stopwatch with a positive offset
%     stopwatch(3598.765);
%
%   Example:
%     % count down from one hour
%     stopwatch(-3600);
%
%   Example:
%     % start the stopwatch with time already running
%     stopwatch(clock);
%
%   Example:
%     % start the stopwatch with running time since the day began
%     time = clock;
%     time(4:6) = 0;
%     stopwatch(time);
%
%   Example:
%     % count down the time until midnight
%     time = clock;
%     time(3:6) = [time(3)+1 0 0 0];
%     stopwatch(time);
%
% See also: clock, etime, binclock, circlock
%
% Author: Joseph Kirk
% Email: jdkirk630@gmail.com
% Release: 3.1
% Release Date: 4/23/08

%%
% prompt added by Shimpei
prompt = {'No. of sessions:'};
dlg_title = 'Tickle timer';
num_lines = 1;
def = {'6'};
answer = inputdlg(prompt, dlg_title, num_lines, def);
NoOfSessions = str2num(answer{1});
clear prompt dlg_title num_lines def answer;

button = questdlg('Light on?','Tickle timer','No');
switch button
    case 'Yes'
        light = 1;
        mydaq=Shimpei_NI_GIT
        warndlg('Bright lights turn on in even sessions','Bright light');
    case 'No'
        light = 0;
    case 'Cancel'
        return
end
clear button

T1 = clock;
STOPPED = 1;
LAPFLAG = 0;
TIME = 0;

% Figure Window
hfig = figure('Name','Tickle timer',...
    'Numbertitle','off',...
    'Position',[100 100 350 400],...
    'Color', [0.8 0.8 0.8],...
    'Menubar','none',...
    'Resize','off',...
    'KeyPressFcn',@keyPressFcn,...
    'CloseRequestFcn',@closeRequestFcn);

% Buttons
START = uicontrol(hfig,'Style','PushButton',...
    'Position',[10 10 75 25],...
    'String','START',...
    'Callback',@startFcn);
uicontrol(hfig,'Style','PushButton',...
    'Position',[265 10 75 25],...
    'String','EXIT (X)',...
    'Callback',@closeRequestFcn);

% Stopwatch Time Display
DISPLAY = uicontrol(hfig,'Style','text',...
    'Position',[10 40 330 55],...
    'BackgroundColor',[0.8 0.8 0.8],...
    'ForegroundColor', [0 0.8 0.6],...
    'FontSize',24);

set(hfig,'HandleVisibility','off');

% Task Display (Added by Shimpei)
SESSION =uicontrol(hfig,'Style','text',...
    'Position',[10 320 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'FontSize', 24,...
    'ForegroundColor', [0.8 0 0.8]);
TASK = uicontrol(hfig,'Style','text',...
    'Position',[10 280 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'FontSize', 40,...
    'ForegroundColor', [0.8 0 0.8]);
NextTask = uicontrol(hfig,'Style','text',...
    'Position',[10 180 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'FontSize', 24);
CountDown = uicontrol(hfig,'Style','text',...
    'Position',[10 140 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'FontSize', 40);
Elapse = uicontrol(hfig,'Style','text',...
    'Position',[10 90 330 40],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'String','Elapsed time',...
    'ForegroundColor', [0 0.8 0.6],...
    'FontSize', 18);
LightText = uicontrol(hfig,'Style','text', ...
    'Position',[10 320 65 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'String', '',...
    'ForegroundColor', 'y',...
    'FontWeight','bold',...
    'FontSize', 18);
% Title display at the beginning
set(NextTask,'String','Tickle timer');


% Process Inputs
% for var = varargin
%     input = var{1};
%     if isscalar(input)
%         TIME = input;
%     elseif length(var{1}) == 6
%         target_time = var{1};
%         TIME = etime(T1,target_time);
%         STOPPED = 0;
%         set(START,'String','PAUSE','Callback',@pauseFcn);
%         set(LAP,'Enable','on');
%     end
% end
str = formatTimeFcn(TIME);
set(DISPLAY,'String',str);

% Start the Timer
htimer = timer('TimerFcn',@timerFcn,'Period',0.1,'ExecutionMode','FixedRate');
start(htimer);


%% updated protocol
% Added by Shimpei
Phase = 1;
SessionNo = 1;
% NoOfSessions = 4; % asked by a prompt
NameSession={'Dorsal','Break','Flip','Ventral','Break','Dorsal gentle touch','Break'...
            ,'Flip','Ventral gentle touch','Break' ,'Tail','Break','Chasing hand','Break'};
PhasesInSession = numel(NameSession);
PhaseNames=['Baseline',...
    repmat(NameSession,1,NoOfSessions),...
    'Break',...
    'Finish'];
% Durations of phases
% For experiments
DurBase=30;
DurDor=10;
DurFli=1;
DurVen=9;
DurBre=15;
DurDorGen=10;
DurVenGen=9;
DurTai=10;
DurHan=10;
DurLastBre=15; % in addition
DurFin=3;

% Short run for testing
% DurBase=3;
% DurDor=2;
% DurFli=1;
% DurVen=3;
% DurBre=3;
% DurDorGen=3;
% DurVenGen=3;
% DurTai=3;
% DurHan=3;
% DurLastBre=3; % in addition
% DurFin=3;

DurSession=[DurDor,DurBre,DurFli,DurVen,DurBre,DurDorGen,DurBre,DurFli,DurVenGen,DurBre,DurTai,DurBre,DurHan,DurBre];
PhaseDurations=[DurBase,...
    repmat(DurSession,1,NoOfSessions),...
    DurLastBre,...
    DurFin];

PhaseEnd = cumsum(PhaseDurations);
PhaseStart = horzcat(0, PhaseEnd(1:end-1));

% # of phases, with baseline and last break + finish
NoOfPhases = 3+PhasesInSession*NoOfSessions;    

%% Audio guide
Folder='H:\TickleProject\MatlabFunctions\TickleTimer_AudioGuide';
baseline=audioread(fullfile(Folder,'baseline.wav'));
dorsal=audioread([Folder,'\dorsal.wav']);
flip=audioread([Folder,'\flip.wav']);
ventral=audioread([Folder,'\ventral.wav']);
Break=audioread([Folder,'\break.wav']);
gentle=audioread([Folder,'\gentle.wav']);
tail=audioread([Folder,'\tail.wav']);
finish=audioread([Folder,'\finish.wav']);
now=audioread([Folder,'\now.wav']);
dorgen=audioread([Folder,'\dorsal_gentle.wav']);
vengen=audioread([Folder,'\ventral_gentle.wav']);
hand=audioread([Folder,'\chasing_hand.wav']);
Fs=44800;

%% Functions
    function timerFcn(varargin)
        if ~STOPPED
            time_elapsed = etime(clock,T1);
            str = formatTimeFcn(TIME + time_elapsed);
            set(DISPLAY,'String',str);
            
            % Added by Shimpei
            % Phase update
            if time_elapsed > PhaseEnd(Phase)
               Phase = Phase + 1;
               % Audio guide
               switch PhaseNames{Phase}
                   case 'Dorsal'
                       sound(dorsal,Fs);
                   case 'Flip'
                       sound(flip,Fs);
                   case 'Ventral'
                       sound(ventral,Fs);
                   case 'Break'
                       sound(Break,Fs);
                   case 'Gentle touch'
                       sound(gentle,Fs);
                   case 'Tail'
                       sound(tail,Fs);
                   case 'Dorsal gentle touch'
                       sound(dorgen,Fs);
                   case 'Ventral gentle touch'
                       sound(vengen,Fs);
                   case 'Chasing hand'
                       sound(hand,Fs);
                   case 'Finish'
                       % The last phase
                       sound(finish,Fs);
                       set(SESSION,'String','');
                       set(NextTask,'String','');
                       set(CountDown,'String','');
                       set(LightText, 'String', '');
%                        pauseFcn;
                   end
            end
            % Session update
            if Phase > SessionNo*PhasesInSession+1 % +1 is for baseline
                if SessionNo~=NoOfSessions % not to update during last break and finish
                     SessionNo = SessionNo + 1;
                end
            end
            
            % Light control
            if light == 1
                if mod(SessionNo, 2) == 0
                    outputSingleScan(mydaq, 1);
                    set(LightText, 'String', 'Light');
                else
                    outputSingleScan(mydaq, 0);
                    set(LightText, 'String', '');
                end
            end
            
            % "now" audio guide
            if time_elapsed > PhaseEnd(Phase)-1
                if strcmp(PhaseNames{Phase},'Flip')==0 % Flip phase is only for 1 sec
                    %I have to write like this because there is no exact
                    %point CountDown==1.0000
                    if time_elapsed < PhaseEnd(Phase)-0.9
                        sound(now,Fs);
                    end
                end
            end

            % display update
            set(TASK,'String', PhaseNames{Phase});
            set(NextTask,'String',['Next: "' PhaseNames{Phase+1} '" in']);
            cd = formatTimeFcn(PhaseEnd(Phase)-time_elapsed);
            set(CountDown,'String',cd(7:11));
            sessionstr = ['Session ' num2str(SessionNo) '/' num2str(NoOfSessions)];
            set(SESSION,'String',sessionstr);
        end
    end

    function keyPressFcn(varargin)
        % Parse Keyboard Inputs
        switch upper(get(hfig,'CurrentCharacter'))
            case 'L'
                if isequal(get(LAP,'Enable'),'on')
                    lapFcn;
                end
            case 'R', resetFcn;
            case 'X', closeRequestFcn;
            otherwise
                if STOPPED
                    startFcn;
                else
                    pauseFcn;
                end
        end
    end

    function startFcn(varargin)
        % Start the Stopwatch
        if LAPFLAG
            T2 = clock;
            time_elapsed = etime(T2,T1);
            T1 = T2;
            TIME = TIME + time_elapsed;
        else
            T1 = clock;
        end
        STOPPED = 0;
        if TIME==0
            sound(baseline,Fs);
        end
        set(START,'String','PAUSE','Callback',@pauseFcn);
%         set(LAP,'Enable','on');
     end

    function pauseFcn(varargin)
        % Pause the Stopwatch
        STOPPED = 1;
        LAPFLAG = 0;
        time_elapsed = etime(clock,T1);
        TIME = TIME + time_elapsed;
        str = formatTimeFcn(TIME);
        set(DISPLAY,'String',str);
        set(START,'String','RESUME','Callback',@startFcn);
        set(LAP,'Enable','off');
        % Added by Shimpei
         cd = formatTimeFcn(PhaseEnd(Phase)-time_elapsed);
         set(CountDown,'String',cd(7:11));
    end

    function closeRequestFcn(varargin)
        % Stop the Timer
        try
            stop(htimer)
            delete(htimer)
        catch errmsg
            rethrow(errmsg);
        end
        % Close the Figure Window
        if light == 1;
            outputSingleScan(mydaq, [0]);
        end
        closereq;
    end
    
end

function str = formatTimeFcn(float_time)
        % Format the Time String
        float_time = abs(float_time);
        hrs = floor(float_time/3600);
        mins = floor(float_time/60 - 60*hrs);
        secs = float_time - 60*(mins + 60*hrs);
        h = sprintf('%1.0f:',hrs);
        m = sprintf('%1.0f:',mins);
        s = sprintf('%1.3f',secs);
        if hrs < 10
            h = sprintf('0%1.0f:',hrs);
        end
        if mins < 10
            m = sprintf('0%1.0f:',mins);
        end
        if secs < 9.9995
            s = sprintf('0%1.3f',secs);
        end
        str = [h m s];
    end
