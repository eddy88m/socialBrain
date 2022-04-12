function spike_raster()
wish_etc = 710030503;
wish_exp = floor(wish_etc / 10000);

% User input
db.user = 'shimpei';
db.password = 'tickle';
db.db = 'shimpei_rita';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));

[phase, start_time, end_time] = mysql(sprintf(['' ...
                                , ' SELECT phase, Phases.start_time, Phases.end_time FROM Phases ' ...
                                , ' JOIN Sessions USING (session_id) ' ...
                                , ' WHERE experiment_id = %s ' ...
                                ], wish_exp));






mysql('close');


end