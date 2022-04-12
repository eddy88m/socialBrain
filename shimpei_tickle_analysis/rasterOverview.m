function rasterOverview()

%% user input
exp_id = inputdlg('experiment_id:','rasterOverview');
if isempty(exp_id)
    % user cancel
    return
end
exp_id = str2double(exp_id);


%% get data from database
user = 'shimpei';
pass = 'tickle';
db = 'shimpei_rita';
mysql('open','mysql',user,pass); mysql(strcat('use ',db));

[starts,ends,phases] = mysql(sprintf([' SELECT start_time, end_time, phase ' ...
                                    , ' FROM allBehavs ' ...
                                    , ' WHERE experiment_id = %i ' ...
                                    , ' AND phase != ''break'' ' ...
                                    , ' ORDER BY start_time ASC '] ...
                                    , exp_id...
                                    ));

[ses_starts, ses_ends, brightness, other_stim] = mysql(sprintf(['' ...
                                , ' SELECT start_time, end_time, brightness, other_stimuli ' ...
                                , ' FROM Sessions ' ...
                                , ' WHERE experiment_id = %i '] ...
                                , exp_id ...
                                ));
                                
[etc_id, spikeTime, layer, unit] = mysql(sprintf([' SELECT etc_id, spike_time, layer, unitInfo FROM Spikes ' ...
                                , ' LEFT JOIN ETCs USING (etc_id) ' ...
                                , ' WHERE etc_id IN ( ' ...
                                    , ' SELECT DISTINCT etc_id FROM ETCs ' ...
                                    , ' WHERE experiment_id = %i ' ...
                                , ' ) ' ...
                                , ' ORDER BY etc_id, spike_time ASC '] ...
                                , exp_id ...
                                ));
                            
[usvTime,emitter] = mysql(sprintf([' SELECT nlx_time,emitter FROM USVs ' ...
                         , ' WHERE experiment_id = %i ' ...
                         , ' ORDER BY nlx_time ASC '] ...
                         , exp_id ...
                         ));

mysql('close');

if isempty(starts)
    error('Experiment does not exist')
end

%% set baseline start at 0 s
startAt = min(starts);
ms2s = 1e-3;
starts = (starts - startAt)*ms2s;
ends = (ends - startAt)*ms2s;
ses_starts = (ses_starts - startAt)*ms2s;
ses_ends = (ses_ends - startAt)*ms2s;
spikeTime = (spikeTime - startAt)*ms2s;
usvTime = (usvTime - startAt)*ms2s;

%% append session info to phases
if sum(~cellfun(@isempty,other_stim)) ~= 0
    unqstim = unique(other_stim(~cellfun(@isempty,other_stim)));
    for stim = 1:length(unqstim)
        starts = [starts;ses_starts(strcmp(other_stim,unqstim(stim)))];
        ends = [ends;ses_ends(strcmp(other_stim,unqstim(stim)))];
        phases = [phases;other_stim(strcmp(other_stim,unqstim(stim)))];
    end
end

if length(unique(brightness)) ~= 1
    if length(unique(brightness)) > 2
        warning('More than 2 brightness parameters. Only the maximum is shown in the graph')
    end
    starts = [starts;ses_starts(brightness==max(brightness))];
    ends = [ends;ses_ends(brightness==max(brightness))];
    phases = [phases;sprintfc('brightness %i',brightness(brightness==max(brightness)))];
end


%% stair plot for each phase
height = 0.8;

figure;
axPhase = subplot(10,1,[1 2 3 4]);
hold on

unq = flip(unique(phases,'stable'));
for p = 1:length(unq)
    x = [min(starts);sort([starts(strcmp(phases,unq(p)));ends(strcmp(phases,unq(p)))]);max(ends)];
    y = vertcat(0, repmat([1;0], length(starts(strcmp(phases,unq(p)))),1), 0);
    stairs(x,y*height+p,'k','Parent',axPhase);
end

axPhase.YTick = 1:length(unq);
axPhase.YTickLabel = unq;
axPhase.YLim = [0 length(unq)+1];
axPhase.YLimMode = 'manual';
ylabel('Phase')
axPhase.XTick = [];
axPhase.TickDir = 'out';
title(sprintf('experiment_id = %i',exp_id),'Interpreter','none')

myxlim = xlim;


%% spike raster plot

inclMU = uicontrol('Style','Checkbox' ...
                  ,'Units','Normalized' ...
                  ,'Position',[0.05 0.95 0.05 0.05] ...
                  ,'String','include MU'...
                  ,'Value',1 ...
                  ,'Callback',@inclMU_CB ...
              );
          
    function inclMU_CB(src,evnt)
        if ~isempty(spikeTime)
            plotSpikes()
        end
    end

axSpike = subplot(10,1,[5 6 7 8 9]);
markerSize = 60;
hold on

if ~isempty(spikeTime)
    plotSpikes
end

    function plotSpikes()
        cla(axSpike)
        hold on
        unqetc = flip(unique(etc_id,'stable'));
        if ~inclMU.Value
            unqetc = flip(unique(etc_id(~strcmp(unit,'MU')),'stable'));
        end

        for e = 1:length(unqetc)
            x = spikeTime(etc_id==unqetc(e));
            scatter(x,e*ones(size(x)),markerSize,'.','Parent',axSpike)
        end
        axSpike.YTick = 1:length(unqetc);
        axSpike.YTickLabel = join([sprintfc('%i',unqetc)...
            arrayfun(@(x) unique(unit(etc_id==unqetc(x)),'stable'),1:length(unqetc))' ...
            repmat({'L'},size(unqetc)) ...
            arrayfun(@(x) unique(layer(etc_id==unqetc(x)),'stable'),1:length(unqetc))']) ...
            ;
        axSpike.YLimMode = 'auto';
    end

ylabel('etc_id','Interpreter','none')
xticks([])
axSpike.TickDir = 'out';
xlim(myxlim)


%% USV raster plot
axUSV = subplot(10,1,10);
hold on
if ~isempty(usvTime)
    if sum(~cellfun(@isempty,emitter))~=0
        % separate emitters
        unqemitter = flip(unique(emitter,'stable'));
        for em = 1:length(unqemitter)
            x = usvTime(strcmp(emitter,unqemitter(em)));
            scatter(x,em*ones(size(x)),markerSize,'.')
        end
        yticks(1:length(unqemitter))
        yticklabels(unqemitter)
    else
        scatter(usvTime,ones(size(usvTime)),markerSize,'.');
        yticks([])
    end
end
ylabel('USVs')
xlabel('Time [s]')
axUSV.YLimMode = 'manual';
axUSV.TickDir = 'out';
xlim(myxlim)


%% Final touch
linkaxes([axPhase,axSpike,axUSV],'x')
set(pan,'Motion','horizontal')
set(zoom,'Motion','horizontal','Enable','on')


end