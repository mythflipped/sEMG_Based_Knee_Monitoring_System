% Read your data
filename = 'Test_File.csv';  % Replace with your actual filename
data = readmatrix(filename);

% Preallocate array to store RMS values
numChannels = size(data, 2);
rms_values = zeros(1, numChannels);

% Compute RMS for each channel
for ch = 1:numChannels
    signal = data(:, ch);
    rms_values(ch) = sqrt(mean(signal.^2));
end

% Display the RMS values
for ch = 1:numChannels
    fprintf('RMS of CH%d: %.2f\n', ch, rms_values(ch));
end
