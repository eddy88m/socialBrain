% Playback a video, and send TTL to Avisoft device to start USV playback.
% IR-LED is shared with bright light LED. For non-anxiogenic conditions,
% plug off the power of the lights.


clear mydaq video_path video_name;
[video_name, video_path, ~] = uigetfile('*.mp4', 'Select a video file to play.');
if video_name == 0
    return
end
video_path = fullfile(video_path, video_name);
if exist(video_path,'file') ~= 2
    error('Unable to open file ''%s''.', video_path);
end

% start daq session
mydaq = daq.createSession('ni');
LED = mydaq.addDigitalChannel('Dev1','port0/line0','OutputOnly');
LED.Name = 'LED';
USV=mydaq.addDigitalChannel('Dev1','port0/line1','OutputOnly');
USV.Name='USV';
   
outputSingleScan(mydaq,[1 1]);
pause(1)
outputSingleScan(mydaq,[1 0]);

[status, result] = system(sprintf(['vlc --qt-start-minimized --fullscreen --video-x=1800 ', ...
' --video-y=100 --no-embedded-video --no-video-title-show --qt-fullscreen-screen ', ...
'number=2 --play-and-exit file:///%s'], video_path));

    
outputSingleScan(mydaq,[0 0]);
daq.reset
clear
% quit with Ctrl+Q