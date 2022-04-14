function usv_spectrogram()
% Generate spectrogram video
% 
% ---DESCRIPTION---
% Read a .wav file and stream spectrogram (20-100 kHz) along with a red
% cursor as in Avisoft RECORDER, saving .mp4 video.
% The resulting video is supposed to be superimposed on behavioral video
% footage after some beautification in AE.
%
% ---OPTIONS---
% Invert (default) makes white spectrogram on black background
% Highspeed makes 250 fps video. Default is 50 fps.
% Width [s] is the Xlim of the spectrogram
%
% Author: Shimpei Ishiyama, 2018


filename = uigetfile({'*.wav;*.WAV','Audio files (*.wav, *.WAV)'; '*.*', 'All files (*.*)'});
if filename==0
    return;
end
[y,fs] = audioread(filename);

% user input
[invert, highspeed, xwidth] = userInput();


% fft parameters
sample_per_sec = 500; 
window = hamming(sample_per_sec*2);
noverlap = round(sample_per_sec);
nfft = round(max(256,2^log2(sample_per_sec)));

[~,F,T,P] = spectrogram(y,window,noverlap,nfft,fs,'yaxis');
disp('Calculating spectrogram...')
data = 10*log10(P);

yrange = [20000 100000]; % in Hz


% initialize axes
fig = figure('Position', [100 500 1600 300], ...
             'Color', 'white');
if invert
    set(fig, 'Color','black');
end
ax = subplot(1,1,1);
set(gca,'color','none', ...
        'box','off',...
        'XColor', 'white',...
        'YColor', 'white',...
        'XTick', [],...
        'YTick', [],...
        'XTickLabel', [],...
        'YTickLabel', []);
if invert
    set(ax, 'XColor', 'black', 'YColor', 'black');
end
    

% graph animation
if highspeed
    fps = 250;
else
    fps = 50; % of video
end
dur = length(y)/fs;
nframe = floor(dur*fps);
% nframe = floor(4*fps); % for debugging
sample_per_frame = round(sample_per_sec/fps);
cursor = line([0 0], yrange, 'Color','r','LineWidth',2);
disp('Generating video...');
wb = waitbar(0, sprintf('1/%i',nframe),'Name', 'Generating video', ...
             'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1)');
setappdata(wb,'canceling',0);

video = VideoWriter(regexprep(filename,'wav','mp4','ignorecase'), 'MPEG-4');
video.FrameRate = fps;
open(video);

for frame = 1:nframe
    
    % waitbar
        if getappdata(wb, 'canceling')
            delete(wb);
            close(fig);
            return
        end
        waitbar(frame/nframe, wb, sprintf('%i/%i',frame, nframe));
    % spectrogram for this frame
        thisAx = axes('Position', ax.Position);
        if frame==1
            start_sample = sample_per_frame*(frame-1)+1; % to avoid index 0
            end_sample = sample_per_frame*frame;
        else
            start_sample = sample_per_frame*(frame-1); % 1 frame before to fill the 'gap'
            end_sample = sample_per_frame*frame;
        end
        surf(T(start_sample:end_sample),...
            F, ...
            data(:,start_sample:end_sample),...
            'EdgeColor', 'none',...
            'Parent', thisAx...
            );
        set(thisAx,'position',ax.Position,...
                'Color', 'none',...
                'XGrid', 'off',...
                'YGrid', 'off',...
                'ZGrid', 'off', ...
                'box', 'off',...
                'XColor', 'none',...
                'XTick', [],...
                'YTick', yrange(1):20000:yrange(2), ...
                'YTickLabel', yrange(1)/1000:20:yrange(2)/1000, ...
                'TickDir', 'out');
        axis tight;
        if invert
            set(thisAx, 'YColor','white');
            colormap(gray);
        else
            colormap(flipud(gray));
        end
        % set contrast
        caxis([-110 max(data(:))])
        view(0,90);
        % set xlim
        xlim([floor(frame/(fps*xwidth))*xwidth floor(frame/(fps*xwidth))*xwidth+xwidth]);
        ylim(yrange);
        
    
    % cursor for this frame
        set(cursor,'Parent',thisAx,'XData',[T(sample_per_frame*frame) T(sample_per_frame*frame)]);
    
    % write frame
    writeVideo(video, getframe(gcf));
    
    % delete old axes for process speed
        % delete on each sweep (faster)
        if frame>fps*xwidth && mod(frame,fps*xwidth)==0
            axlist = findall(gcf,'type','axes'); % last one is ax, don't delete
            delete(axlist(fps*xwidth+1:fps*xwidth*xwidth));
        end
        % delete on each frame
%         if frame>fps*xwidth % after one sweep
%            axlist = findall(gcf, 'type', 'axes'); % lasat one is ax, don't delete
%            delete(axlist(end-1));
%         end

end
delete(wb);
close(fig);

close(video);
disp('Done!');
end

function [invert, highspeed, xwidth] = userInput()
    d = dialog('Position', [500 500 200 150], 'Name', 'USV Spectrogram');
    checkbox = uitable('Parent', d...
                       , 'ColumnFormat', {'logical', 'char'}...
                       , 'ColumnWidth', {15, 135}...
                       , 'ColumnEditable', [true, false]...
                       , 'Position', [25 90 160 40]...
                       , 'Units', 'norm'...
                       , 'ColumnName', []...
                       , 'RowName', []...
                       , 'Data', {true 'Invert color'...
                                ; false 'Highspeed (250 fps)'...
                       }...
                       , 'TooltipString', sprintf(['Invert color results in black background. '...
                                                 , 'Default 50fps, Highspeed 250fps'...
                                                 ])...
                       , 'CellEditCallback', @checkbox_callback...
    );
    txt = uicontrol('Parent', d...
                       , 'Style', 'text'...
                       , 'Position', [25 50 130 20]...
                       , 'HorizontalAlignment', 'Left'...
                       , 'String', 'Width [s]: '...
    );
    invert = true;
    highspeed = false;
    xwidth = 2;
    txtbox = uicontrol('Parent', d...
                       , 'Style', 'edit'...
                       , 'Position', [150 52 40 20]...
                       , 'String', num2str(xwidth)...
                       , 'callback', @txt_callback...
    );
    OKbtn = uicontrol('Parent', d...
                       , 'Position', [115 20 70 25]...
                       , 'String', 'OK'...
                       , 'Callback', 'delete(gcf)'...
    );
    uiwait(d);
    function checkbox_callback(obj, callbackdata)
        tableData = get(obj, 'Data');
        checkboxData = cell2mat(tableData(:,1));
        invert = checkboxData(1);
        highspeed = checkboxData(2);
    end
    function txt_callback(obj, callbackdata)
        xwidth = str2double(obj.String);
    end
end