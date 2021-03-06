% tapGroom groom offset
tapPhase = 'tapping ipsi while trunk grooming';

exp_ids = [401008,...
           401010,...
           401012,...
           401015];
exp_ids = strjoin(arrayfun(@(x) num2str(exp_ids(x)),...
        1:length(exp_ids),'UniformOutput',false),...
        ', ');

mysql('open','mysql','shimpei','tickle'); mysql('use shimpei_rita');

exp_ids = mysql(sprintf(['', ...
    ' SELECT experiment_id FROM Experiments ', ...
    ' WHERE experiment_id IN (%s) ', ...
    ' ORDER BY experiment_id ASC ',...
    ],exp_ids));

groom_ends = cell(1,length(exp_ids));

for e=1:length(exp_ids)
    [phase,start_time,end_time] = mysql(sprintf(['',...
        ' SELECT phase, start_time, end_time FROM allBehavs ',...
        ' WHERE experiment_id = %i ', ...
        ' AND phase != ''break'' ',...
        ' ORDER BY start_time ASC ',...
        ],exp_ids(e)));
    groom_ends{1,e} = end_time(find(strcmp(phase,tapPhase))-1) - ...
        start_time(strcmp(phase,tapPhase));
    
end

mysql('close');

allGroomEnds = vertcat(groom_ends{1,:});

clear phase start_time end_time e

% groom_ends is the end_time of the previous phase of tapPhase relative to
% the start_time of tapPhase