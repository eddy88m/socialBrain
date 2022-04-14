function slowFast_time_corr(toAnalyze,varargin)
switch toAnalyze
    case 'USV'
        %% slowFast USV-Time correlation during approach
        db_user = 'shimpei';
        db_password = 'tickle';
        db = 'shimpei_rita';
        mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));

        exp_id = mysql([' SELECT experiment_id FROM Experiments ', ...
                        ' WHERE notes = ''slowFast'' ', ...
                        ' ORDER BY experiment_id ASC ']);

        keyPhase = 'approaching';

        [exp, start_time, end_time] = mysql(sprintf( ...
                      [' SELECT experiment_id, start_time, end_time ' ...
                     , ' FROM allBehavs ' ...
                     , ' WHERE experiment_id IN (%s) ' ...
                     , ' AND phase = ''%s'' ' ...
                     , ' ORDER BY experiment_id, start_time ASC ' ...
                     ], strjoin(arrayfun(@(x) num2str(exp_id(x)), 1:length(exp_id), 'UniformOutput', false), ', ') ...
                     , keyPhase ...
                     ));

        phaseCallTime = cell(size(start_time));

        for p = 1:length(start_time)
            phaseCallTime{p} = mysql(sprintf( ...
                      [' SELECT nlx_time - %.2f FROM USVs ' ...
                     , ' WHERE experiment_id = %i ' ...
                     , ' AND nlx_time BETWEEN %.2f AND %.2f ' ...
                     , ' ORDER BY nlx_time ASC ' ...
                     ], end_time(p),exp(p),start_time(p),end_time(p))...
                     );
        end % phase loop


        mysql('close');

        nBins = 20;
        x = 1/nBins:1/nBins:1;
        phaseDur = end_time - start_time;
        h = zeros(length(start_time),nBins);


        for p = 1:length(start_time)
            edges = linspace(-phaseDur(p),0,nBins+1);
            binWidth = mean(diff(edges));
            h(p,:) = histcounts(phaseCallTime{p},edges) / (binWidth/1000);
            if length(h(p,:))~=sum(~h(p,:))
                % normalize to peak
                h(p,:) = h(p,:)/max(h(p,:));
            end
        end

        figure;clf;
        ax = subplot(1,1,1);
        n = length(start_time);
        nExp = length(exp_id);
        nAnimals = length(unique(floor(exp_id/1000)));
        y = mean(h,1);
        err = std(h,0,1)./sqrt(n);
        
        plotCor(x,y,err,ax,toAnalyze,nExp,nAnimals,[]);
        
    case 'Spike'
        %% slowFast Spike-Time correlation during approach
        db_user = 'shimpei';
        db_password = 'tickle';
        db = 'shimpei_rita';
        mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));

        % exclude unclear
