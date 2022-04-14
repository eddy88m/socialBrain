%% USV types pie chart
% counts all the USVs uploaded on the database, and categorize them
% and compare tickling vs breaks

% User input
db.user = 'shimpei';
db.password = 'tickle';
db.db = 'shimpei_rita';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));

% Call type catalogue
[Type.call_type_id,  Type.call_type, Type.call_type_color] = mysql(sprintf(['' ...
            , ' SELECT DISTINCT Call_Types.call_type_id, Call_Types.call_type, Call_Types.color ' ...
            , ' FROM Call_Types ' ...
            , ' RIGHT JOIN USVs ' ...
            , ' ON USVs.call_type_id = Call_Types.call_type_id ' ...% only types that have ever been recorded
            , ' ORDER BY call_type_id ASC ' ...
            ]));
        
% Optionally, make 'combined' colour to yellow
Type.call_type_color{find(strcmp(Type.call_type,'combined'))}='FBE251';

% Phase catalogue
Phase_Catalogue = mysql(sprintf(['' ...
            , ' SELECT phase_type FROM Phase_Types ' ...
            , ' WHERE category = ''tickle'' ' ...
            , ' AND phase_type != ''pick up'' ' ...
            , ' AND phase_type != ''mixed'' ' ...
            , ' ORDER BY phase_type ASC ' ...
            ]));
psy_Phase_Catalogue = mysql(sprintf(['' ...
            , ' SELECT DISTINCT phase FROM Experiments ' ...
            , ' JOIN Sessions USING (experiment_id) ' ...
            , ' JOIN Phases USING (session_id) ' ...
            , ' WHERE notes LIKE ''Psychophysics'' ' ...
            , ' ORDER BY phase ASC ' ...
            ]));
Phase_Catalogue{end+1} = 'stimulation';
Phase_Catalogue{end+1} = 'none'; % for those out of phase
USV_Counts = zeros(length(Phase_Catalogue),length(Type.call_type)); % phase x call_type


% Get Experiments
stim_experiment_id = mysql(sprintf(['' ...
            , ' SELECT experiment_id FROM Phases ' ...
            , ' JOIN Sessions USING (session_id) ' ...
            , ' WHERE phase = ''stimulation'' ' ...
            , ' GROUP BY experiment_id ' ...
            ]));
anx_experiment_id = mysql(sprintf(['' ...
            , ' SELECT experiment_id FROM Sessions ' ...
            , ' WHERE brightness > 20 OR other_stimuli IS NOT NULL ' ...
            , ' GROUP BY experiment_id ' ...
            ]));
psy_experiment_id = mysql(sprintf(['' ...
            , ' SELECT experiment_id FROM Experiments ' ...
            , ' WHERE notes LIKE ''Psychophysics'' ' ...
            ]));
% non_regular_exp_id = strjoin(arrayfun(@(id) sprintf('%i', id), vertcat(anx_experiment_id, psy_experiment_id, stim_experiment_id), 'Un', 0), ',');
non_regular_exp_id = strjoin(arrayfun(@(id) sprintf('%i', id), vertcat(anx_experiment_id, psy_experiment_id), 'Un', 0), ',');
experiment_id = mysql(sprintf(['' ...
            , ' SELECT DISTINCT experiment_id ' ...
            , ' FROM USVs ' ...
            , ' WHERE experiment_id NOT IN (%s) ' ...
            , ' ORDER BY experiment_id ASC ' ...
            ], non_regular_exp_id));
% Followings are for normal experiments (neither stim, anx nor psy)
NoOfRats = length(unique(floor((experiment_id * 1e-3))));
NoOfExperiments = length(experiment_id);
USVsDownloaded = zeros(NoOfExperiments,1);
USVsCounted = zeros(NoOfExperiments,1);
Phase_NoOfExperiments = zeros(length(Phase_Catalogue), 1);

% Access phases of each experiment, and determine in which phase USVs were
% observed.

