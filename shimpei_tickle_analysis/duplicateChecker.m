function [duplicates] = duplicateChecker()
% MySQL Database Duplicate Check

% User input
db.user = 'shimpei';
db.password = 'tickle';
db.db = 'shimpei_rita';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));

% Rats
rat_id = mysql(sprintf(['' ...
    , ' SELECT rat_id FROM Rats ' ...
    , ' GROUP BY rat_id ' ...
    , ' HAVING count(rat_id) > 1 ' ...
    ]));
if ~isempty(rat_id)
    duplicates.rat_id = rat_id;
end

% Experiments
experiment_id = mysql(sprintf(['' ...
    , ' SELECT experiment_id FROM Experiments ' ...
    , ' GROUP BY experiment_id ' ...
    , ' HAVING count(experiment_id) > 1 ' ...
    ]));
if ~isempty(experiment_id)
    duplicates.experiment_id = experiment_id;
end

% Sessions
session_id = mysql(sprintf(['' ...
    , ' SELECT session_id FROM Sessions ' ...
    , ' GROUP BY session_id ' ...
    , ' HAVING count(session_id) > 1 ' ...
    ]));
if ~isempty(session_id)
    duplicates.session_id = session_id;
end

% Phases
phase_start_time = mysql(sprintf(['' ...
    , ' SELECT start_time FROM Phases ' ...
    , ' GROUP BY start_time ' ...
    , ' HAVING count(start_time) > 1 ' ...
    ]));
if ~isempty(phase_start_time)
    duplicates.phase_start_time = phase_start_time;
end

% USVs
usv_nlx_time = mysql(sprintf(['' ...
    , ' SELECT nlx_time FROM USVs ' ...
    , ' GROUP BY nlx_time ' ...
    , ' HAVING count(nlx_time) > 1 ' ...
    ]));
if ~isempty(usv_nlx_time)
    [duplicates.usv_id, duplicates.usv_exp_id] = mysql(sprintf(['' ...
        , ' SELECT usv_id, experiment_id FROM USVs ' ...
        , ' WHERE nlx_time IN (%s) ' ...
        ] ...
        , strjoin(arrayfun(@(id) sprintf('%0.5f', id), usv_nlx_time, 'Un', 0)', ',') ...
        ));
end

% ETCs
etc_id = mysql(sprintf(['' ...
    , ' SELECT etc_id FROM ETCs ' ...
    , ' GROUP BY etc_id ' ...
    , ' HAVING count(etc_id) > 1 ' ...
    ]));
if ~isempty(etc_id)
    duplicates.etc_id = etc_id;
end

% ETC_Responses
ETC_Responses_etc_id = mysql(sprintf(['' ...
    , ' SELECT etc_id FROM ETC_Responses ' ...
    , ' GROUP BY etc_id ' ...
    , ' HAVING count(etc_id) > 1 ' ...
    ]));
if ~isempty(ETC_Responses_etc_id)
    duplicates.ETC_Responses_etc_id = ETC_Responses_etc_id;
end

% Synchronizations
Synchronizations_exp_id = mysql(sprintf(['' ...
    , ' SELECT experiment_id FROM Synchronizations ' ...
    , ' GROUP BY experiment_id ' ...
    , ' HAVING count(experiment_id) > 1 ' ...
    ]));
if ~isempty(Synchronizations_exp_id)
    duplicates.sync_id = mysql(sprintf(['' ...
        , ' SELECT sync_id FROM Synchronizations ' ...
        , ' WHERE experiment_id IN (%s) ' ...
        ], strjoin(arrayfun(@(id) sprintf('%i', id), Synchronizations_exp_id, 'Un', 0)', ',') ...
        ));
end

% Other_Behaviors
Behavior_session_id = mysql(sprintf(['' ...
    , ' SELECT session_id FROM Other_Behaviors ' ...
    , ' GROUP BY session_id ' ...
    , ' HAVING count(session_id) > 1 ' ...
    ]));
if ~isempty(Behavior_session_id)
    duplicates.Behavior_session_id = Behavior_session_id;
end


mysql('close');

if ~exist('duplicates','var')
    disp('No duplicates found');
end




end