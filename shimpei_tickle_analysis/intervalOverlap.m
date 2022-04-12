function [overStarts,overEnds] = intervalOverlap(starts1,ends1,starts2,ends2)
%{
return overlapping intervals of 2 different intervals
required file: isUp.m
%}
if ~isnumeric(starts1)
    error('starts1 must be numeric');
end
if ~isnumeric(ends1)
    error('ends1 must be numeric');
end
if length(starts1) ~= length(ends1)
    error('starts1 and ends1 should be the same length');
end
if ~isnumeric(starts2)
    error('starts2 must be numeric');
end
if ~isnumeric(ends2)
    error('ends2 must be numeric');
end
if length(starts2) ~= length(ends2)
    error('starts2 and ends2 should be the same length');
end

% all event time points
t = unique([starts1;ends1;starts2;ends2]);

% overlap starts when both intervals become true
overStarts = t(isUp(starts1,ends1,t) & isUp(starts2,ends2,t));
% overlap ends at next time points
overEnds = t(arrayfun(@(x) find(t==overStarts(x)),1:length(overStarts))+1);


end