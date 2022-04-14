function [breakStarts,breakEnds] = intervalBreak(starts,ends)
    % input intervals can be overlapped
    if size(starts)~=size(ends)
        error('starts and ends should be the same length')
    end

    % sort by start time
    [starts,sortIdx] = sort(starts);
    ends = ends(sortIdx);
    
    breakStarts = [];
    breakEnds = [];
    this = 1;
    next = this + 1;
    
    while next < length(starts)
        if ends(next) <= ends(this)
            next = next + 1;
            continue
        elseif starts(next) <= ends(this)
            this = next;
            next = next + 1;
            continue
        elseif starts(next) > ends(this)
            breakStarts(end+1,1) = ends(this);
            breakEnds(end+1,1) = starts(next);
            this = next;
            next = this + 1;        
            continue
        end
        
    end
    

end