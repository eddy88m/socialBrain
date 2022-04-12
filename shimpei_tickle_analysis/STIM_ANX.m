% STIM_ANX.m
% analysis for STIM-ANX-HOME experiments
% file requirement: mintersect (multiple intersect) https://www.mathworks.com/matlabcentral/fileexchange/6144-mintersect-multiple-set-intersection?s_tid=mwa_osa_a

%% Getting data
db_user = 'shimpei';
db_password = 'tickle';
db = 'shimpei_rita';
mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));

% get STIM_ANX experiments
experiments = mysql(sprintf(['', ...
                        ' SELECT DISTINCT experiment_id FROM Phases ', ...
                        ' JOIN Sessions USING (session_id) ' , ...
                        ' WHERE phase = ''stimulation'' ', ...
                        ' AND other_stimuli IS NOT NULL ', ...
                        ' ORDER BY experiment_id ASC ' ...
                        ]));
% get phases and USV rates for each phase
disp('Calculating in the database...');
[phase_id, usv_rate, layer, stim_amp, stim_frq, stim_success, stim_tt, experiment_id, session_nr, other_stimuli] ...
    = mysql(sprintf(['', ...
                    ' SELECT phase_id, count(usv_count)/(phase_dur/1000) AS usv_rate, ', ...
                    ' layer, stim_amp, stim_frq, stim_success, stim_tt, experiment_id, session_nr, other_stimuli ', ...
                    ' FROM ( ', ...
                        ' SELECT phase_id, Phases.start_time, Phases.end_time, Phases.end_time - Phases.start_time AS phase_dur, ' , ...
                        ' layer, stim_amp, stim_frq, stim_success, Sessions.experiment_id, session_nr, other_stimuli, stim_tt, ', ...
                        ' autousvcomb_id - autousvcomb_id + 1 AS usv_count ', ...
                        ' FROM Phases ' , ...
                        ' LEFT JOIN Sessions USING (session_id) ' , ...
                        ' LEFT JOIN AutoUSVs_Comb AS USV ', ...
                        ' ON ( ', ...
                        ' (Sessions.experiment_id = USV.experiment_id) ' , ...
                        ' AND ', ...
                        ' (Phases.start_time <= USV.nlx_time) ', ...
                        ' AND ', ...
                        ' (USV.nlx_time < Phases.end_time) ', ...
                        ' ) ', ...
                        ' WHERE Sessions.experiment_id IN (%s) ', ...
                        ' AND phase = ''stimulation'' ', ...
                        ' ) AS phaseUSV ', ...
                     ' GROUP BY phase_id ' , ...
                     ' ORDER BY phase_id ASC ', ...
                    ], strjoin(arrayfun(@(x) num2str(experiments(x)), 1:length(experiments), 'UniformOutput', false), ', ') ...
                    ));
mysql('close');

%% Data wrangling for overview plots
disp('Data wrangling...');
if length(unique(phase_id)) ~= length(phase_id)
    error('Duplicates in phase_id. Check the original data');
end
exp_tt = experiment_id * 100 + stim_tt; % unique for each stim site that yields a graph
graph_id = unique(exp_tt);
other_stimuli(cellfun(@isempty,other_stimuli))={'Control'};
other_stimuli(strcmp(other_stimuli,'EPF'))={'Anxiogenic'};
overview = table(phase_id, experiment_id, session_nr, other_stimuli, stim_tt, exp_tt, layer, stim_amp, usv_rate);
overview = sortrows(overview, 'phase_id', 'ascend');

% plot x: stim_amp, y: usv_rate, lines as many as sessions
grid_size = ceil(sqrt(length(graph_id)));
figure;
for g = 1:length(graph_id)
    h = subplot(grid_size,grid_size,g);
    ses_amp_usv = [session_nr(exp_tt == graph_id(g)) stim_amp(exp_tt == graph_id(g)) usv_rate(exp_tt == graph_id(g))];
    unq_ses = unique(ses_amp_usv(:,1));
    for ses = 1:length(unq_ses)
        ses_name = [num2str(unq_ses(ses)), ': ', cell2mat(unique(other_stimuli(exp_tt==graph_id(g) & session_nr==unq_ses(ses))))];
        [x, ~, iAmp] = unique(ses_amp_usv(ses_amp_usv(:,1)==unq_ses(ses), 2));
        y = accumarray(iAmp, ses_amp_usv(ses_amp_usv(:,1)==unq_ses(ses), 3), [], @mean);
        n = accumarray(iAmp, 1);
        stdev = accumarray(iAmp, ses_amp_usv(ses_amp_usv(:,1)==unq_ses(ses),3), [], @std);
        sem = stdev./sqrt(n);
