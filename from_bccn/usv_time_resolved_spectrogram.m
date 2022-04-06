function [data] = usv_time_resolved_spectogram(audioTraceSingleUSVs, Fs)
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
% Author: Shimpei Ishiyama, 2018; adapted from Eduard Maier, 12/2019

y = audioTraceSingleUSVs;
fs = Fs;

% fft parameters
sample_per_sec = 50;%original:500 
window = hamming(sample_per_sec*2);
noverlap = round(sample_per_sec);
nfft = round(max(256,2^log2(sample_per_sec)));

[~,F,T,P] = spectrogram(y(:,1),window,noverlap,nfft,fs,'yaxis');
disp('Calculating spectrogram...')
data = 10*log10(P);

% yrange = [0 120000]; % in Hz


% % initialize axes
% fig = figure('Position', [100 500 1600 300], ...
%              'Color', 'white');
% 
% ax = subplot(1,1,1);
% set(gca,'color','none', ...
%         'box','off',...
%         'XColor', 'white',...
%         'YColor', 'white',...
%         'XTick', [],...
%         'YTick', [],...
%         'XTickLabel', [],...
%         'YTickLabel', []);
%     
%     % spectrogram for this frame
%         thisAx = axes('Position', ax.Position);
%        
%         surf(T,...
%             F, ...
%             data,...
%             'EdgeColor', 'none',...
%             'Parent', thisAx...
%             );
%         set(thisAx,'position',ax.Position,...
%                 'Color', 'none',...
%                 'XGrid', 'off',...
%                 'YGrid', 'off',...
%                 'ZGrid', 'off', ...
%                 'box', 'off',...
%                 'XColor', 'none',...
%                 'XTick', [],...
%                 'YTick', yrange(1):20000:yrange(2), ...
%                 'YTickLabel', yrange(1)/1000:20:yrange(2)/1000, ...
%                 'TickDir', 'out');
%         axis tight;
%        
        subplot(2,3,[1,2,3])
        imagesc(data); colormap(flipud(gray));
        caxis([-130 max(data(:))]);%contrast
        set(gca,'YDir','normal')
%         view(0,90);
        % set xlim
        
%         ylim(yrange);

end
