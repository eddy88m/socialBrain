%% Latency
clc
list = [{'Neck'} ...
      , {'Ja'} ...
      ];
rep = 20;
ticklingSequence = cell(1,rep);
list=repmat(list, [1,rep/length(list)]);
ticklingSequence = list(randperm(rep));
for i = 1:length(list)
    fprintf('Trial %i', i);
    display(ticklingSequence(i));
    pause
end

save(sprintf('latency_%s.mat', datestr(today)),'ticklingSequence')
clear

%% Body parts
clc
list = [{'Head'} ...
      , {'Neck'} ...
      , {'Trunk'} ...
      , {'Arm pit'} ...
      , {'Foot'} ...
      ];
rep = 25;
ticklingSequence = cell(1,rep);
list=repmat(list, [1,rep/length(list)]);
ticklingSequence = list(randperm(rep));
for i = 1:length(list)
    fprintf('Trial %i', i);
    display(ticklingSequence(i));
    pause
end

save(sprintf('bodyparts_%s.mat', datestr(today)),'ticklingSequence')
clear
%% self-touch

clc
list = [{'Ipsi'} ...
      , {'Contra'} ...
      , {'Air ipsi'} ...
      , {'Air contra'} ...
    
      , {'Control'} ...
      ];
rep = 25;
ticklingSequence = cell(1,rep);
list=repmat(list, [1,rep/length(list)]);
ticklingSequence = list(randperm(rep));
for i = 1:length(list)
    fprintf('Trial %i', i);
    display(ticklingSequence(i));
    pause
end

save(sprintf('selftouch_%s.mat', datestr(today)),'ticklingSequence')
clear