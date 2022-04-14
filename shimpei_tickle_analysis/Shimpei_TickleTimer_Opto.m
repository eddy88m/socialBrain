function Shimpei_TickleTimer_Opto()
mydaq = Shimpei_NI_GIT




LIGHT = 0;
T1 = clock;
STOPPED = 1;
TIME = 0;

% Figure Window
hfig = figure('Name','Tickle timer OPTO',...
    'Numbertitle','off',...
    'Position',[100 100 350 400],...
    'Color', [0.8 0.8 0.8],...
    'Menubar','none',...
    'Resize','off',...
    'HandleVisibility', 'off', ...
    'KeyPressFcn',@keyPressFcn,...
    'CloseRequestFcn',@closeRequestFcn);
START = uicontrol(hfig,'Style','PushButton',...
    'Position',[10 10 75 25],...
    'String','START',...
    'Callback',@startFcn);
EXIT = uicontrol(hfig,'Style','PushButton',...
    'Position',[265 10 75 25],...
    'String','EXIT (X)',...
    'Callback',@closeRequestFcn);
DISPLAY = uicontrol(hfig,'Style','text',...
    'Position',[10 40 330 55],...
    'BackgroundColor',[0.8 0.8 0.8],...
    'ForegroundColor', [3/255 166/255 120/255],...
    'FontSize',24);
