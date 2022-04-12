function motion_track_population()
% user input
myPhase = 'freezing';
alignTo = 'start'; %start or end
phaseColor = hex2rgb('c4e896')/255;
pokeColor = hex2rgb('c1d9ff')/255;
excl_exp = []; % list of experiment_ids that are excluded
frameRate = 30;


%% Data munging
[rawTracking, Phase, Sync, unq_exp, PrevPhase] = getData(excl_exp, myPhase);
if isempty(rawTracking)
    warning('No tracking data');
    return;
end

% reshape data
[Tracking, Phase] = expWise(rawTracking, Phase, Sync, unq_exp, frameRate);
[~, PrevPhase] = expWise(rawTracking, PrevPhase, Sync, unq_exp, frameRate);
[Times, Speeds] = phaseWise(Tracking, Phase, unq_exp, alignTo);

% universal time and one big speed matrix
[uniT, Speed_mat, Phase_start_mat, Phase_end_mat, phaseDur, col_label] = universalTIme(Speeds, Times, Phase, unq_exp, frameRate);
[~,~,PrevPhase_start_mat, PrevPhase_end_mat, PrevPhaseDur, ~] = universalTIme(Speeds,Times,PrevPhase,unq_exp,frameRate);

%% Plot

set(0,'DefaultFigureWindowStyle','docked')
plotTile()
plotHeat()
plot3d()
plotOverlay()
% plotTrajectory()
set(0,'DefaultFigureWindowStyle','normal')



