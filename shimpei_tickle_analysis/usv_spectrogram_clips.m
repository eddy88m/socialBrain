function usv_spectrogram_clips(starts,ends)
% Generate multiple spectrogram video clips from .wav file
% 
% ---DESCRIPTION---
% Modified version of usv_spectrogram.m
% Input: clip start times, clip end times (same length; in [s])
% Output: "clip01.mp4"...
%
% ---OPTIONS---
% Invert (default) makes white spectrogram on black background
% Highspeed makes 250 fps video. Default is 50 fps.
% Width [s] is the Xlim of the spectrogram
%
% Author: Shimpei Ishiyama, 2018

% error check
if length(starts) ~= length(ends)
    error('Length of starts and ends must be the same');
end
if sum(starts < ends) ~= length(starts)
    error('Starts must be smaller than Ends');
end

filename = uigetfile({'*.wav;*.WAV','Audio files (*.wav, *.WAV)'; '*.*', 'All files (*.*)'});
if filename==0
    return;
end
[y,fs] = audioread(filename);
if max(ends)>length(y)/fs
    error('Starts and Ends time must be smaller than duration of the audio');
end
% convert time to sample
starts = starts*fs;
ends = ends*fs;

% user input
[invert, highspeed, xwidth] = userInput();
% fft parameters
sample_per_sec = 500; 
window = hamming(sample_per_sec*2);
noverlap = round(sample_per_sec);
nfft = round(max(256,2^log2(sample_per_sec)));

yrange = [20000 100000]; % in Hz

% clip loop
for clip=1:length(starts)
    fprintf('### Clip %i ###\n', clip);
    [y,fs] = audioread(filename, [floor(starts(clip)) ceil(ends(clip))]);

    [~,F,T,P] = spectrogram(y,window,noverlap,nfft,fs,'yaxis');
    disp('Calculating spectrogram...')
    data = 10*log10(P);


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
    wb = waitbar(0, sprintf('1/%i',nframe),'Name', sprintf('Generating clip %i',clip), ...
                 'CreateCancelBtn', 'setappdata(gcbf,''canceling'',1)');
    setappdata(wb,'canceling',0);         
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
                if end_sample > length(T)
                    end_sample = length(T);
                end
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
            set(cursor,'Parent',thisAx,'XData',[T(end_sample) T(end_sample)]);

        % video frame
            vid_frames(frame) = getframe(gcf);

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

    % write video
    disp('Saving video...')
    videoname = regexprep(strrep(filename,'.',sprintf('_clip%02d.',clip)),'wav','mp4','ignorecase');
    video = VideoWriter(videoname, 'MPEG-4');
    video.FrameRate = fps;
    open(video);
    writeVideo(video, vid_frames);
    close(video);
    disp('Done!');
end
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