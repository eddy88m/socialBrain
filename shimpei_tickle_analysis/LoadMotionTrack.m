function LoadMotionTrack()
% user input
myPhase = 'freezing';
phaseColor = hex2rgb('c4e896')/255;
pokeColor = hex2rgb('c1d9ff')/255;
showPoke = true; % highlight nose-poke if myPhase is not nose-poke


xlName = uigetfile(...
                    {'*.xls?','MS Excel files (*.xls, *.xlsx, *.xlsm, *.xlsb)'; ...
                     '*.*',  'All Files (*.*)'}, ...
                     'Select excel sheet', 'MultiSelect', 'off');
if ~xlName
    warning('User cancelled');
    return;
end

[xPxl,yPxl,frames,times,speed,frameRate] = getAEdata(xlName);
[phaseStarts, phaseEnds] = getPhases(myPhase);
phaseDur = phaseEnds - phaseStarts;
[pokeStarts, pokeEnds] = getPhases('nose-poke');
pokeDur = pokeEnds - pokeStarts;

breaks = [1; find(diff(frames)~=1); length(frames)]; % break in AE analysis

%% Plot


[T,S,X,Y] = calcPlot();
[uniT,Ms,Mx,My] = uniformMatrix(T,S,X,Y,frameRate);
set(0,'DefaultFigureWindowStyle','docked')
plotTile(showPoke)
plotHeat()
plot3d(showPoke)
plotOverlay()
% plotTrajectory()
set(0,'DefaultFigureWindowStyle','normal')



