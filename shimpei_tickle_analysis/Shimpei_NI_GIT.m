function mydaq=Shimpei_NI_GIT
    % for NI PCI-6220 card
    % NI DAQmx (including the driver and the control software MAX) must be
    % installed, and then the card must be installed

    % Vendor ID is 'ni', device ID is 'Dev1'
    mydaq = daq.createSession('ni');
    % In MAX: Test Panels: Digital I/O, channels (e.g. port0/line0-7 must be
    % configured as output/input

    % Add three digital channels
    sound=mydaq.addDigitalChannel('Dev1','port0/line0','OutputOnly');
    sound.Name='light';
    
    
    % port0/line1 is reserved for Master-8
%     neuralynx=mydaq.addDigitalChannel('Dev1','port0/line1','OutputOnly');
%     neuralynx.Name='neuralynx';
    % port0/line2 is free
%     LED=mydaq.addDigitalChannel('Dev1','port0/line2','OutputOnly');
%     LED.Name='LED';

    outputSingleScan(mydaq,[0])
    disp 'Bright light: off'
end