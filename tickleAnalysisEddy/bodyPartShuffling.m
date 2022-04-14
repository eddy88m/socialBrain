%
longTickling = input('long tickling?(1=yes, 0=no)')
% noFlipAndHand = input('no flip and hand?(1=yes, 0=no)')
noFlipAndBrush = input('no flip and brush?(1=yes, 0=no)')
flip = input('flip? (1=yes, 0=no)')
flipFair = input('flipFair? (1=yes, 0=no)')
%audio signal
Folder='N:\Git\tickleAnalysisEddy\audioFiles';
prepareTickling=audioread(fullfile(Folder,'prepare tickling.wav'));
start = audioread(fullfile(Folder,'start.wav'));
stop = audioread(fullfile(Folder,'stop.wav'));
areYouReady = audioread(fullfile(Folder,'are you ready.wav'));
Fs=44800/3;
if exist('ticklingSequence.mat')==2
      error('ticklingSequence already exists')
end
%%
if flip == 1
randTicklingSequence = randperm(13)

ventralAnterior = imread('ventral anterior.jpg'); % = 1 in the randTicklingSequence
ventralPosteriot = imread('ventral posterior.jpg');% = 2 in the randTicklingSequence
dorsalAnterior = imread('dorsal anterior.jpg');% = 3 in the randTicklingSequence
dorsalPosterior = imread('dorsal posterior.jpg');% = 4 in the randTicklingSequence
forepawVentral = imread('forepaw ventral.jpg');% = 5 in the randTicklingSequence
forepawDorsal = imread('forepaw dorsal.jpg');% = 6 in the randTicklingSequence
hindpawVentral = imread('hindpaw ventral.jpg');% = 7 in the randTicklingSequence
hindpawDorsal = imread('hindpaw dorsal.jpg');% = 8 in the randTicklingSequence
whiskers = imread('whiskers.jpg');% = 9 in the randTicklingSequence
tail = imread('tail.jpg');% = 10 in the randTicklingSequence
genital = imread('genital.jpg');% = 11 in the randTicklingSequence
ventralAnteriorInversed = imread('ventral anterior inversed.jpg'); % = 12 in the randTicklingSequence
trunkLateral = imread('trunkLateral.jpg');%18 in the randTicklingSequence (now 13 but change to 18 below for database)

imageSequence = {ventralAnterior ventralPosteriot dorsalAnterior dorsalPosterior forepawVentral forepawDorsal...
    hindpawVentral hindpawDorsal whiskers tail genital ventralAnteriorInversed trunkLateral};

figure('units','normalized','outerposition',[0 0 1 1])
for i = randTicklingSequence
imshow(imageSequence{i},'InitialMagnification','fit')
sound(areYouReady,Fs);
pause
sound(prepareTickling,Fs);
pause(10)
sound(start,Fs);
pause(10)
sound(stop,Fs);
pause
end


randTicklingSequence(randTicklingSequence==13) = 18;%have to change ID to 18 because this is how it is in the database
save('ticklingSequence.mat','randTicklingSequence')

end
%%
if noFlipAndBrush == 1
randTicklingSequence = randperm(10)

dorsalAnterior = imread('dorsal anterior.jpg');% = 3 in the randTicklingSequence (now 1, will be changed below)
dorsalPosterior = imread('dorsal posterior.jpg');% = 4 in the randTicklingSequence(now 2, will be changed below)
forepawVentral = imread('forepaw ventral.jpg');% = 5 in the randTicklingSequence(now 3, will be changed below)
forepawDorsal = imread('forepaw dorsal.jpg');% = 6 in the randTicklingSequence(now 4, will be changed below)
hindpawVentral = imread('hindpaw ventral.jpg');% = 7 in the randTicklingSequence(now 5, will be changed below)
hindpawDorsal = imread('hindpaw dorsal.jpg');% = 8 in the randTicklingSequence(now 6, will be changed below)
whiskers = imread('whiskers.jpg');% = 9 in the randTicklingSequence(now 7, will be changed below)
tail = imread('tail.jpg');% = 10 in the randTicklingSequence(now 8, will be changed below)
genital = imread('genital.jpg');% = 11 in the randTicklingSequence(now 9, will be changed below)
ventral = imread('ventral.jpg');%19 in the randTicklingSequence(now 10, will be changed below)

imageSequence = {dorsalAnterior dorsalPosterior forepawVentral forepawDorsal...
    hindpawVentral hindpawDorsal whiskers tail genital ventral};

figure('units','normalized','outerposition',[0 0 1 1])
for i = randTicklingSequence
imshow(imageSequence{i},'InitialMagnification','fit')
sound(areYouReady,Fs);
pause
sound(prepareTickling,Fs);
pause(5)
sound(start,Fs);
pause(10)
sound(stop,Fs);
pause
end