%% Plot functions (nested)
    function [T,S,X,Y] = calcPlot()
        thisPhase = 1;
        S = cell(1,length(phaseStarts));
        T = cell(1,length(phaseStarts));
        X = cell(1,length(phaseStarts));
        Y = cell(1,length(phaseStarts));
        for x=1:length(breaks)-1
            if thisPhase > length(phaseStarts)
                break
            end
            if times(breaks(x)) < phaseStarts(thisPhase) && phaseStarts(thisPhase) < times(breaks(x+1)) % myPhase in this block
                S{thisPhase} = speed(breaks(x)+1:breaks(x+1)-1);
                T{thisPhase} = times(breaks(x)+2:breaks(x+1))-phaseStarts(thisPhase);
                X{thisPhase} = xPxl(breaks(x)+1:breaks(x+1)-1);
                Y{thisPhase} = yPxl(breaks(x)+1:breaks(x+1)-1);
                thisPhase = thisPhase + 1;
            end
        end
    end

    function plotTile(showPoke)
        gridSize = ceil(sqrt(length(phaseStarts)));
        figure('Name', 'Tile');
        for p=1:length(phaseStarts)
            h = subplot(gridSize,gridSize,p);
            hSpeed = plot(T{p},S{p});
            hold on
            rectangle('Position', [0 0 phaseDur(p) h.YLim(2)],...
                      'EdgeColor','none','FaceColor',phaseColor);
            if showPoke && ~strcmp(myPhase, 'nose-poke')
                pokeIdx = find(pokeStarts<phaseStarts(p),1,'last');
                line([pokeStarts(pokeIdx)-phaseStarts(p) pokeStarts(pokeIdx)-phaseStarts(p)], ...
                     [0 h.YLim(2)], 'Color','r');
            end
            hold off
            uistack(hSpeed,'top');
            xlabel(sprintf('time from onset of %s [s]',myPhase));
            ylabel('speed [pixel/s]');
            title(sprintf('%s at %.2f [s]',myPhase,phaseStarts(p)));
        end
    end

    function plot3d(showPoke)
        figure('Name', '3D');
        h = axes;
        [~, sortDur] = sort(phaseDur);
        for p=1:length(phaseStarts)
             hSpeed = plot3(T{p}, ones(length(T{p}))*find(sortDur==p), S{p},'b');
             hold on
             hPhase = rectangle('Position', [0 find(sortDur==p)-0.5 phaseDur(p) 1],...
                                'EdgeColor','none','FaceColor',phaseColor);
             if showPoke && ~strcmp(myPhase, 'nose-poke')
                 pokeIdx = find(pokeStarts<phaseStarts(p),1,'last');
                 line([pokeStarts(pokeIdx)-phaseStarts(p) pokeStarts(pokeIdx)-phaseStarts(p)], ...
                      [find(sortDur==p)-0.5 find(sortDur==p)+0.5], ...
                      [0 0], ...
                      'LineWidth',5,'Color',pokeColor);
             end
        end
        h.XLim = [-2 6];
        xlabel(sprintf('time from onset of %s [s]',myPhase));
        zlabel('speed [pixel/s]');
        ylabel('trial');
        hold off
    end

    function plotHeat()
        figure('Name', 'Heatmap');
        [~, sortDur] = sort(phaseDur);
        hHeat = imagesc(uniT, 1:length(phaseStarts), Ms(:,sortDur)');
        caxis([0 300])
        cBar = colorbar;
        cBar.Label.String = 'Speed [pixel/s]';
        set(hHeat, 'AlphaData', ~isnan(Ms(:,sortDur))');
        set(gca, 'ydir', 'normal');
        set(gca, 'XLIM', [-2 4]);
        xlabel(sprintf('Time from onset of %s [s]', myPhase));
        % show myPhase
        arrayfun(@(x) rectangle('Position',[0 x-0.5 phaseDur(sortDur(x)) 1], ...
                                'EdgeColor', 'w', 'LineWidth', 3),...
                      1:length(sortDur));
    end

    function plotOverlay()
        figure('Name', 'Overlay');
        hold on
        for p=1:length(phaseStarts)
             plot(T{p},S{p});
        end
        hAxis = gca;
        hPha = rectangle('Position', [0 0 mean(phaseDur) hAxis.YLim(2)],...
                         'EdgeColor','none','FaceColor',phaseColor);
        uistack(hPha,'bottom');
        xlabel(sprintf('time from onset of %s [s]',myPhase));
        ylabel('speed [pixel/s]');
        title(sprintf('%s (n = %i)', myPhase, length(phaseStarts)));
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


%% Motion Track

%     
% thisPhase = 1;
% figure;
% for x=1:length(breaks)-1
%     if times(breaks(x)) < phaseStarts(thisPhase) && phaseStarts(thisPhase) < times(breaks(x+1)) %nose-poke in this block
%         subplot(4,4,thisPhase);
%         h = plot(xPxl(breaks(x)+2:breaks(x+1)), yPxl(breaks(x)+2:breaks(x+1)), 'LineWidth', 2);
%         N = length((breaks(x)+2):breaks(x+1));
%         colormap = [uint8(parula(N)*255) uint8(ones(N,1))].';
%         drawnow
%         set(h.Edge, 'ColorBinding', 'interpolated', 'ColorData', colormap);
%         
%         hold on
%         timeBlock = times(breaks(x)+2:breaks(x+1));
%         [~,pokeIdx] = min(abs(timeBlock-phaseStarts(thisPhase)));
%         pokeIdx = find(times==timeBlock(pokeIdx));
%         scatter(xPxl(pokeIdx),yPxl(pokeIdx),300,'rx');
%         xlabel('x-position [pixel]');
%         ylabel('y-position [pixel]');
%         xlim([250 800])
%         ylim([0 400])
%         hold off
%         thisPhase = thisPhase + 1;
%     end
% end
end


%% Data functions (unnested)
function [xPxl,yPxl,frames,times,speed,frameRate] = getAEdata(xlName)
    xlData = xlsread(xlName);
    frameRate = xlData(1,2);
    xlData = xlData(~sum(isnan(xlData),2),:); % actual motion track part
    frames = xlData(:,1);
    times = frames/(frameRate);
    xPxl = xlData(:,2);
    yPxl = xlData(:,3);
    dist = sqrt(diff(xPxl).^2 + diff(yPxl).^2);
    speed = dist./(1/frameRate);
end

function [phaseStarts, phaseEnds] = getPhases(phase)
    if ~exist('NLXtime.mat','file')
        error('NLXtime.mat does not exist');
    end
    load('NLXtime.mat','Triggers','ELAN','ELAN_Other');
    if sum(strcmpi(ELAN.Video_PhaseNames,phase)) ~= 0
        % Normal ELAN
        video_starts = ELAN.Video_PhaseStart_NLXtime - Triggers.Video_NlxOffset;
        video_ends = ELAN.Video_PhaseEnd_NLXtime - Triggers.Video_NlxOffset;
        phaseStarts = video_starts(strcmpi(ELAN.Video_PhaseNames,phase));
        phaseEnds = video_ends(strcmpi(ELAN.Video_PhaseNames,phase));
        
    elseif sum(strcmpi(ELAN_Other.Video_PhaseNames,phase)) ~= 0
        % Other_Behaviors
        video_starts = ELAN_Other.Video_PhaseStart_NLXtime - Triggers.Video_NlxOffset;
        video_ends = ELAN_Other.Video_PhaseEnd_NLXtime - Triggers.Video_NlxOffset;
        phaseStarts = video_starts(strcmpi(ELAN_Other.Video_PhaseNames,phase));
        phaseEnds = video_ends(strcmpi(ELAN_Other.Video_PhaseNames,phase));
        
    else
        error('%s does not exist in NLXtime.mat',phase);
    end
    
end

function [uniT,Ms,Mx,My] = uniformMatrix(T,S,X,Y,frameRate)
    % create matrices from T, S, X, Y
    % resulting Ms shares uniT time (error < 0.033 s is expected)
    % Ms is filled with NaN where empty
    minT = min(vertcat(T{:}));
    maxT = max(vertcat(T{:}));
    uniT_neg = flip([0:-1/frameRate:floor(minT)]);
    uniT_pos = [0:1/frameRate:ceil(maxT)];
    uniT=horzcat(uniT_neg, uniT_pos(2:end))';
    
    Ms = nan(length(uniT),length(T));
    Mx = Ms;
    My = Ms;
    for c=1:length(T)
        [~,nearzeroIdx] = min(abs(T{c}));
        % negative side
        till = find(uniT==0);
        from = till-nearzeroIdx+1;
        Ms(from:till,c) = S{c}(1:nearzeroIdx);
        Mx(from:till,c) = X{c}(1:nearzeroIdx);
        My(from:till,c) = Y{c}(1:nearzeroIdx);
        % positive side
        from = find(uniT==0)+1;
        till = from + length(S{c}(nearzeroIdx+1:end))-1;
        Ms(from:till,c) = S{c}(nearzeroIdx+1:end);
        Mx(from:till,c) = X{c}(nearzeroIdx+1:end);
        My(from:till,c) = Y{c}(nearzeroIdx+1:end);
    end
end
