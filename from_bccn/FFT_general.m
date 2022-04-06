%LFP
[filename,path]=uigetfile('*.mat', 'Select wav file', 'MultiSelect', 'on');
load filename
% Trace and Interval has to be inputted
trace = traceValues;
Fs = 1/samplingInterval;
% FFT
% LFP = BandPassFilteredTraces(1:10000000);
L = length(trace);
f = Fs*(0:(L/2))/L;
Y = fft(trace);
P2 = abs(Y/L);
P1 = P2(1:L/2+1);
P1(2:end-1) = 2*P1(2:end-1);
figure;plot(f,P1)
xlim([0 100])

