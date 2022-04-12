function CheckIFI()
FrameFile = uigetfile(...
                    {'*.csv?','csv files (*.csv)'; ...
                     '*.*',  'All Files (*.*)'}, ...
                     'Select frame file', 'MultiSelect', 'off');
if ~FrameFile
    warning('User cancelled');
    return;
end

display(FrameFile)
Table = csvread(FrameFile, 1);
FrameTime = Table(:,2); % in [ms]

% start from 0 ms
FrameTime = FrameTime - FrameTime(1);
IFI = diff(FrameTime);

thresholdIFI = 50; %[ms]
ms2sec = 1e-3;

DropFrames = find(IFI > thresholdIFI);
if isempty(DropFrames)
    display(sprintf('No frames with IFI>%i [ms]',thresholdIFI));
    set(0,'DefaultFigureWindowStyle','docked')
    bar(IFI)
    xlabel('Frame #')
    ylabel('Inter frame interval [ms]')
    set(0,'DefaultFigureWindowStyle','normal')
    return
end
DropFrameTimes = FrameTime(DropFrames)*ms2sec;
% DropFrameTimesHMS = char(length(DropFrameTimes),1);
for frame=1:length(DropFrameTimes)
    DropFrameTimesHMS{frame}=sec2hms(DropFrameTimes(frame));
end
DropFrameTimesHMS=char(DropFrameTimesHMS);

display(sprintf('\rMedian IFI = %.3f [ms]', median(IFI)));
display(sprintf('Max IFI = %.3f [ms]', max(IFI)));
display(sprintf('Min IFI = %.3f [ms]', min(IFI)));
display(sprintf('\r%i Frames with IFI > %i [ms]:', length(DropFrames), thresholdIFI));
display(DropFrames)
display('Corresponding times')
display(DropFrameTimesHMS)

set(0,'DefaultFigureWindowStyle','docked')
bar(IFI)
xlabel('Frame #')
ylabel('Inter frame interval [ms]')
set(0,'DefaultFigureWindowStyle','normal')


end