for exp = 1:length(experiment_id)   % Experiment loop
    ThisExp_id = experiment_id(exp);
    MinSession_id = ThisExp_id * 1000;
    MaxSession_id = MinSession_id + 999;
    % get phase times
    [Phase_start_temp, Phase_end_temp, Phase_name_temp] = mysql(sprintf(['' ...% these are temp variables and overwritten in every loop
            , ' SELECT start_time, end_time, phase ' ...
            , ' FROM Phases ' ...
            , ' WHERE session_id BETWEEN %i AND %i ' ...
            , ' ORDER BY start_time ASC ' ...
            ], MinSession_id, MaxSession_id ...
            ));
    % count # of experiments for each phase
    % e.g. 'dorsal anterior' are only used in psychophysics
    % I deal with 'none' phase later
    for pha = 1:length(Phase_Catalogue)
        ThisPhase = Phase_Catalogue{pha};
        if ~isempty(find(strcmp(Phase_name_temp, ThisPhase))) %the phase in this experiment
            Phase_NoOfExperiments(pha) = Phase_NoOfExperiments(pha) + 1;
        end
    end
    Pha_NoEx_counted = 0;
    
    % get USVs
    [usv_type_id_temp, usv_time_temp] = mysql(sprintf(['' ...
            , ' SELECT call_type_id, nlx_time ' ...
            , ' FROM USVs ' ...
            , ' WHERE experiment_id = %i ' ...
            , ' ORDER BY nlx_time ASC ' ... 
            ], ThisExp_id ...
            ));
    USVsDownloaded(exp,1) = USVsDownloaded(exp,1) + length(usv_type_id_temp);
    
    % For each usv, check in which phase it's pronounced
    for usv = 1:length(usv_time_temp)   % USV loop
        for pha = 1:length(Phase_start_temp)    % Phase loop
            if usv_time_temp(usv) >= Phase_start_temp(pha) && usv_time_temp(usv) < Phase_end_temp(pha) % during this phase
                usv_phase_temp(usv,1) = Phase_name_temp(pha);
            end
        end
        if length(usv_phase_temp) == usv-1 % no phase assigned i.e. out of phase = 'none'
            usv_phase_temp{usv,1} = 'none';
            if Pha_NoEx_counted == 0 % count # of experiments for 'none' phase
                Phase_NoOfExperiments(find(strcmp(Phase_Catalogue, 'none'))) ...
                    = Phase_NoOfExperiments(find(strcmp(Phase_Catalogue, 'none'))) + 1;
                Pha_NoEx_counted = 1;
            end
        end
    end
    
    % Now that we know phase and call_type of each usv in this experiment,
    % let's count up.
    % Before starting, check all dimensions match
    if length(usv_phase_temp) ~= length(usv_time_temp) % there are USVs without phase name
        error('Dimension mismatch: usv_phase_temp & usv_time_temp')
    elseif length(usv_time_temp) ~= length(usv_type_id_temp) % there are USVs without call_type
        error('Dimension mismatch: usv_time_temp & call_type_id_temp')
    end
 
    % Travel through USVs, for each phase, check call_type_id and usv_phase_temp
    for pha = 1:length(Phase_Catalogue) % phase catalogue loop
        for usv = 1:length(usv_phase_temp) %USV loop
            if strcmp(usv_phase_temp{usv}, Phase_Catalogue{pha}) %in this phase, then count
                Column = find(Type.call_type_id == usv_type_id_temp(usv)); % call_type column
                USV_Counts(pha, Column) = USV_Counts(pha, Column) + 1;
                USVsCounted(exp,1) = USVsCounted(exp,1) + 1;
            end
        end
    end
    
    if USVsDownloaded(exp,1) - USVsCounted(exp,1) ~= 0
        error('There are USVs uncounted in experiment_id = %i',experiment_id(exp));
    end

    % reset temp variable, just in case...
    clear Phase_start_temp
    clear Phase_end_temp
    clear Phase_name_temp
    clear call_type_id_temp
    clear usv_time_temp
    usv_phase_temp = {};
end     % Experiment loop
        