%         [etc_exp, etc_id,layer] = mysql(['',...
%                         ' SELECT experiment_id, etc_id, ', ...
%                         ' CASE WHEN histo = ''unclear'' THEN Null ELSE layer END ', ...
%                         ' FROM ETCs ', ...
%                         ' WHERE experiment_id IN ( ', ...
%                             ' SELECT experiment_id FROM Experiments ', ...
%                             ' WHERE notes = ''slowFast'' ', ...
%                         ' ) ', ...
%                         ' AND unitInfo != ''MU'' ', ...
%                         ' ORDER BY experiment_id, etc_id ASC ']);

        % include unclear
        [etc_exp, etc_id,layer] = mysql(['',...
                        ' SELECT experiment_id, etc_id, ', ...
                        '  layer ', ...
                        ' FROM ETCs ', ...
                        ' WHERE experiment_id IN ( ', ...
                            ' SELECT experiment_id FROM Experiments ', ...
                            ' WHERE notes = ''slowFast'' ', ...
                        ' ) ', ...
                        ' AND unitInfo != ''MU'' ', ...
                        ' ORDER BY experiment_id, etc_id ASC ']);
        
        uExp_id = unique(etc_exp);
        keyPhase = 'approaching';
        [phase_exp, start_time, end_time] = mysql(sprintf( ...
                      [' SELECT experiment_id, start_time, end_time ' ...
                     , ' FROM allBehavs ' ...
                     , ' WHERE experiment_id IN (%s) ' ...
                     , ' AND phase = ''%s'' ' ...
                     , ' ORDER BY experiment_id, start_time ASC ' ...
                     ], strjoin(arrayfun(@(x) num2str(uExp_id(x)), 1:length(uExp_id), 'UniformOutput', false), ', ') ...
                     , keyPhase ...
                     ));

        phaseEtcSpikeTime = cell(length(start_time),length(etc_id));         

        for p = 1:length(start_time)
            for e = 1:length(etc_id)
                phaseEtcSpikeTime{p,e} = mysql(sprintf( ...
                    [' SELECT spike_time - %.2f FROM Spikes ', ...
                    ' WHERE etc_id = %i ', ...
                    ' AND spike_time BETWEEN %.2f AND %.2f ', ...
                    ' ORDER BY spike_time ASC '], ...
                    end_time(p),etc_id(e),start_time(p),end_time(p)));
            end % etc loop    
        end % phase loop

        mysql('close');

        nBins = 20;
        x = 1/nBins:1/nBins:1;
        % due to different phase durations, 
        % 1. calculate firing rate histogram with fixed nBins within the phase duration
        % 2. normalized to the peak firing rate (0-1)
        % 3. normalize x to duration of phase (0-1)

        % get histogram for each cell (avg over phases)
        phaseDur = end_time - start_time;
        h = zeros(length(etc_id),nBins);
        
        plotSlope = false;
        if ~isempty(varargin) && strcmp(varargin{1},'slope')
            plotSlope = true;
        end
            
        
        for e = 1:length(etc_id)
            phase_for_etc = find(~cellfun(@isempty,phaseEtcSpikeTime(:,e)));
            % edges for each phase
            edges = cell2mat(arrayfun(@(p) linspace(-phaseDur(p),0,nBins+1),1:length(phase_for_etc),'UniformOutput',false)');
            binWidth = mean(diff(edges,1,2),2);
            % spike count for each phase
            hETC = cell2mat(arrayfun(@(p) histcounts(phaseEtcSpikeTime{phase_for_etc(p),e},edges(p,:)),1:length(phase_for_etc),'UniformOutput',false)');
            % in Hz
            hETC = cell2mat(arrayfun(@(p) hETC(p,:)/(binWidth(p)/1000),1:length(phase_for_etc),'UniformOutput',false)');
            % average
            hETC = mean(hETC,1);
            % normalize
            h(e,:) = hETC;
            if ~plotSlope
                h(e,:) = hETC/max(hETC);
            end
            
        end
        
        colorArea = [220 220 220]./255;    % Grey
        colorLine = [100 100 100]./255;
        figure;clf;
        
        if plotSlope
            twoBinFR = zeros(length(etc_id),2);
            for e=1:length(etc_id)
                twoBinFR(e,1) = mean(h(e,1:nBins/2));
                twoBinFR(e,2) = mean(h(e,nBins/2+1:nBins));
            end
            
            delta = twoBinFR(:,2)./twoBinFR(:,1);
            RI = (twoBinFR(:,2) - twoBinFR(:,1)) ./ (twoBinFR(:,2) + twoBinFR(:,1));
            
            % all layers
            p1 = subplot(2,2,1);
            scatter(twoBinFR(:,1),twoBinFR(:,2))
            p1.XLim = [0,max([p1.XLim p1.YLim])];
            p1.YLim = [0,max([p1.XLim p1.YLim])];
            hold on
            line(p1.XLim,p1.YLim)
            axis square
            xlabel('FR first half [Hz]')
            ylabel('FR second half [Hz]')
            title('All cells')
            text(p1.XLim(2)/2,p1.YLim(2)/3, ...
                sprintf('signed-rank\np = %.3f',signrank(twoBinFR(:,1),twoBinFR(:,2))));
            
            
            % each layer
            p2 = subplot(2,2,2);
            twoFRplot(twoBinFR,layer,{'1','2','3'},1)
            twoFRplot(twoBinFR,layer,{'4'},2)
            twoFRplot(twoBinFR,layer,{'5a'},3)
            twoFRplot(twoBinFR,layer,{'5b'},4)
            twoFRplot(twoBinFR,layer,{'6'},5)
            twoFRplot(twoBinFR,layer,{''},6)
            
            p2.XTick = 0:7;
            p2.XLim = [0,7];
            xticklabels({'','L1-3','L4','L5a','L5b','L6','Unidentified'})
            ylabel('FR [Hz]')
            title('FR change during slow approach')
            
            
            % delta
            p3 = subplot(2,1,2);
            
%             deltaPlot(delta,layer,{'1','2','3'},1)
%             deltaPlot(delta,layer,{'4'},2)
%             deltaPlot(delta,layer,{'5a'},3)
%             deltaPlot(delta,layer,{'5b'},4)
%             deltaPlot(delta,layer,{'6'},5)
%             deltaPlot(delta,layer,{''},6)
            
            % delta RI
            deltaPlot(RI,layer,{'1','2','3'},1)
            deltaPlot(RI,layer,{'4'},2)
            deltaPlot(RI,layer,{'5a'},3)
            deltaPlot(RI,layer,{'5b'},4)
            deltaPlot(RI,layer,{'6'},5)
            deltaPlot(RI,layer,{''},6)
            
            
            p3.XTick = 0:7;
            p3.XLim = [0,7];
            plot([0,7],[1,1],'k--')
            xticklabels({'','L1-3','L4','L5a','L5b','L6','Unidentified'})
            ylabel('FR(second) / FR(first)')

            % L4 vs L5a
            
            getDelta = @(layername) delta(cell2mat(cellfun(@(x) ismember(x,layername),layer,'UniformOutput',false)));
            [~,p] = ttest2(getDelta({'4'}),getDelta({'5a'}));
            
            
            getRI = @(layername) RI(cell2mat(cellfun(@(x) ismember(x,layername),layer,'UniformOutput',false)));
            [~,p] = ttest2(getRI({'4'}),getRI({'5a','5b'}));
            return
        end
        
        
        

        % all layers
        p1 = subplot(1,2,1);
        Lall = true(size(etc_id));
        layerPlot(Lall,x,p1,h,etc_id,etc_exp)
        title('all layers')
        
        % L1-3
        p2 = subplot(2,6,4);
        Lsup = strcmp(layer,'1')|strcmp(layer,'2')|strcmp(layer,'3');
        layerPlot(Lsup,x,p2,h,etc_id,etc_exp)
        title('L1-3')
        
        % L4
        p3 = subplot(2,6,5);
        L4 = strcmp(layer,'4');
        layerPlot(L4,x,p3,h,etc_id,etc_exp)
        title('L4')
        
        % L5a
        p4 = subplot(2,6,6);
        L5a = strcmp(layer,'5a');
        layerPlot(L5a,x,p4,h,etc_id,etc_exp)
        title('L5a')
        
        % L5b
        p5 = subplot(2,6,10);
        L5b = strcmp(layer,'5b');
        layerPlot(L5b,x,p5,h,etc_id,etc_exp)
        title('L5b')
        
        % L6
        p6 = subplot(2,6,11);
        L6 = strcmp(layer,'6');
        layerPlot(L6,x,p6,h,etc_id,etc_exp)
        title('L6')
        
        % unidentified
        p7 = subplot(2,6,12);
        Lu = strcmp(layer,'');
        layerPlot(Lu,x,p7,h,etc_id,etc_exp)
        title('Unidentified')
        
end

end

function plotCor(x,y,err,ax,toAnalyze,nExp,nAnimals,nETC)
    colorArea = [220 220 220]./255;    % Grey
    colorLine = [100 100 100]./255;
   
    
    fill([x,fliplr(x)], [y+err,fliplr(y-err)] ...
            ,colorArea ...
            ,'EdgeColor','none')
    
    hold on
    
    plot(x,y,'Color',colorLine)
    xlabel('Normalized approach duration')
    ylabel('Normalized firing rate')
    switch toAnalyze
        case 'USV'
            ylabel('Normalized USV rate')
    end
    [R,P] = corr(x',y');
    stats = regstats(y',x','linear','beta');
    beta = stats.beta; % beta(1) is intercept, beta(2) is slope
    N = length(x);
    x_min = min(x);
    x_max = max(x);
    n_pts = 100;
    
    X = x_min:(x_max-x_min)/n_pts:x_max;
    Y = ones(size(X))*beta(1) + beta(2)*X;
    plot(X,Y)
    ax.YLim(1) = 0;
    ax.YLim(2) = 1;
    
    switch toAnalyze
        case 'USV'
            txt = sprintf('slope = %.3f\nr = %.3f\np = %.3f\n%i recs\n%i rats',beta(2),R,P,nExp,nAnimals);
            text((x_min+x_max)*1/2, (min(y)+max(y))/3, txt)
        case 'Spike'
            txt = sprintf('slope = %.3f\nr = %.3f\np = %.3f\n%i recs\n%i rats\n%i cells',beta(2),R,P,nExp,nAnimals,nETC);
            text((x_min+x_max)*1/2, ax.YLim(1)+diff(ax.YLim)/5, txt)
    end
    
end

function layerPlot(L,x,ax,h,etc_id,etc_exp)
    fRate = mean(h(L,:),1);
    err = std(h(L,:),0,1)./sqrt(sum(L));
    nAnimals = length(unique(floor(etc_id(L)/10000000)));
    nETC = sum(L);
    nExp = length(unique(etc_exp(L)));
    plotCor(x,fRate,err,ax,'Spike',nExp,nAnimals,nETC)
end

function deltaPlot(delta,layer,layername,plotindex)
    layerMatch = cell2mat(cellfun(@(x) ismember(x,layername),layer,'UniformOutput',false));
    plotThis = delta(layerMatch);
    scatter(ones(size(plotThis)) * plotindex,plotThis,'jitter','on')
    line([plotindex-0.2,plotindex+0.2],[median(plotThis),median(plotThis)],'color','r')
    hold on
end

function twoFRplot(twoBinFR,layer,layername,plotindex)
    layerMatch = cell2mat(cellfun(@(x) ismember(x,layername),layer,'UniformOutput',false));
    FR = twoBinFR(layerMatch,:);
    plot(repmat([plotindex-0.2,plotindex+0.2],length(FR),1)',[FR(:,1),FR(:,2)]','k-')
    p = signrank(FR(:,1),FR(:,2));
    text(plotindex-0.2,max(max(twoBinFR)) * 0.8,...
        sprintf('p = %.3f',p))
    hold on
end

