function [RI_tap,RI_tapGroom] = tapGroomQuant()
%{
possible ways of quantification of tapGroom effect
1: "before" vs "in-tapping"
2: "before" vs "first xx ms of tapping"

Using overlap will lose nearly half of the events
%}

clear
mysql('close')
before_range = [-3000, -1000];

includeMU = true;


% DB info
db.user = 'shimpei';
db.password = 'tickle';
db.db = 'shimpei_rita';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));
clear db

% get tapGroom experiments
exp_ids = mysql(sprintf(['' ...
                , ' SELECT experiment_id FROM Experiments ' ...
                , ' WHERE notes = ''tapGroom'' ' ...
                , ' ORDER BY experiment_id ASC' ...
                ]));

nCells = mysql(sprintf(['' ...
                , ' SELECT count(etc_id) FROM ETCs ' ...
                , ' WHERE experiment_id IN (%s) ' ...
                , ' GROUP BY experiment_id ' ...
                , ' ORDER BY experiment_id ASC ' ...
                ],strjoin(arrayfun(@num2str,exp_ids,'UniformOutput',false),',') ...
                ));
RI_tapGroom = nan(sum(nCells),1);
RI_tap = nan(sum(nCells),1);
etc_ids = nan(sum(nCells),1);
units = {};
insert2nan = @(destin,this) ...
                vertcat(destin(1:find(isnan(destin),1)-1) ...
                       ,this...
                       ,nan(sum(isnan(destin))-length(this),1)...
                );
            
tapGroomPhase = 'tapping ipsi while trunk grooming';
tapPhase = 'tapping';

            
for e = 1:length(exp_ids)
    RI_tapGroom = insert2nan(RI_tapGroom,...
        getRI(exp_ids(e),tapGroomPhase,nCells(e),before_range));
    RI_tap = insert2nan(RI_tap,...
        getRI(exp_ids(e),tapPhase,nCells(e),before_range));
    etc_ids = insert2nan(etc_ids,...
        mysql(sprintf([''...
        ,' SELECT etc_id FROM ETCs ' ...
        ,' WHERE experiment_id=%i '...
        ,' ORDER BY etc_id ASC '...
        ],exp_ids(e))));
    units(end+1:end+nCells(e),1)=mysql(sprintf([''...
        ,' SELECT unitInfo FROM ETCs '...
        ,' WHERE experiment_id=%i '...
        ,' ORDER BY etc_id ASC '],exp_ids(e)));
    
end

mysql('close')

% plot scatter
f = figure;
ax = axes('Parent',f);
line([-1,1],[0,0],'Color','k','HandleVisibility','off')
line([0,0],[-1,1],'Color','k','HandleVisibility','off')
line([-1,1],[-1,1],'Color','k','HandleVisibility','off')
hold on
SU = scatter(RI_tap(~strcmp(units,'MU')),RI_tapGroom(~strcmp(units,'MU'))...
    ,'DisplayName',sprintf('SU (n=%i)',sum(~strcmp(units,'MU'))));
if includeMU
    MU = scatter(RI_tap(strcmp(units,'MU')),RI_tapGroom(strcmp(units,'MU'))...
    ,'kx','DisplayName',sprintf('MU (n=%i)',sum(strcmp(units,'MU'))));
end
xlim([-1,1])
ylim([-1,1])

% average
avgCrossLen = 0.05;
meanTap = mean(RI_tap(~strcmp(units,'MU')));
meanTapGroom = mean(RI_tapGroom(~strcmp(units,'MU')));

if includeMU
    meanTap = mean(RI_tap);
    meanTapGroom = mean(RI_tapGroom);
end

line([meanTap-avgCrossLen, meanTap+avgCrossLen],...
     [meanTapGroom,meanTapGroom],...
     'Color','r','HandleVisibility','off')
line([meanTap,meanTap],...
     [meanTapGroom-avgCrossLen,meanTapGroom+avgCrossLen],...
     'Color','r','HandleVisibility','off')

% axes settings
ax.TickDir = 'out';
xlabel('RI (tapping)')
ylabel('RI (peri-groom tapping)')
axis(ax,'square')
L = legend('Location','northwest');

% statistics
pVal = signrank(RI_tap(~strcmp(units,'MU')),RI_tapGroom(~strcmp(units,'MU')));
if includeMU
    pVal = signrank(RI_tap,RI_tapGroom);
end
t=text('String',sprintf('signed-rank test:\np = %.3f',pVal),...
    'Parent',ax,...
    'Position',[0.6,-0.8]);



end

function RIs=getRI(exp_id,phaseStr,nCells,before_range)
    beforeDur = diff(before_range);
    [phase_start, phase_end] = mysql(sprintf(['' ...
                , ' SELECT start_time, end_time FROM Phases ' ...
                , ' JOIN Sessions USING (session_id) ' ...
                , ' WHERE experiment_id = %i ' ...
                , ' AND phase = ''%s'' '...
                ], exp_id, phaseStr));
   
    FRbefore = zeros(nCells,length(phase_start));
    FRin = FRbefore;
    
    nSpikeQuery = [' SELECT ' ...
                 , ' CASE WHEN n IS NULL THEN 0 ELSE n END ' ...
                 , ' FROM ( ' ...
                    , ' SELECT DISTINCT etc_id FROM ETCs ' ...
                    , ' WHERE experiment_id = %i ' ...
                    , ' ORDER BY etc_id ASC ' ...
                    , ' ) AS ID ' ...
                 , ' LEFT JOIN ( ' ...
                    , ' SELECT etc_id, count(etc_id) AS n FROM Spikes ' ...
                    , ' LEFT JOIN ETCs USING (etc_id) ' ...
                    , ' WHERE experiment_id = %i ' ...
                    , ' AND spike_time BETWEEN %.2f AND %.2f' ...
                    , ' GROUP BY etc_id ' ...
                    , ' ORDER BY etc_id ASC ' ...
                    , ' ) AS nSpikes ' ...
                 , ' USING (etc_id) ' ...
                 ];
            
    % firing rate during 'before' and 'in'
    for p = 1:length(phase_start)
        phaseDur = phase_end(p) - phase_start(p);
        
        
        FRin(:,p) = mysql(sprintf(nSpikeQuery,...
            exp_id,exp_id,phase_start(p),phase_end(p) ...
                )) / phaseDur;

            
        FRbefore(:,p) = mysql(sprintf(nSpikeQuery,...
            exp_id,exp_id,phase_start(p)+before_range(1),...
                phase_start(p)+before_range(2) ...
                )) / beforeDur;
    end
    
    % calculate response index from mean firing rate
    calcRI = @(FRphase,FRbase) (FRphase-FRbase)./(FRphase+FRbase);
    
    RIs = calcRI(mean(FRin,2),mean(FRbefore,2));
    
end