newvals = [3,4,5,6,7,8,9,10,11,19];
randTicklingSequence = newvals(randTicklingSequence);
save('ticklingSequence.mat','randTicklingSequence')

end
%%
if longTickling == 1
randTicklingSequence = randperm(11)

dorsalAnterior = imread('dorsal anterior.jpg');% = 3 in the randTicklingSequence (now 1, will be changed below)
dorsalPosterior = imread('dorsal posterior.jpg');% = 4 in the randTicklingSequence(now 2, will be changed below)
forepawVentral = imread('forepaw ventral.jpg');% = 5 in the randTicklingSequence(now 3, will be changed below)
forepawDorsal = imread('forepaw dorsal.jpg');% = 6 in the randTicklingSequence(now 4, will be changed below)
hindpawVentral = imread('hindpaw ventral.jpg');% = 7 in the randTicklingSequence(now 5, will be changed below)
hindpawDorsal = imread('hindpaw dorsal.jpg');% = 8 in the randTicklingSequence(now 6, will be changed below)
whiskers = imread('whiskers.jpg');% = 9 in the randTicklingSequence(now 7, will be changed below)
tail = imread('tail.jpg');% = 10 in the randTicklingSequence(now 8, will be changed below)
genital = imread('genital.jpg');% = 11 in the randTicklingSequence(now 9, will be changed below)
ventral = imread('ventral.jpg');%19 in the randTicklingSequence(now 10, will be changed below)
dorsalAnteriorNoArmHolding = imread('dorsal anterior - no arm holding.jpg');%21 in the randTicklingSequence(now 11, will be changed below)

imageSequence = {dorsalAnterior dorsalPosterior forepawVentral forepawDorsal ...
    hindpawVentral hindpawDorsal whiskers tail genital ventral dorsalAnteriorNoArmHolding};

figure('units','normalized','outerposition',[0 0 1 1])
for i = randTicklingSequence
imshow(imageSequence{i},'InitialMagnification','fit')
sound(areYouReady,Fs);
pause
sound(prepareTickling,Fs);
pause(5)
sound(start,Fs);
pause(10)
sound(stop,Fs);
pause
end

newvals = [3,4,5,6,7,8,9,10,11,19,21];
randTicklingSequence = newvals(randTicklingSequence);
save('ticklingSequence.mat','randTicklingSequence')


end

%%
if flipFair == 1
randTicklingSequence = randperm(14)

ventralAnterior = imread('ventral anterior.jpg'); % = 1 in the randTicklingSequence
ventralPosteriot = imread('ventral posterior.jpg');% = 2 in the randTicklingSequence
dorsalAnterior = imread('dorsal anterior.jpg');% = 3 in the randTicklingSequence
dorsalPosterior = imread('dorsal posterior.jpg');% = 4 in the randTicklingSequence
forepawVentral = imread('forepaw ventral.jpg');% = 5 in the randTicklingSequence
forepawDorsal = imread('forepaw dorsal.jpg');% = 6 in the randTicklingSequence
hindpawVentral = imread('hindpaw ventral.jpg');% = 7 in the randTicklingSequence
hindpawDorsal = imread('hindpaw dorsal.jpg');% = 8 in the randTicklingSequence
whiskers = imread('whiskers.jpg');% = 9 in the randTicklingSequence
tail = imread('tail.jpg');% = 10 in the randTicklingSequence
genital = imread('genital.jpg');% = 11 in the randTicklingSequence
ventralAnteriorInversed = imread('ventral anterior inversed.jpg'); % = 12 in the randTicklingSequence
trunkLateral = imread('trunkLateral.jpg');%18 in the randTicklingSequence (now 13 but change to 18 below for database)
ventralAnteriorFair = imread('ventral anterior fair.jpg');%19 in the randTicklingSequence (now 14 but change to 18 below for database)

imageSequence = {ventralAnterior ventralPosteriot dorsalAnterior dorsalPosterior forepawVentral forepawDorsal...
    hindpawVentral hindpawDorsal whiskers tail genital ventralAnteriorInversed trunkLateral ventralAnteriorFair};

figure('units','normalized','outerposition',[0 0 1 1])
for i = randTicklingSequence
imshow(imageSequence{i},'InitialMagnification','fit')
sound(areYouReady,Fs);
pause
sound(prepareTickling,Fs);
pause(10)
sound(start,Fs);
pause(10)
sound(stop,Fs);
pause
end


randTicklingSequence(randTicklingSequence==13) = 18;%have to change ID to 18 because this is how it is in the database
randTicklingSequence(randTicklingSequence==14) = 20;%have to change ID to 20 because this is how it is in the database

save('ticklingSequence.mat','randTicklingSequence')
end
%%
clear