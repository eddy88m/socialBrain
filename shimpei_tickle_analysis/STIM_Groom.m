% STIM_Groom.m
% analysis for STIM-selfTouch experiments
% file requirement: mintersect (multiple intersect) https://www.mathworks.com/matlabcentral/fileexchange/6144-mintersect-multiple-set-intersection?s_tid=mwa_osa_a

%% Getting data
db_user = 'shimpei';
db_password = 'tickle';
db = 'shimpei_rita';
mysql('open','mysql',db_user,db_password); mysql(strcat('use ',db));

% get STIM experiments with self-touch
experiments = mysql(sprintf(['', ...
                        ' SELECT DISTINCT experiment_id FROM Phases ', ...
                        ' JOIN Sessions USING (session_id) ' , ...
                        ' WHERE phase = ''stimulation'' ', ...
                        ' AND (notes LIKE ''%%grooming%%'' ', ...
                        ' OR notes LIKE ''%%scratching%%'') ', ...
                        ' ORDER BY experiment_id ASC ' ...
                        ]));
% get phases and USV rates for each phase
disp('Calculating in the database...');
[phase_id, self_touch, usv_rate, layer, stim_amp, stim_frq, stim_success, stim_tt, experiment_id, session_nr] ...
    = mysql(sprintf(['', ...
                    ' SELECT phase_id, ', ...
                    ' CASE WHEN notes LIKE ''%%grooming%%'' OR notes LIKE ''%%scratching%%'' THEN 1 ELSE 0 END AS self_touch, ', ...
                    ' count(usv_count)/(phase_dur/1000) AS usv_rate, ', ...
                    ' layer, stim_amp, stim_frq, stim_success, stim_tt, experiment_id, session_nr ', ...
                    ' FROM ( ', ...
                        ' SELECT phase_id, Phases.notes, Phases.start_time, Phases.end_time, Phases.end_time - Phases.start_time AS phase_dur, ' , ...
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
                        ' AND Sessions.other_stimuli IS NULL ', ...
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
graph_id = unique(exp_tt(self_touch==1)); % only sites with self-touch
overview = table(phase_id, experiment_id, session_nr, stim_tt, exp_tt, layer, stim_amp, self_touch, usv_rate);
overview = sortrows(overview, 'phase_id', 'ascend');

% plot x: stim_amp, y: usv_rate, lines: self-touch and not
grid_size = ceil(sqrt(length(graph_id)));
figure;
for g = 1:length(graph_id)
    h = subplot(grid_size,grid_size,g);
    self_amp_usv = [self_touch(exp_tt == graph_id(g)) stim_amp(exp_tt == graph_id(g)) usv_rate(exp_tt == graph_id(g))];
    
    for self = 0:1
        if self
            self_name = ' (self-touch)';
        else
            self_name = '';
        end
        plot_name = [num2str(floor(graph_id(g)/100)), self_name];
        [x, ~, iAmp] = unique(self_amp_usv(self_amp_usv(:,1)==self, 2));
        y = accumarray(iAmp, self_amp_usv(self_amp_usv(:,1)==self, 3), [], @mean);
        n = accumarray(iAmp, 1);
        stdev = accumarray(iAmp, self_amp_usv(self_amp_usv(:,1)==self,3), [], @std);
        sem = stdev./sqrt(n);
%         errorbar(x,y,sem, '-o', 'MarkerSize', 8, 'DisplayName', plot_name);
        plot(x,y,'-o','MarkerSize',8,'DisplayName',plot_name);
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
% plot USV rates at maximum amplitude where all conditions (self-touch and not) were tested
% get such amplitude for each stimulation site (exp_tt)
% Typically there are no amplitude where only stim-self-touch exist
% Thus get max amplitude of self-touch
expTT_maxAmp = [graph_id zeros(length(graph_id),1)];
for g = 1:length(graph_id)
    self_amp_usv = [self_touch(exp_tt == graph_id(g)) stim_amp(exp_tt == graph_id(g)) usv_rate(exp_tt == graph_id(g))];
    expTT_maxAmp(g,2) = max(self_amp_usv(self_amp_usv(:,1)==1, 2));
end

% another exp_tt loop to calculate usv rate
x = {'Out of self-touch'; 'During self-touch'};
ys = zeros(length(x), length(graph_id)); % condition by site
names = cell(length(graph_id),1); % experiment_id, tetrode #, layer, amplitude
for g = 1:length(graph_id)
    self_usv = [self_touch(exp_tt == graph_id(g) & stim_amp==expTT_maxAmp(g,2)) usv_rate(exp_tt == graph_id(g) & stim_amp==expTT_maxAmp(g,2))];
    for self = 0:1
        % update mean usv_rate for this site under this condition
        ys(self+1, g) = mean(self_usv(self_usv(:,1)==self, 2));
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