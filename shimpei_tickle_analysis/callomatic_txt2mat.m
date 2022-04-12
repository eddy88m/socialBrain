%% Convert TXT to MAT for call-o-matic

% call-o-matic generates an error when load a text file
% this little script converts a text file to a MAT file, which can be
% loaded in the call-o-matic.
% Shimpei 2016

USV_file=dir('*-labels-*.txt');
USV_labels=readtable(USV_file.name,'Delimiter','tab','ReadVariableNames',false);
labels = [num2cell(USV_labels{:,{'Var1'}}), num2cell(USV_labels{:,{'Var2'}}), USV_labels{:,{'Var3'}}];
clear USV_file USV_labels