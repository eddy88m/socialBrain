%% USV raster for Eddy
% requirement: run tickleSyncTime.m and ELAN and USV in workspace

if ~exist('ELAN')
    error('prepare ELAN structure in the Workspace')
end
% Get colours from Database    
db.user = 'eduard';
db.password = 'H,urGel9';
db.db = 'EddyTickling';
mysql('open','mysql',db.user,db.password); mysql(strcat('use ',db.db));
[Phase_type, Hex_color] = mysql('SELECT phase_type, color_code FROM Phase_Types');
for ThisPhase = 1:length(Hex_color)
    Phase_color{ThisPhase,1} = hex2rgb(Hex_color(ThisPhase))/255;
end
mysql('close');

% Plot phases
set(0,'DefaultFigureWindowStyle','docked')
figure
hold on
ms2s = 1e-3;
for ThisPhase = 1:length(ELAN.PhaseNames)
    ColorIndices(ThisPhase,1) = find(strcmpi(Phase_type,ELAN.PhaseNames{ThisPhase}));
    Rect = rectangle('Position', [ELAN.Start(ThisPhase)*ms2s, 0, ...
                                    (ELAN.End(ThisPhase)-ELAN.Start(ThisPhase))*ms2s, 1]);
    set(Rect, 'FaceColor', Phase_color{ColorIndices(ThisPhase,1)}, ...
                'EdgeColor', 'None')
end



xlabel('WAV time [ms]')
% USV types organize
[USV_Categories,~,USV_CatIndex]=unique(USV.Type(:));    % 'bw', 'co', 'fc' etc.
% I wanna have fear call at the top, misc at the second, others are
% anti-alphabetical order
OldCategory=USV_Categories;
USV_Categories=flipud(USV_Categories);
FearCell = find(strcmp(USV_Categories,'fc'));
if isempty(FearCell)~=1 && FearCell~=1
    USV_Categories = ['fc'; USV_Categories(1:FearCell-1); USV_Categories(FearCell+1:end)];
end    
MiscCell = find(strcmp(USV_Categories,'mc'));
if ~isempty(MiscCell)
    if isempty(FearCell)
        if MiscCell~=1
            USV_Categories = ['mc';USV_Categories(1:MiscCell-1); USV_Categories(MiscCell+1:end)];
        end            
    else
        if MiscCell~=2
            USV_Categories = ['fc';'mc';USV_Categories(2:MiscCell-1); USV_Categories(MiscCell+1:end)];
        end
    end
end


NoOfCategories = length(USV_Categories);
for i=1:NoOfCategories
    switch USV_Categories{i}
        case 'tr'
            Ticks{i,1}='Trill';
        case 'sh'
            Ticks{i,1}='Short';
        case 'ru'
            Ticks{i,1}='Ramp up';
        case 'rd'
            Ticks{i,1}='Ramp down'; 
        case 'mt'
            Ticks{i,1}='M-Trill';
        case 'md'
            Ticks{i,1}='Modulated';
        case 'mc'
            Ticks{i,1}='Misc.';
        case 'fl'
            Ticks{i,1}='Flat';
        case 'fc'
            Ticks{i,1}='Fear (22 kHz)';
        case 'co'
            Ticks{i,1}='Combined';
        case 'bw'
            Ticks{i,1}='Bow';
        otherwise
            Ticks{i,1}=USV_Categories{i};
    end
            
end
% Plot USVs (normalized NLX time)
for i=1:size(USV.Start,1)
    for ThisType=1:NoOfCategories
      switch char(USV.Type(i))
       case char(USV_Categories(ThisType))
           % Option A: as thick as USV length
%         Rect=rectangle('Position',[USV.USV_Start_NLXtime_Norm(i),(ThisType-1)/NoOfCategories,USV.USV_End_NLXtime_Norm(i)-USV.USV_Start_NLXtime_Norm(i),1/NoOfCategories]);
           % Option B: as thick as hairline
%           Rect=rectangle('Position',[USV.USV_Start_NLXtime_Norm(i),(ThisType-1)/NoOfCategories,1,1/NoOfCategories]);
           % Option C: line
           Rect = line([USV.Start(i)*ms2s USV.Start(i)*ms2s], [(ThisType-1)/NoOfCategories (ThisType)/NoOfCategories]);
           set(Rect, 'Color', [0 0 0], 'LineWidth', 1)

%         set(Rect,'FaceColor',[0/255, 0/255, 0/255])   %black
%         set(Rect,'EdgeColor','None')
      end
    end
end

set(gca,'YLim',[0 1], 'YTick', 0.5/NoOfCategories:1/NoOfCategories:1, 'yticklabel',Ticks)
set(gca,'layer','top') % Axis and ticks in front of the other objects
title('USV')

% Legend
uniqIndices = unique(ColorIndices);
for ThisPhase = 1:length(uniqIndices)
    Legend_labels(ThisPhase,1) = Phase_type(uniqIndices(ThisPhase));
    Legend_plot(ThisPhase) = plot(nan, nan, 's', 'markerfacecolor', Phase_color{uniqIndices(ThisPhase)}, 'markeredgecolor', 'none');
end
legend(Legend_plot, Legend_labels, 'Location', 'SouthEastOutside');
hold off

% flip the categories for next graph
USV_Categories=flipud(USV_Categories);
Ticks=flipud(Ticks);
% Correct Category Indices
for i=1:length(USV_CatIndex)
    USV_CatIndex(i,1) = find(strcmp(USV_Categories,OldCategory(USV_CatIndex(i))));
end
USVcolor=[150/255, 167/255, 177/255];
% Plot USV types in another graph
% Bar = accumarray(USV_CatIndex, 1, [], @sum); % number of events
Bar = accumarray(USV_CatIndex, 100/length(USV_CatIndex), [], @sum); % fraction
figure
bar(Bar,'facecolor',USVcolor)
set(gca,'XTickLabel',Ticks)
% ylabel('Number of events')
ylabel('Frequency (%)')
% pie chart
figure
for i=1:length(Ticks)
    Ticks{i}=sprintf('%s \n(%.2f%%)', Ticks{i}, Bar(i));
end
pie(Bar,Ticks)
hold off
set(0,'DefaultFigureWindowStyle','normal')
% Cleaning
    clear db Hex_color ThisPhase Rect Bar ColorIndices FearCell i Legend_labels Legend_plot MiscCell NoOfCategories OldCategory Phase_color Phase_type ThisType Ticks uniqIndices
    clear USV_Categories USV_CatIndex USVcolor line ms2s