%         errorbar(x,y,sem, '-o', 'MarkerSize', 8, 'DisplayName', ses_name);
        plot(x,y,'-o','MarkerSize',8,'DisplayName',ses_name);
        legend;
        hold on
    end
    hold off
    xlabel('Amplitude [uA]');
    ylabel('USV rate [Hz]');
    h.XLim = [0, h.XLim(2)+50];
    h.YLim(1) = 0;
    title([num2str(floor(graph_id(g)/100)), ': TT', ...
          num2str(unique(stim_tt(exp_tt==graph_id(g)))), ...
          ' L', cell2mat(unique(layer(exp_tt==graph_id(g)))) ...
          ]);
end

%% Population analysis
% plot USV rates at maximum amplitude where all conditions were tested
% get such amplitude for each stimulation site (exp_tt)
expTT_maxAmp = [graph_id zeros(length(graph_id),1)];
for g = 1:length(graph_id)
    ses_amp_usv = [session_nr(exp_tt == graph_id(g)) stim_amp(exp_tt == graph_id(g)) usv_rate(exp_tt == graph_id(g))];
    unq_ses = unique(ses_amp_usv(:,1));
    if length(unq_ses) ~= 1
        runintersect = stim_amp(exp_tt==graph_id(g) & session_nr==unq_ses(1));
        for ses = 2:length(unq_ses)
            runintersect = intersect(runintersect, stim_amp(exp_tt==graph_id(g) & session_nr==unq_ses(ses)));
        end
        expTT_maxAmp(g,2) = max(runintersect);
    end
end

% remove exp_tt with only one condition
if ~isempty(expTT_maxAmp(expTT_maxAmp(:,2)==0, :))
    graph_id(graph_id==expTT_maxAmp(expTT_maxAmp(:,2)==0,1)) = [];
    expTT_maxAmp(expTT_maxAmp(:,2)==0, :) = [];
end
% another exp_tt loop to calculate usv rate
x = {'Control'; 'Anxiogenic'; 'Home cage'};
ys = zeros(length(x), length(graph_id)); % condition by site
names = cell(length(graph_id),1); % experiment_id, tetrode #, layer, amplitude
for g = 1:length(graph_id)
    ses_usv = [session_nr(exp_tt == graph_id(g) & stim_amp==expTT_maxAmp(g,2)) usv_rate(exp_tt == graph_id(g) & stim_amp==expTT_maxAmp(g,2))];
    unq_ses = unique(ses_usv(:,1));
    for ses = 1:length(unq_ses)
        % update mean usv_rate for this site under this condition
        ys(strcmp(x,unique(other_stimuli(exp_tt == graph_id(g) & session_nr == unq_ses(ses)))), g) = mean(ses_usv(ses_usv(:,1)==ses, 2));
    end
    % get plot name
    names(g) = {[num2str(floor(graph_id(g)/100)), ': TT', ...
                num2str(unique(stim_tt(exp_tt==graph_id(g)))), ...
                ' L', cell2mat(unique(layer(exp_tt==graph_id(g)))), ', ',...
                num2str(expTT_maxAmp(g, 2)), ' uA' ...
                ]};
end

% plot
figure;
% mean and SEM
means =  mean(ys,2);
sem = std(ys')'/sqrt(size(ys,2));
errorbar(1:length(x), means, sem, 'o', 'MarkerSize',10, 'CapSize', 18, 'DisplayName', 'Mean SEM');
hold on
% individual sites
for g = 1:length(graph_id)
    plot(1:length(x), ys(:,g), 'DisplayName', names{g});
    hold on
end
legend;
xlim([0.5, 3.5])
xticks(1:length(x))
xticklabels(x)
ylabel('USV rate [Hz]')