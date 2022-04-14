function spikeMIDI(spike_time)
% required files http://kenschutte.com/midi

% spike_time in ms
start_time = spike_time;
start_time = start_time / 1000;
end_time = start_time + 0.1;
midi_info(:,1) = ones(length(start_time),1); % track number
midi_info(:,2) = ones(length(start_time),1); % channel number
midi_info(:,3) = ones(length(start_time),1)*60; % note (60 = C3)
midi_info(:,4) = ones(length(start_time),1)*100; % velocity (1-127)
midi_info(:,5) = start_time; % note on in s
midi_info(:,6) = end_time; % note off in s 
midi_info(:,7) = ones(length(start_time),1); % message number of note on
midi_info(:,8) = ones(length(start_time),1); % message number of note off
spikeMIDI = matrix2midi(midi_info);
writemidi(spikeMIDI,'spikes.mid');
end