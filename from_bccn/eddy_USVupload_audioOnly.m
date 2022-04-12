% load('\\homefs\falk\04_matlab_scripting\427_shimpei_usvupload\Rat04a_E03.mat');

%% user input
prompt={'Rat name:','Experiment #:'};
dlg_title='USV upload';
num_lines=1;
def={'Rat01a','5'};
answer=inputdlg(prompt,dlg_title,num_lines,def);
rat_name=answer(1);
experiment_nr=str2num(answer{2});

%insert rat_name in database
ratID = input('Rat ID?');
sessionID = ratID*1000+experiment_nr;%equals experiment ID here
mysql(sprintf('DELETE from Rats WHERE rat_id = (%s)',num2str(ratID)))
mysql(sprintf('INSERT INTO Rats(rat_id,name) VALUES (%s,''%s'')',num2str(ratID),num2str(rat_name{:})));
%load usvIDs from spectralAnalysis table
USVidsFromSyllables = mysql(sprintf('SELECT USV_ID from spectralAnalysis WHERE session_id = (%s)',num2str(sessionID)));
USVids = unique(USVidsFromSyllables);

% rat_name = 'Rat04a';
% experiment_nr = 5;

db_user = 'eduard';
db_password = 'H,urGel9';
db = 'EddyTickling';

[USVtableName,path] = uigetfile('*.txt','Select USV table');
USVtable = readtable(USVtableName);
USV.Start = table2array(USVtable(:,1));
USV.End = table2array(USVtable(:,2));
USV.Type = table2cell(USVtable(:,3));
USV.autoUSVs = 1;
USV.comb_threshold = '40';

%% upload data
%% check everything and connect
if ~exist('USV','var')
    throw(MException('MATLAB:DataNotFound','workspace variable ''USV'' not found!'))
end

if ( ~any(strcmp('Start', fieldnames(USV))) ) ...
        || ( ~any(strcmp('End', fieldnames(USV))) ) ...
        || ( ~any(strcmp('Type', fieldnames(USV))) ) 

    throw(MException('MATLAB:DataNotComplete','workspace variable ''NlxTimeInMilisec'' does not contain all required fields!'))
end

% connect 
mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));

% get session id
experiment_id = mysql(sprintf(['' ...
            , ' SELECT DISTINCT experiment_id ' ...
            , ' FROM Experiments ' ...
            , ' WHERE TRUE ' ...
            , ' AND Experiments.rat_id IN ' ...
                , ' ( SELECT DISTINCT rat_id FROM Rats WHERE name = ''%s'' ) ' ...
            , ' AND Experiments.experiment_nr = %i ' ...
            ] , rat_name{:}, experiment_nr ));

% check existing data
if mysql( sprintf('SELECT DISTINCT COUNT(usv_id) FROM USVs WHERE experiment_id = %i', experiment_id) )
    existing_experiment = questdlg( ...
                    sprintf('Found usv data for experiment %i. DELETE?', experiment_id) ...
                    ,'RITA usv upload','yes','no','yes'); 
    switch existing_experiment
        case 'yes'
            mysql( sprintf('DELETE FROM USVs WHERE experiment_id = %i', experiment_id) );
        otherwise
            return
    end % switch user choice
                        
end % check existing data
        
        
%% get call types
[ct_abbr, ct_id] = mysql( [ '' ...
                , ' SELECT abbr, call_type_id FROM Call_Types '
                ] );

calltypes = cellfun(@(ct) ct_id(strcmp(ct, ct_abbr)) ...
                , USV.Type) ;


%% make upload string and upload
% Dealing with autoUSVs
if USV.autoUSVs
    % USVs
    datastrings = arrayfun(@(usv_nr) sprintf('(%i, %i, %i, %.2f, %.2f, ''%s'' )' ...
                            , USVids(usv_nr) ...    
                            , experiment_id ...
                            , calltypes(usv_nr) ... % call type
                            , USV.Start(usv_nr) ... % audio start [ms]
                            , USV.End(usv_nr)-USV.Start(usv_nr)  ... % Duration [ms]
                            , sprintf('autoUSVs comb threshold %i ms', USV.comb_threshold) ...% notes about autoUSVs
                            ) ...
        , 1:numel(USV.Start), 'UniformOutput', false)';
    querystr = 'INSERT INTO USVs (USV_ID_spectralAnalysis,experiment_id, call_type_id, nlx_time, duration, notes ) VALUES ';
    mysql(sprintf('%s %s', querystr, strjoin(datastrings', ',')))
    
%     % autoUSVs_Comb
%     datastrings = arrayfun(@(usv_nr) sprintf('( %i, %i, %.2f, %.2f, %.2f, %i )' ...
%                             , experiment_id ...
%                             , calltypes(usv_nr) ... % call type
%                             , USV.Start(usv_nr) ... % Nlx start time [ms]
%                             , USV.comb_threshold ...% interval_threshold_ms
%                             ) ...
%         , 1:numel(USV.Start), 'UniformOutput', false)';
%     querystr = 'INSERT INTO AutoUSVs_Comb (experiment_id, call_type_id, start_wavetime_ms, duration, nlx_time, interval_threshold_ms ) VALUES ';
%     mysql(sprintf('%s %s', querystr, strjoin(datastrings', ',')))
else
    datastrings = arrayfun(@(usv_nr) sprintf('(%i, %i, %i, %.2f, %.2f )' ...
                            , USVids(usv_nr) ... 
                            , experiment_id ...
                            , calltypes(usv_nr) ... % call type
                            , USV.Start(usv_nr) ... % Nlx start [ms]
                            , USV.End(usv_nr)-USV.Start(usv_nr)  ... % Duration [ms]
                            ) ...
        , 1:numel(USV.Start), 'UniformOutput', false)';
    querystr = 'INSERT INTO USVs (USV_ID_spectralAnalysis,experiment_id, call_type_id, nlx_time, duration ) VALUES ';
    mysql(sprintf('%s %s', querystr, strjoin(datastrings', ',')))
end


mysql('close')
%% done!

clear answer calltypes ct_abbr ct_id datastrings db db_password db_user def dlg_title
clear experiment_id experiment_nr num_lines prompt querystr rat_name 