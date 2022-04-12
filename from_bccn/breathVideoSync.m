%%%HUMAN TICKLING
%% breathing data
[filenameBreath,path]=uigetfile('*.mat', 'Select wav file', 'MultiSelect', 'on');
% filenameBreath = 'SES_1809050102.mat'
load(filenameBreath)
samplingFrequency = 50000;%Hz
breathingTrace = Adc5.values;
if exist
FilteredTracesBreathing = butterworth_humanBreath(filenameBreath);
time = 1/samplingFrequency:1/samplingFrequency:length(breathingTrace)/samplingFrequency;%s
time_ms = time*1000;
load videoTTL.txt
videoTTLs = videoTTL;
load touchOnsets.txt
breathingTTLs = time(2*samplingFrequency):time(5*samplingFrequency):time((5*length(videoTTLs)-2)*samplingFrequency);%should be inputted, here I know from patchmaster protocol


%% Align and normalize video & USV time to audio time
% Plot video vs. audio
figure;
subplot(1,2,1);
line([0 videoTTLs'], [0 videoTTLs'],'Color','red');
hold on
scatter(videoTTLs,breathingTTLs,'k');
hold off
xlabel('Video TTL start time [s]')
ylabel('breathing TTL start time [s]')
legend('X=Y', 'TTL','Location','northwest')
% Normalize
% If ELAN times are on y axis, then y intercept has to be substracted from ELAN times.
% If ELAN times are on x axis, then x intercept has to be substracted from ELAN times.
% It is important, that first intercept has to be substracted and
% AFTERWARDS slope multiplication!
slope = (breathingTTLs(end) - breathingTTLs(1)) / (videoTTLs(end)-...
    videoTTLs(1));
y_intercept = breathingTTLs(1)-slope*videoTTLs(1);
x_intercept = -y_intercept/slope;
videoTTLs = videoTTLs - x_intercept;
touchOnsets = touchOnsets - x_intercept;
videoDur = videoTTLs(end) - videoTTLs(1);
breathingDur = breathingTTLs(end) - breathingTTLs(1);
videoError = breathingDur - videoDur;
videoTTLs = videoTTLs * slope;
touchOnsets = touchOnsets * slope;
% Plot video vs. audio
subplot(1,2,2);
line([0 videoTTLs'], [0 videoTTLs'],'Color','red');
hold on
scatter(videoTTLs,breathingTTLs,'k');
hold off
xlabel('Video TTL start time [s]')
ylabel('breathing TTL start time [s]')
legend('X=Y', 'TTL','Location','northwest')
linfit = fitlm(videoTTLs,breathingTTLs);
R2 = linfit.Rsquared.Ordinary;
title(strcat('Post-Normalization: R-squared = ', num2str(R2)));
savefig('syncTest.fig')

% everything in ms
s2ms = 1e3;
videoTTLs_ms = videoTTLs * s2ms;
videoError = videoError * s2ms;
breathingTTLs_ms = breathingTTLs * s2ms;
touchOnsets_ms = touchOnsets *1000;

%% Touch-triggered breathing-average

analysisStartBeforeTouchOnset_ms = 2000;
analysisEndAfterTouchOnset_ms = 2000;
touchTriggeredBreathing = zeros(length(touchOnsets_ms),(analysisStartBeforeTouchOnset_ms+analysisEndAfterTouchOnset_ms)/1000*samplingFrequency);
for i = 1:length(touchOnsets_ms)
touchTriggeredBreathingCur = FilteredTracesBreathing(find(time_ms >= touchOnsets_ms(i)-analysisStartBeforeTouchOnset_ms &...
    time_ms < touchOnsets_ms(i) + analysisEndAfterTouchOnset_ms));
touchTriggeredBreathing(i,:) = touchTriggeredBreathingCur;
end

figure('units','normalized','outerposition',[0 0 1 1])
subplot(1,2,1)
plot(-analysisStartBeforeTouchOnset_ms/1000:1/samplingFrequency:(analysisEndAfterTouchOnset_ms/1000)-1/samplingFrequency,touchTriggeredBreathing')
xlabel('time from touch onset (s)')
ylabel('<-- exhale     inhale-->')
title('all triggered touches')
subplot(1,2,2)
plot(-analysisStartBeforeTouchOnset_ms/1000:1/samplingFrequency:(analysisEndAfterTouchOnset_ms/1000)-1/samplingFrequency,mean(touchTriggeredBreathing))
xlabel('time from touch onset (s)')
ylabel('<-- exhale     inhale -->')
title('touch triggered average')
savefig('touchTriggeredAverage.fig')
figure('units','normalized','outerposition',[0 0 1 1])
plot(time,FilteredTracesBreathing)
xlabel('time (s)')
hold on
plot(touchOnsets_ms/1000,0,'r.')
savefig('breathingTraceWithTouches')


%% derivative
h = 0.001;       % step size
derivTimeDomain = 1:1/h:length(breathingTrace);
touchTriggeredBreathing(derivTimeDomain)'
subplot(1,2,1)
plot(-analysisStartBeforeTouchOnset_ms/1000:1/samplingFrequency:(analysisEndAfterTouchOnset_ms/1000)-2/samplingFrequency,diff(touchTriggeredBreathing'))
xlabel('time from touch onset (s)')
ylabel('<-- exhale     inhale-->')
title('all triggered touches')
subplot(1,2,2)
plot(-analysisStartBeforeTouchOnset_ms/1000:1/samplingFrequency:(analysisEndAfterTouchOnset_ms/1000)-2/samplingFrequency,diff(mean(touchTriggeredBreathing)))
xlabel('time from touch onset (s)')
ylabel('<-- exhale     inhale -->')
title('touch triggered average')



%% save variables

