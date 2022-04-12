% ##############################################
% ##          RITA Excel to MySQL             ##
% ##############################################
%                        Falk Mielke; 15.08.2014
%
% read selected excel files and execute the SQL queries within
%
% arguments: 
%   - enter path to previously gathered data to skip excel opening
% 


function xl2sql_Eddy(varargin)

    % user needs to have r/w access
    db_user = 'eduard';
    db_password = 'H,urGel9';
    db = 'EddyTickling';

%% load file if user passes a path

    if (nargin ~= 0)
         the_loaded = load([varargin{1}],'upload_selection');
         data = the_loaded.upload_selection;
         clear the_loaded;
         nr_of_files = length(data);
    else
%% get file path

        [files] = GetFilePaths();
        nr_of_files = size(files,2);
        
        % check if actually files were selected
        if(nr_of_files == 0)
            fprintf('no file selected!\n');
            return;
        end
        
        
%% get data!
        % get session ids!
        [experiments, files, nr_of_files] = GetExperiments(files, db);
        if(nr_of_files == 0)
            fprintf('no file left!\n');
            return;
        end

        % fill data structure
%         data_columns = {'Session id','path'}; % ,'Session','Rec',''
        data = FillData(experiments, files, nr_of_files);
        
        data = GetExcelSQL(data, db);
    
    end % check nargin
        
        
%% GUI

% if one day we have time to do something as beautiful as the RITA loader,
% we'll do it here!
%         sessionslist = cell(nr_of_files,size(data_columns,2));       
%         sessionslist(:,1) = num2cell([data(:).Session_id]');
%         sessionslist(:,2) = {data(:).filepath}';
%         
%         [gui] = StartupGUI(data_columns);
% 
%         set(gui.L4_1,'data',sessionslist);


%% Upload Preparation
    % connect 
    mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));
        
    % optional: delete query
%         DeleteBeforeEntry()

    % loop through the data and insert
        for file = 1:nr_of_files
%             data(1,file).experiment_id = mysql();

            current_experiment = mysql(sprintf( ...
                        ['  SELECT DISTINCT experiment_id FROM Experiments ' ...
                         , ' WHERE date = ''%s'' AND experiment_nr = %i ' ...
                         , ' AND rat_id = (SELECT DISTINCT rat_id FROM Rats WHERE name = ''%s'' GROUP BY rat_id ORDER BY rat_id DESC LIMIT 1)  ' ...
                         ], data(1,file).date, data(1,file).experiment_nr, data(1,file).ratname));
            if (~isempty(current_experiment))
                existing_experiment = questdlg( ...
                    sprintf('Found data for experiment %i. DELETE?',current_experiment) ...
                    ,'RITA XL import','yes','no','yes'); 
                switch existing_experiment
                    case 'yes'
                        DeleteBeforeEntry(current_experiment);

                end % switch user choice
                        
            end % check for existing session
            
%% insert data filewise
            for tag = 1:length(data(1,file).data)

            % exclude empty sql queries
                if (isempty(data(1,file).data(1,tag).sql))
                    continue;
                end
                if (data(1,file).data(1,tag).sql{2} == ';')
                    continue;
                end

            % insert!
                fprintf('inserting experiment %s, %s, #%i,  %s: ', data(1,file).ratname, data(1,file).date, data(1,file).experiment_nr ...
                                    ,strcat(data(1,file).data(1,tag).tag));
                if strcmp('Rats', data(1,file).data(1,tag).tag)
                    if ~isempty(mysql(sprintf('SELECT DISTINCT rat_id FROM Rats WHERE name = ''%s'' ',data(1,file).ratname)))
                        continue;
                    end
                end
                querystr = strcat(data(1,file).data(1,tag).sql{:});
                sepqueries = strsplit(querystr, ';');
                for sub = 1:numel(sepqueries)
                    if(isempty(sepqueries{sub}))
                        continue;
                    end
                    mysql([sepqueries{sub},';']);
                end

            end %<- tags loop
        end %<- files loop
    
%% cleanup
        DuplicateRatStatus();
        mysql('close');
        
        fprintf('done! \n');
        
%% done!



%% ______________________________________________
%  ##############################################
%% ##      DELETE entries before INSERT        ##
%  ##############################################
%                         Falk Mielke; 24.05.2013
%
%  subfunction of RITA_xl2SQL

function DeleteBeforeEntry(experiment)

