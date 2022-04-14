function phaseFlow()
%{
analyze which event happenes before/after each event
required file: circularGraph.m
%}

%% get data
    db_user = 'shimpei';
    db_password = 'tickle';
    db = 'shimpei_rita';
    mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));
    
    % e.g. pharmacology rats
    rat_id = mysql([' SELECT rat_id FROM Rats '...
                  , ' WHERE notes = ''Pharmacology'' '...
                  ]);
              
    strList = @(array) strjoin(arrayfun(@(x) num2str(array(x)),1:length(array),'UniformOutput',false),', ');
              
    exp_id = mysql(sprintf(['' ...
                  , ' SELECT experiment_id FROM Experiments '...
                  , ' WHERE rat_id IN (%s) '...
                  , ' ORDER BY experiment_id ASC '...
                  ],strList(rat_id)...
                  ));
    [exp,phase,starts,ends] = mysql(sprintf([''...
                  , ' SELECT experiment_id, phase, start_time, end_time FROM allBehavs '...
                  , ' WHERE experiment_id IN (%s) ' ...
                  , ' AND phase != ''break'' ' ...
                  , ' ORDER BY experiment_id, start_time ASC ' ...
                  ],strList(exp_id)...
                  ));
    ms2s = 1e-3;
    starts = starts * ms2s;
    ends = ends * ms2s;
    
    mysql('close')
    
%% count
    timeIn = 5; % previous phase ends within [s]
    uPhase = unique(phase);
    uPhase(end+1) = {'break'};
    
    fromTo = zeros(length(uPhase)); % from row to col
    
    for p=1:length(phase)-1
        thisPhase = phase(p);
        thisPhaseIdx = find(strcmp(uPhase,thisPhase));
        nextPhase = phase(p+1);
        if exp(p) ~= exp(p+1)
            % last phase
            nextPhase = {'break'};
        end
        nextPhaseIdx = find(strcmp(uPhase,nextPhase));
        breakIdx = find(strcmp(uPhase,{'break'}));
        
        
        if abs(starts(p+1) - ends(p)) < timeIn
            fromTo(thisPhaseIdx,nextPhaseIdx) = fromTo(thisPhaseIdx,nextPhaseIdx) + 1;
        else
            fromTo(thisPhaseIdx,breakIdx) = fromTo(thisPhaseIdx,breakIdx) + 1;
        end
        
    end

%% visualize
    circularGraph(fromTo','Label',uPhase);

end

