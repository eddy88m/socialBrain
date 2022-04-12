function result = isUp(starts,ends,t)
%{
returns if a logical interval at time t is true
arguments
- starts: start of interval
- ends: end of interval
- t: given times
%}
if ~isnumeric(starts)
    error('starts must be numeric');
end
if ~isnumeric(ends)
    error('ends must be numeric');
end
if ~isnumeric(t)
    error('t must be numeric');
end
if length(starts) ~= length(ends)
    error('starts and ends should be the same length');
end

result = sum(starts <= t' & t' < ends,1);

end