%% Plot functions (nested)


    function plotTile()
        gridSize = ceil(sqrt(length(col_label)));
        figure('Name', 'Tile');
        for p=1:length(col_label)
            h = subplot(gridSize,gridSize,p);
            hSpeed = plot(uniT,Speed_mat(:,p));
            hold on
            if strcmp(alignTo,'start')
                rectangle('Position', [0 0 (Phase_end_mat(p)-Phase_start_mat(p)) h.YLim(2)],...
                          'EdgeColor','none','FaceColor',phaseColor);
                % PrevPhase (nose-poke) indicator
                line([-(Phase_start_mat(p)-PrevPhase_start_mat(p)), -(Phase_start_mat(p)-PrevPhase_start_mat(p))],...
                     [0, h.YLim(2)], 'Color','red','LineStyle','-');
            elseif strcmp(alignTo, 'end')
                rectangle('Position', [-(Phase_end_mat(p)-Phase_start_mat(p)) 0 (Phase_end_mat(p)-Phase_start_mat(p)) h.YLim(2)],...
                          'EdgeColor','none','FaceColor',phaseColor);
                % PrevPhase (nose-poke) indicator
                line([-(Phase_end_mat(p)-PrevPhase_start_mat(p)), -(Phase_start_mat(p)-PrevPhase_start_mat(p))],...
                     [0, h.YLim(2)], 'Color','red','LineStyle','-');
            end
            hold off
            uistack(hSpeed,'top');
            xlabel(sprintf('time from %s of %s [s]',alignTo,myPhase));
            ylabel('speed [pixel/s]');
            title(sprintf('%i: %s at %.2f [s]',col_label(p), myPhase,Phase_start_mat(p)));
        end
    end

    function plot3d()
        figure('Name', '3D');
        h = axes;
        [~, sortDur] = sort(phaseDur);
        for p=1:length(Phase_start_mat)
             hSpeed = plot3(uniT, ones(length(uniT))*find(sortDur==p), Speed_mat(:,p),'b');
             hold on
             if strcmp(alignTo,'start')
                hPhase = rectangle('Position', [0 find(sortDur==p)-0.5 phaseDur(p) 1],...
                                    'EdgeColor','none','FaceColor',phaseColor);
             elseif strcmp(alignTo,'end')
                hPhase = rectangle('Position', [-phaseDur(p) find(sortDur==p)-0.5 phaseDur(p) 1],...
                                    'EdgeColor','none','FaceColor',phaseColor);
             end
        end
        if strcmp(alignTo,'start')
            h.XLim = [-2 6];
        elseif strcmp(alignTo,'end')
            h.XLim = [-10 1];
        end
        xlabel(sprintf('time from %s of %s [s]',alignTo,myPhase));
        zlabel('speed [pixel/s]');
        ylabel('trial');
        hold off
    end

    function plotHeat()
        figure('Name', 'Heatmap');
        [~, sortDur] = sort(phaseDur);
        hHeat = imagesc(uniT, 1:length(Phase_start_mat), Speed_mat(:,sortDur)');
        caxis([0 300])
        cBar = colorbar;
        cBar.Label.String = 'Speed [pixel/s]';
        set(hHeat, 'AlphaData', ~isnan(Speed_mat(:,sortDur))');
        set(gca, 'ydir', 'normal');
        xlabel(sprintf('Time from %s of %s [s]', alignTo,myPhase));
        % show myPhase
        if strcmp(alignTo,'start')
            arrayfun(@(x) rectangle('Position',[0 x-0.5 phaseDur(sortDur(x)) 1], ...
                                    'EdgeColor', 'w', 'LineWidth', 3),...
                          1:length(sortDur));
            % PrevPhase line
%             arrayfun(@(x) line([-(Phase_start_mat(x)-PrevPhase_start_mat(x)), -(Phase_start_mat(x)-PrevPhase_start_mat(x))],...
%                                [x-0.5 x+0.5],...
%                                'Color','red','LineStyle','-', 'LineWidth', 3), ...
%                                1:length(sortDur));
            set(gca, 'XLIM', [-2 4]);
        elseif strcmp(alignTo,'end')
            arrayfun(@(x) rectangle('Position',[-phaseDur(sortDur(x)) x-0.5 phaseDur(sortDur(x)) 1], ...
                                    'EdgeColor', 'w', 'LineWidth', 3),...
                          1:length(sortDur));
            set(gca, 'XLIM', [-10 1]);
        end
    end

    function plotOverlay()
        figure('Name', 'Overlay');
        hold on
        % individual
        plot(uniT,Speed_mat,'Color', [0.8,0.8,0.8]);
        % average
        plot(uniT,nanmean(Speed_mat,2),'k', 'LineWidth',1.5);
        hAxis = gca;
        if strcmp(alignTo,'start')
            hPha = rectangle('Position', [0 0 mean(phaseDur) hAxis.YLim(2)],...
                             'EdgeColor','none','FaceColor',phaseColor);
            % range
            line([min(phaseDur), min(phaseDur)],[0, hAxis.YLim(2)], 'Color','red','LineStyle','--');
            line([max(phaseDur), max(phaseDur)],[0, hAxis.YLim(2)], 'Color','red','LineStyle','--');
        elseif strcmp(alignTo,'end')
            hPha = rectangle('Position', [-mean(phaseDur) 0 mean(phaseDur) hAxis.YLim(2)],...
                             'EdgeColor','none','FaceColor',phaseColor);
            % range
            line([-min(phaseDur), -min(phaseDur)],[0, hAxis.YLim(2)], 'Color','red','LineStyle','--');
            line([-max(phaseDur), -max(phaseDur)],[0, hAxis.YLim(2)], 'Color','red','LineStyle','--');
        end
        uistack(hPha,'bottom');
        xlabel(sprintf('time from %s of %s [s]',alignTo,myPhase));
        ylabel('speed [pixel/s]');
        title(sprintf('%s (n = %i)', myPhase, length(Phase_start_mat)));
    end

    function plotTrajectory()
        figure('Name','Trajectory');
        gridSize = ceil(sqrt(length(phaseStarts)));
        pokeIdx = find(uniT==0);
        for p=1:length(phaseStarts)
            subplot(gridSize,gridSize,p);
            h = plot(Mx(:,p),My(:,p),'LineWidth',2);
            hold on
            scatter(Mx(pokeIdx,p),My(pokeIdx,p),300,'rx');
            xlabel('x-position [pixel]');
            ylabel('y-position [pixel]');
            xlim([250 800])
            ylim([0 400])
            hold off
        end
    end


end

%% Data functions (unnested)

function [Tracking, Phase, Sync, unq_exp, PrevPhase] = getData(excl_exp, myPhase)
    % user info
    db_user = 'shimpei';
    db_password = 'tickle';
    db = 'shimpei_rita';
    
    if isempty(excl_exp)
        excl_exp = 0;
    end
    excl = strjoin(arrayfun(@(x) num2str(excl_exp(x)), ...
                            1:length(excl_exp), 'UniformOutput', false), ...
                   ', ');

    mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));
    % motion trackings
    [Tracking.expIDs, Tracking.frames, Tracking.xPxl, Tracking.yPxl] = ...
            mysql(sprintf(...
                   [' SELECT experiment_id, video_frame, x_pixel, y_pixel ' ...
                  , ' FROM Motion_Trackings ' ...
                  , ' WHERE experiment_id NOT IN (%s) ' ...
                  , ' ORDER BY experiment_id, video_frame ASC '...
                   ], excl));
    unq_exp = unique(Tracking.expIDs,'stable');
    unq_exp_str = strjoin(arrayfun(@(x) num2str(unq_exp(x)),...
                          1:length(unq_exp), 'UniformOutput', false), ', ')';
    % synchronizations
    [Sync.expIDs, Sync.video_dur_error, Sync.NLX_Start, Sync.Video_Start] = ...
            mysql(sprintf(...
                   [' SELECT experiment_id, video_dur_error, ' ...
                  , ' NLX_Start, Video_Start ' ...
                  , ' FROM Synchronizations ' ...
                  , ' WHERE experiment_id IN (%s) ' ...
                  , ' ORDER BY experiment_id ASC '...
                   ], unq_exp_str));
                      
    % myPhase
    [behav_id, Phase.expIDs, Phase.start_time, Phase.end_time] = ...
            mysql(sprintf(...
                   [' SELECT behav_id, experiment_id, start_time*1e-3, end_time*1e-3 ' ...
                  , ' FROM allBehavs ' ...
                  , ' WHERE experiment_id IN (%s) ' ...
                  , ' AND phase = ''%s'' ' ...
                  , ' ORDER BY experiment_id, start_time ASC '...
                   ], unq_exp_str, myPhase));
    % Previous phase (nose-poke if myPhase='freezing')
    PrevPhaseOffset = -2;
    [PrevPhase.expIDs, PrevPhase.start_time, PrevPhase.end_time, PrevPhase.phase] =...
            mysql(sprintf(...
                    [' SELECT experiment_id, start_time*1e-3, end_time*1e-3, phase ' ...
                    , ' FROM allBehavs ' ...
                    , ' WHERE behav_id IN (%s) ' ...
                    , ' ORDER BY experiment_id, behav_id ASC '...
                    ], strjoin(arrayfun(@(x) num2str(behav_id(x)+PrevPhaseOffset), 1:length(behav_id), 'UniformOutput', false), ', ')'));
    mysql('close');
end

function [Tracking, Phase] = expWise(Tracking, Phase, Sync, unq_exp, frameRate)
    % columns as experiments
    Tracking.frames = arrayfun(@(exp)...
                    Tracking.frames(Tracking.expIDs==unq_exp(exp)),...
                    1:length(unq_exp), 'UniformOutput', false);
    Tracking.xPxl = arrayfun(@(exp)...
                    Tracking.xPxl(Tracking.expIDs==unq_exp(exp)),...
                    1:length(unq_exp), 'UniformOutput', false);
    Tracking.yPxl = arrayfun(@(exp)...
                    Tracking.yPxl(Tracking.expIDs==unq_exp(exp)),...
                    1:length(unq_exp), 'UniformOutput', false);
    Phase.start_time = arrayfun(@(exp)...
                    Phase.start_time(Phase.expIDs==unq_exp(exp)),...
                    1:length(unq_exp), 'UniformOutput', false);
    Phase.end_time = arrayfun(@(exp)...
                    Phase.end_time(Phase.expIDs==unq_exp(exp)),...
                    1:length(unq_exp), 'UniformOutput', false);
    % calculate speed from pixels
    Tracking.times = arrayfun(@(exp)...
                    Tracking.frames{1,exp}/frameRate,...
                    1:length(unq_exp), 'UniformOutput', false);
    Tracking.dist = arrayfun(@(exp)...
                    sqrt(diff(Tracking.xPxl{1,exp}).^2 + diff(Tracking.yPxl{1,exp}).^2),...
                    1:length(unq_exp), 'UniformOutput', false);
    Tracking.speed = arrayfun(@(exp)...
                    Tracking.dist{1,exp}./(1/frameRate),...
                    1:length(unq_exp), 'UniformOutput', false);
    % breaks indices in frames
    Tracking.breaks = arrayfun(@(exp)...
                    [1; find(diff(Tracking.frames{1,exp})~=1); length(Tracking.frames{1,exp})],...
                    1:length(unq_exp), 'UniformOutput', false);
    % phase time to video time
    Phase.start_time = arrayfun(@(exp)...
                    Phase.start_time{1,exp}-(Sync.NLX_Start(exp)-Sync.Video_Start(exp)),...
                    1:length(unq_exp), 'UniformOutput', false);
    Phase.end_time = arrayfun(@(exp)...
                    Phase.end_time{1,exp}-(Sync.NLX_Start(exp)-Sync.Video_Start(exp)),...
                    1:length(unq_exp), 'UniformOutput', false);
    Phase.dur = arrayfun(@(exp)...
                    Phase.end_time{1,exp} - Phase.start_time{1,exp},...
                    1:length(unq_exp),'UniformOutput',false);
end

function [Times, Speeds] = phaseWise(Tracking, Phase, unq_exp, alignTo)
    % I highly regret that I have no idea how to deal with this
    % without using ugly loops
    Speeds = cell(1,length(unq_exp));
    Times = cell(1,length(unq_exp));
    if strcmp(alignTo, 'start')
        PhaseAlign = Phase.start_time;
    elseif strcmp(alignTo, 'end')
        PhaseAlign = Phase.end_time;
    end
    for exp = 1:length(unq_exp)
        Speeds{1,exp} = cell(1,length(PhaseAlign{1,exp}));
        Times{1,exp} = cell(1,length(PhaseAlign{1,exp}));
        thisPhase = 1;
        for x=1:length(Tracking.breaks{1,exp})
            if thisPhase > length(PhaseAlign{1,exp})
                break
            end
            if Tracking.times{1,exp}(Tracking.breaks{1,exp}(x)) ...
                < Phase.start_time{1,exp}(thisPhase) ...
                && Phase.start_time{1,exp}(thisPhase) ...
                < Tracking.times{1,exp}(Tracking.breaks{1,exp}(x+1))
                
                Speeds{1,exp}{thisPhase} = Tracking.speed{1,exp}(Tracking.breaks{1,exp}(x)+1:Tracking.breaks{1,exp}(x+1)-1);
                Times{1,exp}{thisPhase} = Tracking.times{1,exp}(Tracking.breaks{1,exp}(x)+2:Tracking.breaks{1,exp}(x+1))-PhaseAlign{1,exp}(thisPhase);
                thisPhase = thisPhase + 1;
            end
        end
    end
end

function [uniT, Speed_mat, Phase_start_mat, Phase_end_mat, phaseDur, col_label] = universalTIme(Speeds, Times, Phase, unq_exp, frameRate)
    % prepare universal time
    allT = horzcat(Times{:})';
    allT = vertcat(allT{:});
    minT = min(allT);
    maxT = max(allT);
    uniT_neg = flip([0:-1/frameRate:floor(minT)]);
    uniT_pos = [0:1/frameRate:ceil(maxT)];
    uniT = horzcat(uniT_neg, uniT_pos(2:end))';
    
    % create exp label for each column
    n_phases = cell2mat(arrayfun(@(exp) length(Speeds{1,exp}), ...
                        1:length(unq_exp), 'UniformOutput', false));
    
    col_label = eval(strcat('horzcat(',...
                            strjoin(arrayfun(@(exp)...
                                    sprintf('repmat(unq_exp(%i),[1,n_phases(%i)])',exp,exp),...
                                    1:length(unq_exp),'UniformOutput',false),','),...
                            ')'));
    % create speed matrix
    Speed_mat = nan(length(uniT),sum(n_phases));
    thisCol = 1;
    for exp=1:length(unq_exp)
        for pha=1:length(Speeds{1,exp})
            [~,nearzeroIdx] = min(abs(Times{1,exp}{pha}));
            % negative side
            till = find(uniT==0);
            from = till-nearzeroIdx+1;
            Speed_mat(from:till,thisCol)=Speeds{1,exp}{pha}(1:nearzeroIdx);
            % positive side
            from = find(uniT==0)+1;
            till = from + length(Speeds{1,exp}{pha}(nearzeroIdx+1:end))-1;
            Speed_mat(from:till,thisCol)=Speeds{1,exp}{pha}(nearzeroIdx+1:end);
            thisCol = thisCol + 1;
        end
    end
    
    % create phase matrix
    Phase_start_mat = zeros([1,length(col_label)]);
    Phase_end_mat = zeros([1,length(col_label)]);
    from = 1;
    for exp=1:length(unq_exp)
        Phase_start_mat(from:from+length(Phase.start_time{1,exp})-1) = Phase.start_time{1,exp};
        Phase_end_mat(from:from+length(Phase.end_time{1,exp})-1) = Phase.end_time{1,exp};
        from = from + length(Phase.start_time{1,exp});
    end
    phaseDur = Phase_end_mat - Phase_start_mat;
end

