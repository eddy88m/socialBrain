function multiStairs(starts,ends,phases,varargin)
%{
Stairstep chart for multiple categories.
y-axis is unique(phases)
Useful for checking event overview
%}
 
p = inputParser;
zeroStart = false;
ms2s = false;
addRequired(p,'starts',@isnumeric);
addRequired(p,'ends',@isnumeric);
addRequired(p,'phases',@iscellstr);
addOptional(p,'zeroStart',zeroStart,@islogical);
addOptional(p,'ms2s',ms2s,@islogical);
parse(p,starts,ends,phases,varargin{:})
zeroStart = p.Results.zeroStart;
ms2s = p.Results.ms2s;

if zeroStart
    startAt = min(starts);
    starts = starts - startAt;
    ends = ends - startAt;
end
if ms2s
    ms2s = 1e-3;
    starts = starts*ms2s;
    ends = ends*ms2s;
end

height = 0.8;
figure;
axPhase = subplot(1,1,1);
hold on

unq = flip(unique(phases,'stable'));
for p = 1:length(unq)
    x = [min(starts);sort([starts(strcmp(phases,unq(p)));ends(strcmp(phases,unq(p)))]);max(ends)];
    y = vertcat(0, repmat([1;0], length(starts(strcmp(phases,unq(p)))),1), 0);
    stairs(x,y*height+p,'k','Parent',axPhase);
end

axPhase.YTick = 1:length(unq);
axPhase.YTickLabel = unq;
axPhase.YLim = [0 length(unq)+1];
axPhase.YLimMode = 'manual';
axPhase.TickDir = 'out';

end