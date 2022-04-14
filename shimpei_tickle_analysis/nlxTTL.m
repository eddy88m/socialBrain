function TriggerTimeStamps = nlxTTL(varargin)
%{
    Dependency: MoritzNlx2MatEV
    Result in [s]
%}
    us2s = 1e-6;
    [TimeStamp,~,TTLs,~,Strings] = MoritzNlx2MatEV('Events.nev');
    
    % by default, read port 0
    port = 0;
    if ~isempty(varargin)
        if ~isnumeric(varargin{1})
            error('port number must be numeric')
        end
        port = varargin{1};
    end
    
    % new Digital Lynx SX
    TTLEvents = strncmp(cellstr(Strings), sprintf('TTL Input on AcqSystem1_0 board 0 port %i',port), 40);

    if sum(TTLEvents) == 0
        error('cannot find a TTL event')
    end
    
    TriggerTimeStamps = double(TimeStamp(TTLEvents' & TTLs)) * us2s;
    

end