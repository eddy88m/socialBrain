function audibleUSV()

[filename,path] = uigetfile('*.wav','Select ultrasound wav file');
if ~filename
    return
end
filepath = [path,filename];

rFs = 8000;
[y,Fs] = audioread(filepath,'double');
ry = resample(y,rFs,Fs,0);
f = soundview(ry,rFs);
try
    uiwait
catch
end

toSave = questdlg('Save as file?');
switch toSave
    case 'Cancel'
        return
    case 'No'
        return
end

defNewFilepath = [filepath(1:strfind(lower(filepath),'.wav')-1),'_audible.wav'];
[newFileName,newFilePath] = uiputfile(defNewFilepath);
newFilePath = [newFilePath,newFileName];
audiowrite(newFilePath,ry,rFs)


end
