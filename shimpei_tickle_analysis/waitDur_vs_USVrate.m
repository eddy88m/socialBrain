%% waitDur_vs_USVrate
% calculate relationship of poke-tickle latency and subsequent tickle-induced USVs in nose-poke experiments

incl_chasing = 0;


db.user = 'shimpei';
db.password = 'tickle';
db.db = 'shimpei_rita';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));

% get Phases from nose-poke experiments
[Phases.exp_id, Phases.phase, Phases.start_time, Phases.end_time] = mysql(sprintf(['' ...
        ' SELECT floor(session_id/1000) AS exp_id, phase, start_time, end_time FROM Phases ', ...
        ' WHERE session_id IN ( ', ...
            ' SELECT DISTINCT session_id FROM Phases ', ...
            ' WHERE phase = ''nose-poke'' ) ', ...
        ' ORDER BY exp_id, start_time ASC ' ...
        ]));

ticklePhases = {'dorsal', 'flip', 'ventral'};
if incl_chasing
    ticklePhases(end+1) = {'chasing hand'};
end   

% calculate number of tickle phases following each wait
isWait = strcmp(Phases.phase, {'wait'});
isTickle = ismember(Phases.phase, ticklePhases);
nTicklePhases = find(diff(isTickle)==-1) - find(diff(isTickle)==+1);
% check whether all tickle phases are after wait
if length(nTicklePhases) ~= sum(isWait)
    warning('There seem to be tickle phases not following wait');
end
% time for merged ticklePhase
tickleStarts = Phases.start_time(find(isWait)+1);
tickleEnds = Phases.end_time(find(isWait)+nTicklePhases);
wait_exp_id = Phases.exp_id(isWait);

% get number of USVs during ticklePhase for each wait
query = arrayfun(@(x) ...
        sprintf([' SELECT COUNT(autousvcomb_id) FROM AutoUSVs_Comb ',...
                 ' WHERE experiment_id = %i ', ...
                 ' AND nlx_time >= %.2f ', ...
                 ' AND nlx_time < %.2f ', ...
                 ], wait_exp_id(x), tickleStarts(x), tickleEnds(x) ...
                 ), 1:length(nTicklePhases), 'UniformOutput', false);
nUSV = zeros(length(nTicklePhases),1);
for i=1:length(nUSV)
    nUSV(i) = mysql(query{i});
end

mysql('close');


% calculate USV rate
ms2s = 1e-3;
tickleDur = tickleEnds - tickleStarts;
tickleDur = tickleDur * ms2s;
usvRate = nUSV ./ tickleDur;
waitDur = (Phases.end_time(isWait) - Phases.start_time(isWait)) * ms2s;

% plot
figure;
[R,P] = regPlot(waitDur, usvRate);
xlabel('Poke-tickle latency [s]');
ylabel('USV rate [Hz]');

%%
function [R,P,Rsq] = regPlot(xVal,yVal)
maxValue = ceil(max([xVal;yVal]));
[R,P] = corrcoef(xVal,yVal);
Rsq = R(1,2)^2;
slope = R(1,2)*(std(yVal)/std(xVal));
y = mean(yVal)-(mean(xVal)*slope);
x = min(xVal):maxValue/10:max(xVal);

plot(xVal,yVal,'.','MarkerSize',20,'Color','k');
hold on
plot(x,slope*x+y,'k-')
hold off
ylim([0 maxValue])
xlim([0 maxValue])

end
