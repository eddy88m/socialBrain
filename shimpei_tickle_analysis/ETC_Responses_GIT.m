function ETC_Responses_GIT()
%% access database
% User input
db.user = 'shimpei';
db.password = 'tickle';
db.db = 'shimpei_rita';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));
clear db

% screening
prompt={'Minimum firing rate '};
dlg_title='Cluster responses';
num_lines=1;
def={'0.5'};
answer=inputdlg(prompt,dlg_title,num_lines,def);
min_avg_firing=str2double(answer{1});

excl_MU = questdlg('Exclude MU?', 'Cluster responses', 'Yes');
switch excl_MU
    case 'Cancel'
        return
end


% get dataETC
if strcmp('Yes', excl_MU)
[etc_id, unitInfo, avg_firing, Break, dorsal, flip, ventral, dorsal_gentle, ventral_gentle, tail, chasing_hand, bright_light, notes] = mysql(sprintf(['' ...
            , ' SELECT etc_id, unitInfo, avg_firing, Break, dorsal, flip, ventral, dorsal_gentle, ventral_gentle, tail, chasing_hand, bright_light, notes' ...
            , ' FROM (' ...
            , ' SELECT * FROM ETC_Responses ' ...
            , ' RIGHT JOIN ' ...
            , ' (SELECT etc_id, unitInfo, avg_firing ' ...
            , ' FROM ETCs) AS ETC_selected ' ...
            , ' USING (etc_id) ' ...
            , ' ) AS ETC_Responses_OV ' ...
            , ' WHERE avg_firing >= %f ' ...
            , ' AND unitInfo != ''MU'' ' ... % excluding MU 
            , ' AND exclude != 1 ' ... % exclude unstable clusters
            , ' ORDER BY etc_id ASC ' ... 
            ], min_avg_firing ...
            ));
else
[etc_id, unitInfo, avg_firing, Break, dorsal, flip, ventral, dorsal_gentle, ventral_gentle, tail, chasing_hand, bright_light, notes] = mysql(sprintf(['' ...
            , ' SELECT etc_id, unitInfo, avg_firing, Break, dorsal, flip, ventral, dorsal_gentle, ventral_gentle, tail, chasing_hand, bright_light, notes ' ...
            , ' FROM (' ...
            , ' SELECT * FROM ETC_Responses ' ...
            , ' RIGHT JOIN ' ...
            , ' (SELECT etc_id, unitInfo, avg_firing ' ...
            , ' FROM ETCs) AS ETC_selected ' ...
            , ' USING (etc_id) ' ...
            , ' ) AS ETC_Responses_OV ' ...
            , ' WHERE avg_firing >= %f ' ...
            , ' AND exclude != 1 ' ... % exclude unstable clusters
            , ' ORDER BY etc_id ASC ' ... 
            ], min_avg_firing ...
            ));
end
clear excl_MU min_avg_firing
mysql('close')

%% sorting data

% option 1: table
% ETC_Table = table(etc_id ...
%                     , unitInfo ...
%                     , avg_firing ...
%                     , Break ...
%                     , dorsal ...
%                     , flip ...
%                     , ventral ...
%                     , dorsal_gentle ...
%                     , ventral_gentle ...
%                     , tail ...
%                     , chasing_hand ...
%                     , bright_light ...
%                     , notes ...
%                   );
% % example of sorting by avg_firing. 'etc_id, ascend' should always be as
% % the second sorting key
% ETC_Table = sortrows(ETC_Table, {'avg_firing', 'etc_id'}, {'ascend', 'ascend'});


