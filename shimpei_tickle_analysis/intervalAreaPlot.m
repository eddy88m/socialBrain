function intervalAreaPlot(starts,ends,begin,finish)
%{
plot filled stairstep from closed intervals
%}
if ~isnumeric(starts)
    error('starts must be numeric');
end
if ~isnumeric(ends)
    error('ends must be numeric');
end
if length(starts) ~= length(ends)
    error('starts and ends should be the same length');
end
if ~isnumeric(begin)
    error('begin must be numeric');
end
if ~isnumeric(finish)
    error('finish must be numeric');
end

starts = sort(starts);
ends = sort(ends);

[x,y] = intervalStairs(starts,ends,begin,finish);
[x,y] = stairs(x,y);
area(x,y,'FaceAlpha',0.5)

end