% Task Display
SESSION =uicontrol(hfig,'Style','text',...
    'Position',[10 320 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'FontSize', 24,...
    'ForegroundColor', [249/255 105/255 14/255]);
TASK = uicontrol(hfig,'Style','text',...
    'Position',[10 280 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'FontSize', 30,...
    'ForegroundColor', [249/255 105/255 14/255]);
NextTask = uicontrol(hfig,'Style','text',...
    'Position',[10 180 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'ForegroundColor', [34/255 49/255 63/255], ...
    'FontSize', 24);
CountDown = uicontrol(hfig,'Style','text',...
    'Position',[10 140 330 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'ForegroundColor', [34/255 49/255 63/255], ...
    'FontSize', 40);
Elapse = uicontrol(hfig,'Style','text',...
    'Position',[10 90 330 40],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'String','Elapsed time',...
    'ForegroundColor', [3/255 166/255 120/255],...
    'FontSize', 18);
LightText = uicontrol(hfig,'Style','text', ...
    'Position',[10 330 65 55],...
    'BackgroundColor', [0.8 0.8 0.8],...
    'String', '',...
    'ForegroundColor', 'y',...
    'FontWeight','bold',...
    'FontSize', 18);
set(NextTask, 'String', 'Tickle timer OPTO');
timeStr = formatTimeFcn(TIME);
set(DISPLAY, 'String', timeStr);

% Start the timer
htimer = timer('TimerFcn', @timerFcn, 'Period', 0.1, 'ExecutionMode', 'FixedRate');
start(htimer);

%% Phases
% randomly define light-ON sessions
nTestSession = 4;
nPreSession = 1; % light-OFF session
nSession = nPreSession + nTestSession;
lightSession = false(nSession, 1);
light_1 = rand >= 0.5;
for i=nPreSession+1:nSession
    if mod(i,2)==1
        lightSession(i) = light_1;
    else
        lightSession(i) = ~light_1;
    end
end


Phase = 1;
SessionNo = 1;

SessionPhase = {'Pre-Lighting'; ...
                'Dorsal'; ...
                'Break'; ...
                'Flip'; 'Ventral'; ...
                'Break'; ...
                'Chasing hand'; ...
                'Session break'
                 };
nSessionPhase = numel(SessionPhase);
PhaseList = ['Baseline'; ...
             repmat(SessionPhase, nSession, 1); ...
             'Finish'
             ];
DurBase = 60;
DurDor = 10;
DurFli = 1;
DurVen = 9;
DurBre = 15;
DurHan = 10;
DurSesBre = 60;
DurFin = 3;
DurPreL = 3;

DurSessionPhase = [DurPreL; ...
                   DurDor; ...
                   DurBre; ...
                   DurFli; DurVen; ...
                   DurBre; ...
                   DurHan; ...
                   DurSesBre; ...
                  ];
PhaseDurations = [DurBase; ...
                  repmat(DurSessionPhase, nSession, 1); ...
                  DurFin; ...
                  ];
PhaseEnd = cumsum(PhaseDurations);
PhaseStart = vertcat(0, PhaseEnd(1:end-1));
nPhases = 2+nSessionPhase*(nSession); % with baseline + finish

%% Audio guide
Folder='H:\TickleProject\MatlabFunctions\TickleTimer_AudioGuide';
baseline=audioread(fullfile(Folder,'baseline.wav'));
dorsal=audioread([Folder,'\dorsal.wav']);
flip=audioread([Folder,'\flip.wav']);
ventral=audioread([Folder,'\ventral.wav']);
Break=audioread([Folder,'\break.wav']);
finish=audioread([Folder,'\finish.wav']);
now=audioread([Folder,'\now.wav']);
hand=audioread([Folder,'\chasing_hand.wav']);
Fs=44800;

%% functions
    function timerFcn(varargin)
        if ~STOPPED
            time_elapsed = etime(clock, T1);
            timeStr = formatTimeFcn(TIME + time_elapsed);
            set(DISPLAY, 'String', timeStr(1:end-2));
            
            % Phase update
            if time_elapsed > PhaseEnd(Phase)
                Phase = Phase + 1;
                % Audio guide
                switch PhaseList{Phase}
                    case 'Dorsal'
                        sound(dorsal,Fs);
                    case 'Flip'
                        sound(flip,Fs);
                    case 'Ventral'
                        sound(ventral,Fs);
                    case 'Break'
                        sound(Break,Fs);
                    case 'Session break'
                        sound(Break,Fs);
                    case 'Chasing hand'
                        sound(hand,Fs);
                    case 'Finish'
                         % The last phase
                       sound(finish,Fs);
                       set(SESSION,'String','');
                       set(NextTask,'String','');
                       set(CountDown,'String','');
                       set(LightText, 'String', '');
                       pauseFcn;
                end
            end
            % Session update
            if Phase > SessionNo*nSessionPhase +1 % +1 for baseline
                if SessionNo ~= nSession % not to update during finish
                    SessionNo = SessionNo +1;
                end
            end

            % Light control
            if lightSession(SessionNo) ...
             && ~strcmp(PhaseList{Phase}, 'Session break') ...
             && ~strcmp(PhaseList{Phase}, 'Finish')
                outputSingleScan(mydaq, 1);
%                   set(LightText, 'String', 'Light'); % for debug
                LIGHT = 1;
            else
                outputSingleScan(mydaq, 0);
%                   set(LightText, 'String', '');
                LIGHT = 0;
            end

            % "now" audio guide
            if time_elapsed > PhaseEnd(Phase)-1
                if ~strcmp(PhaseList{Phase}, 'Flip') && ~strcmp(PhaseList{Phase+1}, 'Pre-Lighting')
                    if time_elapsed < PhaseEnd(Phase) - 0.9
                        sound(now,Fs);
                    end
                end
            end

            % Display update
            set(TASK, 'String', PhaseList{Phase});
            set(NextTask, 'String', ['Next: "' PhaseList{Phase+1} '" in']);
            cd = formatTimeFcn(PhaseEnd(Phase)-time_elapsed);
            set(CountDown, 'String', cd(7:10));
            sessionstr = ['Session ' num2str(SessionNo) '/' num2str(nSession)];
            set(SESSION, 'String', sessionstr);
        end
    end
        



    function keyPressFcn(varargin)
        switch upper(get(hfig,'CurrentCharacter'))
            case 'X', closeRequestFcn;
            case 'R', return; % resetFcn;
            otherwise
                if STOPPED
                    startFcn;
                else
                    pauseFcn;
                end
        end
    end
    
    function startFcn(varargin)
       T1 = clock;
       STOPPED = 0;
       if TIME==0
           sound(baseline,Fs);
       end
       set(START,'String','PAUSE','Callback',@pauseFcn);
    end

    function pauseFcn(varargin)
        STOPPED = 1;
        time_elapsed = etime(clock, T1);
        TIME = TIME + time_elapsed;
        timeStr = formatTimeFcn(TIME);
        set(DISPLAY, 'String', timeStr(1:end-2));
        set(START, 'String', 'RESUME', 'Callback', @startFcn);
        % count down
        cd = formatTimeFcn(PhaseEnd(Phase)-time_elapsed);
        set(CountDown, 'String', cd(7:10));
        
    end

    function closeRequestFcn(varargin)
        % Stop the timer
        
        if LIGHT
            outputSingleScan(mydaq,[0]);
        end
        closereq;
        clear mydaq
    end

    function timeStr = formatTimeFcn(float_time)
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
        timeStr = [h m s];
    end
end