% temp_pack = mysql([ 'SELECT DISTINCT pack FROM Rats WHERE Rats_id IN (SELECT Rats_id FROM Session WHERE experiment_id = ',num2str(session),') GROUP BY pack ' ...
% 	' ; ']); 

% temp_rats = mysql([ ...
% 	' 		SELECT DISTINCT Rats_id FROM Rats WHERE pack IN(''', [temp_pack{:}], ''')  ' ...
% 	' 		GROUP BY Rats_id ' ...
% 	' ; ']); 
% rats = cell(1,length(temp_rats));
% for t=1:length(temp_rats)
%     rats(t) = {strcat('''',num2str(temp_rats(t)),'''')};
% end
% allrats = {};
% for t=1:length(rats)-1
%     allrats = {[allrats{:}, rats{t},',']};
% end
% allrats = {[allrats{:}, rats{end}]};

temp_rec = mysql([ ...
	' 		SELECT DISTINCT session_id FROM Sessions WHERE experiment_id = ',num2str(experiment),' GROUP BY session_id ' ...
	' ; ']); 
recs = cell(1,length(temp_rec));
for t=1:length(temp_rec)
    recs(t) = {strcat('''',num2str(temp_rec(t)),'''')};
end
allrecs = strjoin(recs, ', ');

if ~ (numel(recs) == 0)

    % #### DELETEs - careful now! ####
    fprintf('deleting experiment %i:\n',experiment);

    mysql([ ...
        ' DELETE FROM Phases WHERE session_id IN (', allrecs ,'); ']); 
    mysql([ ...
        ' DELETE FROM Sessions WHERE session_id IN (', allrecs ,'); ']); 
end
mysql([ ...
    ' DELETE FROM Experiments WHERE experiment_id = ',num2str(experiment),'; ']); 
mysql([ ...
    ' DELETE FROM ETCs WHERE experiment_id = ',num2str(experiment),'; ']); 

fprintf('done delting! rats stay in.\n');
                    
    end % Delete before entry

end % end main function
%% ______________________________________________


function DuplicateRatStatus()
    fprintf('cleaning up rat journals...\n');
    %/* (1) copy original data to a temp table */
    mysql(['CREATE TEMPORARY TABLE Journal_trunk SELECT DISTINCT ' ...
            , ' `rat_id`,`occasion`,`date`,`experiment_nr`,`session_nr`,`weight`,`estrus`,`notes` ' ...
            , ' FROM Rat_Journals ' ...
            , '  ' ... GROUP BY `rat_id`,`occasion`,`date`,`experiment_id`,`session_id`,`weight`,`estrus`,`notes`
            , ';']);

    %/* (2) clear status table */
    mysql('DELETE FROM Rat_Journals;');

    %/* (3) copy everything back */
    mysql(['INSERT INTO Rat_Journals (`rat_id`,`occasion`,`date`,`experiment_nr`,`session_nr`,`weight`,`estrus`,`notes`) ' ...
            , ' SELECT * FROM Journal_trunk;']);

    %/* (4) remove temp table */
    mysql('TRUNCATE Journal_trunk;');
    mysql('DROP TABLE Journal_trunk;');

end


%  ##############################################
%% ##             Get file paths               ##
%  ##############################################
%                         Falk Mielke; 24.05.2013
%
% asks the user for an excel file to upload
% output:   "files" and "dates" vector
%
    function [files] = GetFilePaths()
    % #### ATTENTION: ####
    % by now, "files" and "session_date" have to be entered seperately! the
    % latter is used for cleaning the DB before use.
    
        [filename, pathname] = uigetfile( ...
                    {  '*.xls?','MS Excel files (*.xls, *.xlsx, *.xlsm, *.xlsb)'; ...
                       '*.*',  'All Files (*.*)'}, ...
                       'Select excel sheet to upload', 'MultiSelect', 'on');

        files = cell(1,size(filename,2));
        if(~iscell(filename))
            if(filename == 0)
                files = {};
                return;
            end
            files = { strcat(pathname,filename);
                        };
        else % multiple files selected
            for fil = 1:size(filename,2)
                files(fil) = {[pathname, filename{fil}]};
            end
        end

    end % get file path
    
    
    
%  ##############################################
%% ##              Get sessions                ##
%  ##############################################
%                         Falk Mielke; 24.05.2013
%
% asks the user for an excel file to upload
% output:   "files" and "dates" vector
%    
function [experiments, files, nr_of_files] = GetExperiments(files, db)   

        nr_of_files = size(files,2);
        experiments = cell(nr_of_files, 3);
        
        % loop thru files
        fil=1;
        while(fil <= nr_of_files)
            
            % check if file is actually an excel file
            try
                validfile = xlsfinfo(files{fil});
            catch e
                switch e.identifier
                    case 'MATLAB:xlsread:FileNotFound'
                        return;
                    otherwise 
                        disp('this has never happened before:');
                        throw(e);
                end
            end
            
            if(isempty(validfile))
                fprintf('Invalid excel file! \n \t skipped file %s \n' ...
                    ,  [files{fil}]);
                files = files((1:nr_of_files~= fil));
                experiments = experiments((1:nr_of_files~= fil), :);
                nr_of_files = size(files,2);
                continue;
            end
        % check if db matches
            [~,xl_db] = xlsread(files{fil},'parameter','B3');
            if (~strcmp(xl_db(:), db))
                fprintf('database name doesn''t match! \n \t skipped file %s \n' ...
                    , [files{fil}]);
                files = files((1:nr_of_files~= fil));
                experiments = experiments((1:nr_of_files~= fil), :);
                nr_of_files = size(files,2);
                continue;
            end
            
            [~,~, raw] = xlsread(files{fil},'Experiments','E5:E8');
            experiments(fil, :) = raw([4,1,2])';
            fprintf('found experiment %s, %s, #%i \n', experiments{fil,1}, experiments{fil,2}, experiments{fil,3});
            
            fil = fil + 1;
        end % loop thru files   
end % get session ids
    
 

%  ##############################################
%% ##           FillData                       ##
%  ##############################################
%                                    ; 24.05.2013
%                
function [upload_selection] = FillData(experiments, files, nr_of_files)   

        upload_selection = struct();
        for dat = 1:nr_of_files
%             data(dat).experiment_id = experiments(dat);
            upload_selection(dat).ratname = experiments{dat,1};
            date_string = strsplit(experiments{dat,2},'/');
            upload_selection(dat).date = strcat(date_string{[3,2,1]});
            upload_selection(dat).experiment_nr = experiments{dat,3};
            upload_selection(dat).filepath = [files{dat}];
        end
        
        
end %fill data struct




    
%  ##############################################
%% ##           Start up the GUI               ##
%  ##############################################
%          from Victors RITALoaderGUI; 24.05.2013
%                
% function [gui] = StartupGUI(info_headers)                 
%         
%         gui.Window = figure( ...
%             'Name', 'RITALoaderGUI' ...
%             , 'NumberTitle', 'off' ...
%             , 'Position', [300 400 700 450] ...
%             , 'MenuBar', 'none' ...
%             , 'Toolbar', 'none' ...
%             , 'HandleVisibility', 'on' ...
%             );
%         gui.L0 = uiextras.HBox( 'Parent', gui.Window ...
%                               , 'Spacing', 5  ... 
%                               , 'Padding', 0  ...
%                               );
%         gui.L0_2 = uiextras.Panel( 'Parent', gui.L0 );
%         gui.L4 = uiextras.VBox( 'Parent', gui.L0_2 ...
%                               , 'Padding', 5 ...
%                               , 'Spacing', 5 ...
%                                 );
%         
%         gui.L4_1 = uitable( 'Parent', gui.L4, ...
%                             'ColumnName', info_headers ...
%                             ..., 'ColumnFormat', data.ColFormat ...
%                             ..., 'ColumnEditable', data.ColEdit ...
%                             , 'RowName', [] ...
%                             ..., 'CellSelectionCallback', @cellSelectCallback  ...
%                             ..., 'CellEditCallback', @cellEditCallback ...
%                             );
%                         
% end    % GUI builder
    



    
%  ##############################################
%% ##        Get SQL from Excel file           ##
%  ##############################################
%                         Falk Mielke; 04.12.2012
%
% input:    - a path where the read excel content is saved
%           - a cell array with file paths  
% output:   the data struct with prepared SQL queries from Excel
%
function [upload_selection] = GetExcelSQL(upload_selection, db)

% % sort files: newer files last
%     files = sort(files);
    files = {upload_selection(:).filepath}';
    
% tags := tables that are filled (marked columns in excel)
    tags = {  'Rats'...
            , 'Experiments'...
            , 'Sessions'...
            , 'Phases'...
            , 'ETCs'...
            , 'Rat_Journals'...
          };
  % rat journals is special
      for t=1:0
          tags = horzcat(tags, 'Rat_Journals'); %#ok<AGROW>
      end
      offset = [0,0,0,0,0,1];

% declare structure
%       data = struct('file',files,...
%                     'data', struct( 'tag',tags...
%                                     ,'lines',uint32([])...
%                                     ,'offset',uint8([])...
%                                     ,'sql',cell({''})));
        data = struct( 'tag',tags...
                        ,'lines',uint32([])...
                        ,'offset',uint8([])...
                        ,'sql',cell({''}));
                                
                                
      fWait = waitbar(0,'Loading queries from Excel ... ');
% go through files and read data
    for fil=1:size(upload_selection,2) % files
        
        upload_selection(fil).data = data;
        [~,txt] = xlsread([upload_selection(fil).filepath],'all_export','2:2');
        columnchoice = txt; clear txt;

        for j=1:length(tags)
            waitbar(j/length(tags),fWait,sprintf('file %i/%i',fil,length(files)));
            col = strcmp(tags{j},columnchoice);
            col = find(col);    
            upload_selection(fil).data(j).offset = col+offset(j);

    %       find in column number

            [~,txt] = xlsread(files{fil},'all_export',strcat(excelcol(upload_selection(fil).data(j).offset),...
                                                        ':',excelcol(upload_selection(fil).data(j).offset)));
            height = find(strcmp(';',txt)) - find(strcmp(tags{j},txt));
            clear txt;
            
            upload_selection(fil).data(j).lines = height;
            
    %       exception: forgot ";" in Session + it doesn't find 
            if (strcmp(tags(j),'Experiments'))
                 upload_selection(fil).data(j).lines = 2;
            end
            if (strcmp(tags(j),'Rat_Journals'))
                 upload_selection(fil).data(j).lines = 43;
            end
        
    %       read sql statements
            if(~isempty(upload_selection(fil).data(j).lines))
                xlinputrange = strcat('',...
                            excelcol(upload_selection(fil).data(j).offset),'3:',...
                            excelcol(upload_selection(fil).data(j).offset),num2str(2+upload_selection(fil).data(j).lines(1))...
                                       );
                [~,txt] = xlsread(files{fil},'all_export',xlinputrange);
                txt = txt(~strcmp(txt,''));
                upload_selection(fil).data(j).sql = txt;
            end
            
        end % all tags read
   
    end % all files read
    waitbar(1,fWait,'Done!');
    delete(fWait);
% save outcome


save_data = questdlg('save data for later?','RITA XL import','yes','no','no'); 
switch save_data
    case 'yes'
        savename = strcat(pwd(),'/',datestr(now,'yyyymmdd'),'_',db,'_xlsinsert','.mat');

        [filename, pathname] = uiputfile( ...
                    {  '*.mat','MAT-files (*.mat)'; ...
                       '*.*',  'All Files (*.*)'}, ...
                       'save spike file',savename);
                   if isequal(filename,0)
                       msgbox(sprintf('No file specified.\nsaved as %s.',savename),'RITA XL import');
                       filename = savename;
                   end
         save(strcat(pathname,filename),'upload_selection');
         fprintf('saved data to %s.mat \n',savename);
end  


%  ##############################################
%% ##         Excel column generater           ##
%  ##############################################
%                        Falk Mielke; 30.11.2012
%
% input:    a column number
% output:   the respective excel column string
%

% ##############################################
% ############### main function ################
function [col] = excelcol(c)
        col = '';
        c=uint32(c);

        letters = cell(1,26);
        for l = 1:26
            letters{l} = char(64+l);
        end
        clear l

    %  Base case: the lase letter of column name
        remainder = mod(c-1,26);
        quotient = (c - remainder)/26;


        if (quotient > 0)
            column(quotient);
        end

    % finally append last letter
        col = strcat(col,letters{remainder+1});

    
    
    
% ##### function: column #####
% 
% --> adds a new column letter before the previous step
    function [] = column(colm)
        rem = mod(colm-1,26)+1;
        quot = (colm - rem)/26;

    %  recursive step    
        if (quot > 0)
            column(quot);
        end

    % append letter
        col = strcat(col,letters{rem});
        end
% ###### eofctn: column ######

        
end %<- of "excelcol"

end %<- of "GetExcelSQL"



%  ##############################################
%% ##          delete duplicate rats           ##
%  ##############################################
%                         Falk Mielke; 29.05.2013
%
% finds all unique rats in database
% removes unused duplicates
%
% function RattusDuplicatus()
% %% . cleanup empty packs 
% %     mysql([ ...    
% %         'UPDATE Rats '...
% %         'SET pack = name '...
% %         'WHERE (pack IS NULL OR pack = '''') '...
% %         'AND purpose = ''','implanted',''' '...
% %         ]);
%     
%     
% %% . Select unique rat lines and occurrence
%     rattus = struct();
% 
%     [rattus.name ...
%         , rattus.purpose ...
%         , rattus.sex ...
%         ] = ...
%     mysql([ ...    
%             'SELECT DISTINCT  '...
%             'name '...
%             '	, purpose '...
%             '	, sex '...
%             'FROM ( '...
%             '	SELECT rat_id '...
%             '	, name '...
%             '	, purpose '...
%             '	, sex '...
%             '	FROM Rats '...
%             '	WHERE TRUE '...
%             '	AND TRUE '...
%             '	ORDER BY Rats_id ASC '...
%             ') AS allrats '...
%             'GROUP BY name, purpose, sex '...
%             ]);
% 
%     dupcount = length(rattus.name);
%     rattus.right_id = zeros(dupcount,1);
%     rattus.obsolete = struct();
% 
% 
% 
% %% . get first id of duplicates
% 
%     for i=1:dupcount
%             ratname = rattus.name{i};    
%             ratpurpose = rattus.purpose{i};
%             ratsex = rattus.sex{i};
%             ratpack = rattus.pack{i};
% 
%             rattus.right_id(i) = mysql([ ...       
%                     'SELECT DISTINCT Rats_id FROM Rats  '...
%                     'WHERE  '...
%                     '   name = ''',ratname,''' '...
%                     '   AND purpose = ''',ratpurpose,''' '...
%                     '   AND sex = ''',ratsex,''' '...
%                     '   AND pack = ''',ratpack,''' '...
%                     ' GROUP BY Rats_id ORDER BY Rats_id ASC'...
%                     ' LIMIT 1 '...
%                     '; '...
%                     ]);        
% 
% %% . get all other ids from duplicates
%             rattus.obsolete(i,1).ids = mysql([ ...       
%                     'SELECT DISTINCT Rats_id FROM Rats  '...
%                     'WHERE  '...
%                     '   name = ''',ratname,''' '...
%                     '   AND purpose = ''',ratpurpose,''' '...
%                     '   AND sex = ''',ratsex,''' '...
%                     '   AND pack = ''',ratpack,''' '...
%                     '   AND Rats_id NOT IN (',num2str(rattus.right_id(i)),') ' ...
%                     ' GROUP BY Rats_id ORDER BY Rats_id ASC'...
%                     '; '...
%                     ]);  
% 
%         obsoletestring = '';
%         for j=1:length(rattus.obsolete(i,1).ids)
%             obsoletestring = strcat(obsoletestring,num2str(rattus.obsolete(i,1).ids(j)),',');
%         end
%         obsoletestring = obsoletestring(1:end-1);
% 
% %% . update
%     %     - Session
%     %     - Stimulus reference (!type=rat)
%     %     - Rat_status
%     %     
%         if(~isempty(rattus.obsolete(i,1).ids))
% 
%             mysql([ ...    
%                 ' UPDATE Session '...
%                 ' SET rat_id = ', num2str(rattus.right_id(i)), ...
%                 ' WHERE rat_id IN (',obsoletestring,')  '...
%                 ]);     
% 
%             mysql([ ...    
%                 ' UPDATE Rat_status '...
%                 ' SET Rats_id = ', num2str(rattus.right_id(i)), ...
%                 ' WHERE Rats_id IN (',obsoletestring,')  '...
%                 ]); 
% 
%             mysql([ ...    
%                 ' UPDATE Stimulus ' ...
%                 ' SET reference = ', num2str(rattus.right_id(i)), ...
%                 ' WHERE type = ''rat'' ' ...
%                 ' AND reference IN (',obsoletestring,')  '...
%                 ]); 
% 
% %% . delete
%     %     - Rats
%     %     
%     fprintf('deleting duplicate rats now: \n');
%             mysql([ ...    
%                 ' DELETE FROM Rats ' ...
%                 ' WHERE Rats_id IN (',obsoletestring,')  '...
%                 ]); 
% 
%         end
%     end
% 
% end % end duplicate rats



%% ______________________________________________
%  ##############################################
%% ##                  backup                  ##
%  ##############################################

