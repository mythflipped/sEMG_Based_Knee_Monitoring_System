clc; clear;

% Initialize serial port
s = serialport('COM5', 115200);
flush(s);

% Parameters
numChannels = 6;      % Total number of channels
windowSize = 1000;    % Number of samples per RMS and MPF calculation
maxPoints = 20;       % Maximum number of points to display in the plot
Fs = 512;            % Sampling frequency in Hz

% Initialize data buffers
rmsHistory = nan(maxPoints, 4);  % RMS history for channels 1, 2, 5, 6
mpfHistory = nan(maxPoints, 4);  % MPF history for channels 1, 2, 5, 6
timeStamps = 1:maxPoints;        % X-axis for plots

% Set up the figure with two subplots
figure;

% Subplot for RMS
subplot(2,1,1);
hold on;
colors = {'r', 'g', 'b', 'k'};
markers = {'o', 's', 'd', '^'};
rmsHandles = gobjects(1, 4);
for i = 1:4
    rmsHandles(i) = scatter(nan, nan, 50, colors{i}, markers{i}, 'filled');
end
legend('CH1', 'CH2', 'CH5', 'CH6');
xlabel('Rolling Window Index (Latest → Oldest)');
ylabel('RMS Value');
title('Real-Time RMS (Sliding Window)');
xlim([0.5, maxPoints+0.5]);
ylim([0, 150]);
grid on;
set(gca, 'XTick', 1:maxPoints);

% Subplot for MPF
subplot(2,1,2);
hold on;
mpfHandles = gobjects(1, 4);
for i = 1:4
    mpfHandles(i) = scatter(nan, nan, 50, colors{i}, markers{i}, 'filled');
end
legend('CH1', 'CH2', 'CH5', 'CH6');
xlabel('Rolling Window Index (Latest → Oldest)');
ylabel('MPF (Hz)');
title('Real-Time Mean Power Frequency (Sliding Window)');
xlim([0.5, maxPoints+0.5]);
ylim([0, Fs/2]);  % MPF ranges from 0 to Nyquist frequency
grid on;
set(gca, 'XTick', 1:maxPoints);

% Data Acquisition Cycle
sampleCount = 0;
dataBuffer = zeros(windowSize, numChannels);

while true
    % Collect 1000 samples
    while sampleCount < windowSize
        if s.NumBytesAvailable > 0
            try
                rawData = readline(s);
                dataStr = strsplit(strtrim(rawData), ',');
                
                if length(dataStr) == numChannels
                    sampleCount = sampleCount + 1;
                    dataBuffer(sampleCount, :) = str2double(dataStr);
                end
            catch
                continue;
            end
        end
    end
    
    % Calculate RMS for all channels
    rmsValues = sqrt(mean(dataBuffer.^2, 1));
    
    % Calculate MPF for channels 1, 2, 5, 6
    mpfValues = zeros(1, 4);
    channelIndices = [1, 2, 5, 6];
    for i = 1:4
        channelData = dataBuffer(:, channelIndices(i));
        [pxx, f] = periodogram(channelData, [], [], Fs);
        mpfValues(i) = meanfreq(pxx, f);
    end
    
    % Update data buffers
    rmsHistory = [rmsHistory(2:end, :); rmsValues(channelIndices)];
    mpfHistory = [mpfHistory(2:end, :); mpfValues];
    
    % Update scatter plots
    for i = 1:4
        set(rmsHandles(i), 'XData', timeStamps, 'YData', rmsHistory(:, i));
        set(mpfHandles(i), 'XData', timeStamps, 'YData', mpfHistory(:, i));
    end
    
    % Reset sample count
    sampleCount = 0;
    drawnow limitrate;
end
