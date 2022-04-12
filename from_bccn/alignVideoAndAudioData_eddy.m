% get video ttl
[filenamevTTL,path] = uigetfile('*.avi','Select video file');
LEDtrace = [];
v = VideoReader(filenamevTTL);
k = 1;
knowCoordinates = input('do you know the coordinates? (1 = yes, 0 = no)');    
while hasFrame(v)
    video = readFrame(v);
    if knowCoordinates == 1
    x = 72; %input coordinates here if you know
    y = 109;%input coordinates here if you know
    LEDtrace(k) =  video(round(y),round(x));  
    k=k+1;
    else
    if k == 1
        imshow(video)
        hold on
        [x,y] = ginput(1);
        plot(round(x),round(y),'r.')
    end
    LEDtrace(k) =  video(round(y),round(x));  
    k=k+1;
%     if k > 1000
%         break
%     end
    end
end
vTTL_Frames = find(diff(LEDtrace)>100);
vTTL = vTTL_Frames/v.FrameRate; %s
% get audio ttl 
[aTTLTable] = audioTTL()
aTTL = aTTLTable.TTL_Up_in_s;
% [filenameATTL,path] = uigetfile('*.txt','Select audioTTL.txt file');
% aTTLTable = readtable(filenameATTL);
% aTTL = table2array(aTTLTable(:,1))';%s
audibleUSV()
[filename,path] = uigetfile('*.wav','Select ultrasound wav file');
filepath = [path,filename];
[aValues,Fs] = audioread(filepath,'double');
%% Align and normalize audio values to video time
%check if start and end TTLs are correct in vTTL (for this script start ttl
%is always ok but there might be too many end TTLs
TTLdifference = aTTL (1) - vTTL(1)
TTLEndDifference = aTTL(end) - vTTL(end)
TTLsOk = input('are start and end TTLs meaningful? (1 = yes, 0 = no)')
if TTLsOk == 0
    findMinVector = aTTL(end)-TTLdifference - vTTL;
    vTTL = vTTL(1:find(abs(findMinVector) == min(abs(findMinVector))));
end

if TTLdifference > 0 %if video starts after audio the aligned audio start value is searched
alignedAValues = aValues(TTLdifference*Fs : end);
slope = round((aTTL(end) - aTTL(1)) / (vTTL(end) - vTTL(1)),3);
splt = regexp(num2str(slope), '\.', 'split');
if length(splt) == 1
    slopeNoDcmls = slope;
    nrOfdcmls = 0;
else
nrOfdcmls = length(splt{2});
slopeNoDcmls = slope*10^nrOfdcmls;
end
correctedAValues = resample(alignedAValues,1*round(10^nrOfdcmls),round(slopeNoDcmls));
else % if video starts before audio values have to be added to audio (add just zeros at the beginning)
valuesToBeAdded = zeros(1,TTLdifference*Fs);
alignedAValues = [valuesToBeAdded aValues];
slope = round((aTTL(end) - aTTL(1)) / (vTTL(end) - vTTL(1)),3);
splt = regexp(num2str(slope), '\.', 'split');
if length(splt) == 1
    slopeNoDcmls = slope;
    nrOfdcmls = 0;
else
nrOfdcmls = length(splt{2});
slopeNoDcmls = slope*10^nrOfdcmls;
end
correctedAValues = resample(alignedAValues,1*round(10^nrOfdcmls),round(slopeNoDcmls));
end
audiowrite('correctedAudible.wav',correctedAValues,Fs)