mysql('close')
clear db Column MaxSession_id MinSession_id Phase_end_temp Phase_name_temp Phase_start_temp ThisExp_id ThisPhase
clear USVsCounted usv_type_id_temp exp experiment_id pha usv usv_phase_temp usv_time_temp USVsDownloaded Pha_NoEx_counted
clear anx_experiment_id non_regular_exp_id psy_experiment_id stim_experiment_id

%#############################################################################################################
% This section makes simpler USV types (modulated; trill&M-trill; combined; other)
% If full category is needed, comment these out
mod_id = Type.call_type_id(strmatch('modulated', Type.call_type));
trill_id = Type.call_type_id(strmatch('trill', Type.call_type));
mtrill_id = Type.call_type_id(strmatch('m-trill', Type.call_type));
comb_id = Type.call_type_id(strmatch('combined', Type.call_type));
% id is used in the database. num is column index in Matlab
mod_num = find(Type.call_type_id == mod_id);
trill_num = find(Type.call_type_id == trill_id);
mtrill_num = find(Type.call_type_id == mtrill_id);
comb_num = find(Type.call_type_id == comb_id);
% Overwrite Type
Type.call_type_color = [Type.call_type_color(mod_num) ...
                      , Type.call_type_color(trill_num) ...
                      , Type.call_type_color(comb_num) ...
                      , 'CECECE']'; % light grey for others
Type.call_type = [Type.call_type(mod_num) ...
                      , Type.call_type(trill_num) ...
                      , Type.call_type(comb_num) ...
                      , 'others']';
Type.call_type_id = [mod_id, trill_id, comb_id, 0]';

% Modify USV_Counts into simpler types
USV_Counts_mod = USV_Counts(:, mod_num);
USV_Counts_trill = USV_Counts(:, trill_num)+USV_Counts(:, mtrill_num);
USV_Counts_comb = USV_Counts(:, comb_num);
USV_Counts_others = zeros(size(USV_Counts, 1), 1);
for thisType = 1:size(USV_Counts, 2)
    if ~ismember(thisType, [mod_num, trill_num, mtrill_num, comb_num])
        USV_Counts_others = USV_Counts_others + USV_Counts(:, thisType);
    end
end
USV_Counts = horzcat(USV_Counts_mod, USV_Counts_trill, USV_Counts_comb, USV_Counts_others);

clear mod_id trill_id comb_id USV_Counts_comb USV_Counts_mod USV_Counts_others USV_Counts_trill thisType
clear comb_num mod_num trill_num
%#############################################################################################################

% Let's plot!

% MATLAB ignores zero values for pie chart. This makes a problem when I
% want to manage colours.

% Three large graphs for All, Interaction, Out-of-interaction
Layout_large_hor = 3;
Layout_large_ver = 2;

% All
plot_this_all = sum(USV_Counts);
figure
graph_position = subplot(Layout_large_ver, Layout_large_hor, 1);
ThisPie = pie(graph_position, plot_this_all);
ThisPie_handle = findobj(ThisPie, 'Type', 'patch');
for ThisType = 1:length(Type.call_type)
    set(ThisPie_handle(ThisType), 'FaceColor', hex2rgb(Type.call_type_color(ThisType))/255)
end
title(graph_position, {'All'},'FontWeight','bold', 'FontSize', 16)
legend(Type.call_type, 'Location', 'westoutside','Orientation','vertical')
annotation('textbox', [0.01, 0.75, 0.2, 0.2], 'String' ...
                    , {sprintf('Total number of USVs = %i', sum(sum(USV_Counts))) ...
                    , sprintf('Number of experiments = %i', NoOfExperiments) ...
                    , sprintf('Number of rats = %i', NoOfRats) ...
                    }, 'EdgeColor', 'None' ...
                    , 'FontSize', 14 ...
                    );

% Out-of-interaction
% break, baseline and none
sum_out = zeros(1,size(USV_Counts,2)); % = # no of columns = # of call types
out_rows = find(strcmp(Phase_Catalogue,'break') | strcmp(Phase_Catalogue,'baseline') | strcmp(Phase_Catalogue,'none'));
for row = 1:length(out_rows)
    sum_out = sum_out + USV_Counts(out_rows(row),:);
