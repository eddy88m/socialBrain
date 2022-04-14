function customPSTH()
% customPSTH() generates a PSTH of spike or USV which user can input mySQL
% query
[what2plot, binWidth, phaseQuery, etcQuery, usvQuery] = userInput();

disp(what2plot)
disp(binWidth)
disp(phaseQuery)
disp(etcQuery)
disp(usvQuery)




end

function [what2plot, binWidth, phaseQuery, etcQuery, usvQuery] = userInput()


d = dialog('Position', [500 200 300 300], 'Name', 'Custom PSTH');
    txt_type = uicontrol('Parent', d, ...
                    'Style', 'text', ...
                    'Position', [25 250 150 40], ...
                    'HorizontalAlignment', 'Left', ...
                    'String', 'What to plot:');
    popup = uicontrol('Parent', d, ...
                    'Style', 'popup', ...
                    'Position', [25 250 150 25], ...
                    'HorizontalAlignment', 'Left', ...
                    'String', {'Spike'; 'USV'}, ...
                    'Callback', @popup_callback);
    txt_bin_title = uicontrol('Parent', d, ...
                    'Style', 'text', ...
                    'Position', [180 250 150 40], ...
                    'HorizontalAlignment', 'Left', ...
                    'String', 'Bin width [s]:');
    binTxt = uicontrol('Parent', d, ...
                    'Style', 'edit', ...
                    'String', '0.5', ...
                    'Position', [180 255 50 20], ...
                    'Tag', 'bin',...
                    'Callback', @txt_callback);
    phaseTxt = uicontrol('Parent',d,...
                    'Style', 'edit', ...
                    'String', 'Phase Query', ...
                    'Position', [25 190 250 60],...
                    'Tag', 'phase',...
                    'Max', 2, ...
                    'Callback', @txt_callback);
    etcTxt = uicontrol('Parent',d,...
                    'Style', 'edit', ...
                    'String', 'ETC Query', ...
                    'Position', [25 130 250 60],...
                    'Tag', 'etc',...
                    'Max', 2, ...
                    'Callback', @txt_callback);
    usvTxt = uicontrol('Parent',d,...
                    'Style', 'edit', ...
                    'String', 'USV Query', ...
                    'Position', [25 70 250 60],...
                    'Tag', 'usv',...
                    'Max', 2, ...
                    'Callback', @txt_callback);
                    
    OKbtn = uicontrol('Parent', d, ...
                    'Position', [115 20 70 25], ...
                    'String', 'OK', ...
                    'Callback', 'delete(gcf)');
    % default
    what2plot = lower('Spike'); 
    binWidth = 0.5,
    phaseQuery = '';
    etcQuery = '';
    usvQuery = '';
    
    uiwait(d);
    
    function popup_callback(popup, event)
        idx = popup.Value;
        popup_items = popup.String;
        what2plot = lower(char(popup_items(idx, :)));
    end

    function txt_callback(handle, event)
        switch get(handle, 'Tag')
            case 'bin'
                binWidth = str2num(get(handle, 'String'));
            case 'phase'
                phaseQuery = get(handle, 'String');
            case 'etc'
                etcQuery = get(handle, 'String');
            case 'usv'
                usvQuery = get(handle, 'String');
        end
    end
    
    

end