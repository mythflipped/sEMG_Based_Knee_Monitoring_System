% clear
clc; clear;

% Initialize serial port
s = serialport('COM5', 115200);
flush(s);

% Parameters
numChannels = 6;              % Number of channels
windowSize = 1000;            % Samples per window
Fs = 512;                    % Sampling frequency
maxPoints = 20;               % Display last 20 windows
threshold_SI = 15;            % Imbalance threshold (%)
threshold_MPF_slope = -1;     % Fatigue threshold (Hz/s)

% Initialize data buffers
rmsHistory = nan(maxPoints, 4);  % CH1, CH2, CH5, CH6
mpfHistory = nan(maxPoints, 4);
timeStamps = 1:maxPoints;         % X-axis labels

% Initialize figure
figure('Position', [100 100 800 600]);

% Subplot 1: RMS Values
subplot(2,1,1);
hold on;
rmsPlots = gobjects(4);
colors = {'r', 'g', 'b', 'k'};
labels = {'CH1 (Left)', 'CH2 (Right)', 'CH5 (Left)', 'CH6 (Right)'};
for i = 1:4
    rmsPlots(i) = plot(nan, nan, 'Color', colors{i},...
        'LineWidth', 1.5, 'Marker', 'o', 'MarkerSize', 4);
end
title('Real-Time RMS Monitoring');
xlabel('Window Index (Rolling 20)');
ylabel('RMS (μV)');
xlim([0.5, maxPoints+0.5]);
ylim([0 200]);
grid on;
legend(labels, 'Location', 'northwest');

% Subplot 2: MPF Values
subplot(2,1,2);
hold on;
mpfPlots = gobjects(4);
for i = 1:4
    mpfPlots(i) = plot(nan, nan, 'Color', colors{i},...
        'LineWidth', 1.5, 'Marker', 's', 'MarkerSize', 4);
end
title('Real-Time Mean Power Frequency (MPF)');
xlabel('Window Index (Rolling 20)');
ylabel('MPF (Hz)');
xlim([0.5, maxPoints+0.5]);
ylim([0 10]);
grid on;
legend(labels, 'Location', 'northwest');

% Fatigue detection buffers
mpf_buffer = zeros(5,4);      % Store last 5 MPF values
time_buffer = NaT(1,5);       % Store timestamps

% Main loop
while true
    % --- Data Acquisition ---
    dataBuffer = zeros(windowSize, numChannels);
    sampleCount = 0;
    
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
    
    % --- Signal Processing ---
    % 1. Compute RMS
    rmsValues = sqrt(mean(dataBuffer.^2, 1));
    
    % 2. Compute MPF using Welch's method
    channelIndices = [1 2 5 6];
    mpfValues = zeros(1,4);
    for i = 1:4
        [pxx, f] = pwelch(dataBuffer(:, channelIndices(i)),...
                     hann(256), 128, [], Fs);
        mpfValues(i) = sum(f.*pxx)/sum(pxx);
    end
    
    % --- Update Buffers ---
    % Rolling buffer update
    rmsHistory = [rmsHistory(2:end,:); rmsValues(channelIndices)];
    mpfHistory = [mpfHistory(2:end,:); mpfValues];
    
    % Update MPF slope buffer
    mpf_buffer = [mpf_buffer(2:end,:); mpfValues];
    time_buffer = [time_buffer(2:end) datetime('now')];
    
    % --- Update Plots ---
    % Update RMS plot
    for i = 1:4
        set(rmsPlots(i), 'XData', timeStamps, 'YData', rmsHistory(:,i));
    end
    
    % Update MPF plot
    for i = 1:4
        set(mpfPlots(i), 'XData', timeStamps, 'YData', mpfHistory(:,i));
    end
    
    % --- Fatigue Detection ---
    fatigue_flags = false(1,4);
    if size(mpf_buffer,1) >= 2
        time_diff = seconds(time_buffer(end) - time_buffer(1));
        for ch = 1:4
            slope = (mpf_buffer(end,ch) - mpf_buffer(1,ch))/time_diff;
            if slope < threshold_MPF_slope
                fatigue_flags(ch) = true;
            end
        end
    end
    
    % --- Console Output ---
    fprintf('[Window %d] %s\n',...
            mod(floor(toc),1000), datetime('now'));
    
    % 1. Muscle imbalance detection
    [SI1, dir1] = get_imbalance(rmsValues(1), rmsValues(2), threshold_SI);
    [SI2, dir2] = get_imbalance(rmsValues(5), rmsValues(6), threshold_SI);
    
    fprintf('Imbalance Status:\n');
    fprintf(' CH1/CH2: %s (SI=%.1f%%)\n',...
            format_dir(dir1, SI1, threshold_SI), SI1);
    fprintf(' CH5/CH6: %s (SI=%.1f%%)\n',...
            format_dir(dir2, SI2, threshold_SI), SI2);
    
    % 2. Fatigue detection
    fprintf('\nFatigue Flags:\n');
    for ch = 1:4
        if fatigue_flags(ch)
            fprintf(' %s: FATIGUE (MPF=%.1f Hz)\n', labels{ch}, mpfValues(ch));
            beep;
        else
            fprintf(' %s: Normal\n', labels{ch});
        end
    end
    fprintf('------------------------\n\n');
    
    drawnow limitrate;
end

% --- Helper Functions ---
function [SI, direction] = get_imbalance(rmsA, rmsB, threshold)
    SI = abs((rmsA - rmsB)/(rmsA + rmsB)) * 100;
    if SI > threshold
        if rmsA > rmsB
            direction = 'left';
        else
            direction = 'right';
        end
    else
        direction = 'balanced';
    end
end

function str = format_dir(dir, SI, threshold)
    if strcmp(dir, 'balanced')
        str = sprintf('Balanced (SI < %.1f%%)', threshold);
    else
        str = sprintf('IMBALANCE → %s dominant', upper(dir));
    end
end