% option 2: matrix -> uitable
% ETC_Matrix = [num2cell(etc_id) ...
%                 unitInfo ...
%                 num2cell([avg_firing ...
%                             Break ...
%                             dorsal ...
%                             flip ...
%                             ventral ...
%                             dorsal_gentle ...
%                             ventral_gentle ...
%                             tail ...
%                             chasing_hand ...
%                             bright_light ...
%                          ])...
%                 notes
%               ];
Matrix_Labels = {'etc_id' ...
                    , 'unitInfo' ...
                    , 'avg_firing' ...
                    , 'Break' ...
                    , 'dorsal' ...
                    , 'flip' ...
                    , 'ventral' ...
                    , 'dorsal_gentle' ...
                    , 'ventral_gentle' ...
                    , 'tail' ...
                    , 'chasing_hand' ...
                    , 'bright_light' ...
                    , 'notes' ...
                };
% % example of sorting by avg_firing.
% ETC_Matrix = sortrows(ETC_Matrix, [strmatch('avg_firing', Matrix_Labels) strmatch('etc_id', Matrix_Labels)]);


% option 3: matrix -> all strings then use HTML to highlight colors -> uitable

% double -> cell -> string -> remove space -> replace '-1' with 'decrease'
% -> replace '1' with 'increase'
ETC_Matrix = [num2cell(etc_id) ...
                unitInfo ...
                num2cell(avg_firing) ...
                strtrim([strrep(strrep(strrep(cellstr(num2str(Break)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(strrep(cellstr(num2str(dorsal)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(strrep(cellstr(num2str(flip)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(strrep(cellstr(num2str(ventral)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(strrep(cellstr(num2str(dorsal_gentle)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(strrep(cellstr(num2str(ventral_gentle)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(strrep(cellstr(num2str(tail)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(strrep(cellstr(num2str(chasing_hand)),' ',''), '-1', 'decrease'),'1','increase') ...
                         strrep(strrep(cellstr(num2str(bright_light)),' ',''), '1', 'effect') ...
                        ]) ...
                notes ...
              ];
                                            
                

%% displaying data

% cell color as HTML
start_col = 4;
for column = start_col:length(Matrix_Labels)-1
    for row = 1:length(etc_id)
        if strmatch('increase',ETC_Matrix(row, column))
            ETC_Matrix(row, column)=strcat('<html><body bgcolor="#71ee6d">', ETC_Matrix(row,column)); % green
        elseif strmatch('decrease',ETC_Matrix(row, column))
            ETC_Matrix(row, column)=strcat('<html><body bgcolor="#e7846f">', ETC_Matrix(row,column)); % red
        elseif strmatch('effect',ETC_Matrix(row, column))
            ETC_Matrix(row, column)=strcat('<html><body bgcolor="#fff277">', ETC_Matrix(row,column)); % yellow
        elseif strmatch('0', ETC_Matrix(row, column))
            ETC_Matrix{row, column}= '-';
        end
    end
end

% make a figure
set(0,'DefaultFigureWindowStyle','docked')
Notes_Width = 550;
UI=uitable('Data', ETC_Matrix ...
         , 'Units', 'normalized' ...
         , 'Position', [0 0 1 1] ...
         , 'ColumnName', Matrix_Labels ...
         , 'ColumnFormat', repmat({ 'long g'},1,length(Matrix_Labels)) ...
         , 'ColumnWidth', [repmat({ 'auto'}, 1, length(Matrix_Labels)-1) Notes_Width] ...
         );
set(0,'DefaultFigureWindowStyle','normal')




%% sorting function, hint from Undocummented Matlab: uitable sorting
% Display the uitable and get its underlying Java object handle
jscrollpane = findjobj(UI);
jtable = jscrollpane.getViewport.getView;
% Now turn the JIDE sorting on
jtable.setSortable(true);		% or: set(jtable,'Sortable','on');
jtable.setAutoResort(true);
jtable.setMultiColumnSortable(true);
jtable.setPreserveSelectionsAfterSorting(true);
% for some reasons, ColumnWidth of Notes is not applied, and I have to
% reset some another value.
UI.ColumnWidth{end}=560;
% for some reasons, sorting avg_firing does not work properly

end