end

% eliminate zero entries
type_entry = [];
plotcount = 1;
plot_this_out = zeros(length(sum_out) - length(find(sum_out==0)),1);
for ThisType = 1:length(sum_out)
    if sum_out(ThisType) ~= 0
        type_entry(plotcount) = ThisType;
        plot_this_out(plotcount) = sum_out(ThisType);
        plotcount = plotcount + 1;
    end
end

graph_position = subplot(Layout_large_ver, Layout_large_hor, 3);
ThisPie = pie(graph_position, plot_this_out);
ThisPie_handle = findobj(ThisPie, 'Type', 'patch');
for ThisType = 1:length(type_entry)
    set(ThisPie_handle(ThisType), 'FaceColor',hex2rgb(Type.call_type_color(type_entry(ThisType)))/255)
end
title(graph_position, sprintf('Out of interaction (%i USVs)', sum(plot_this_out)), 'FontWeight','bold', 'FontSize', 16)

% Interaction
% All - Out
sum_int = plot_this_all - sum_out;
% eliminate zero entries
type_entry = [];
plotcount = 1;
plot_this_int = zeros(length(sum_int) - length(find(sum_int==0)),1);
for ThisType = 1:length(sum_int)
    if sum_int(ThisType) ~= 0
        type_entry(plotcount) = ThisType;
        plot_this_int(plotcount) = sum_int(ThisType);
        plotcount = plotcount + 1;
    end
end

graph_position = subplot(Layout_large_ver, Layout_large_hor, 2);
ThisPie = pie(graph_position, plot_this_int);
ThisPie_handle = findobj(ThisPie, 'Type', 'patch');
for ThisType = 1:length(type_entry)
    set(ThisPie_handle(ThisType), 'FaceColor',hex2rgb(Type.call_type_color(type_entry(ThisType)))/255)
end
title(graph_position, sprintf('Interaction (%i USVs)', sum(plot_this_int)), 'FontWeight','bold', 'FontSize', 16)


% Small graphs for each phase
Layout_small_hor = length(Phase_Catalogue)/2;
Layout_small_ver = 4; % in two rows below the large graphs
Small_graphs_start = Layout_small_hor * Layout_small_ver / 2 ;

for pha = 1:length(Phase_Catalogue)
    plotcount = 1;
    type_entry = [];
    plot_this = [];
    for ThisType = 1:length(Type.call_type)
        if isempty(find(USV_Counts(pha,ThisType)==0)) % not empty call_types
            plot_this(plotcount) = USV_Counts(pha,ThisType);
            type_entry(plotcount) = ThisType;
            plotcount = plotcount + 1;
        end
    end
    
    % Labels
    Labels = {};
    for ThisType = 1:length(type_entry)
        Labels{ThisType,1} = Type.call_type{type_entry(ThisType)};
    end

    graph_position = subplot(Layout_small_ver, Layout_small_hor, Small_graphs_start + pha);
    ThisPie = pie(graph_position, plot_this);%,Labels);
    ThisPie_handle = findobj(ThisPie, 'Type', 'patch');
    % managing colours
    for ThisType = 1:length(type_entry)
        set(ThisPie_handle(ThisType), 'FaceColor',hex2rgb(Type.call_type_color(type_entry(ThisType)))/255)
    end

     
    title(graph_position, {Phase_Catalogue{pha}; sprintf('%i experiments',Phase_NoOfExperiments(pha)); sprintf('%i USVs', sum(USV_Counts(pha,:)))},'FontWeight','bold')
end

clear Layout_large_hor Layout_large_ver Layout_small_hor Layout_small_ver
clear NoOfUSVs Small_graphs_start ThisPie ThisPie_handle plotcount
clear ThisType graph_position pha plot_this plot_this_all plot_this_int plot_this_out Labels type_entry
clear sum_int sum_out NoOfLargeGraphs row out_rows