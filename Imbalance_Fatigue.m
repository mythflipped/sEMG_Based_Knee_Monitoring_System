% clear
clc; clear;

% Initialize serial port
s = serialport('COM5', 115200);
flush(s);  % Clear any existing data in the buffer

% Parameters
numChannels = 6;      % Number of channels
windowSize = 1000;    % Samples per window
Fs = 512;            % Sampling frequency
threshold_SI = 15;    % Symmetry Index threshold for imbalance (%)
threshold_MPF_slope = -5; % MPF slope threshold for fatigue (Hz/sec)

% Buffers for trend analysis
mpf_history = zeros(1, 4);  % MPF history for CH1, CH2, CH5, CH6
time_history = [];           % Timestamps for MPF slope calculation

% Continuous data acquisition loop
while true
    sampleCount = 0;
    dataBuffer = zeros(windowSize, numChannels);  % Reset buffer
    
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
    
    % --- 1. Muscle Imbalance Analysis (Time Domain) ---
    % Compute RMS for all channels
    rmsValues = sqrt(mean(dataBuffer.^2, 1));
    
    % Symmetry Index Calculation (CH1 vs CH5, CH2 vs CH6)
    [SI1, imbalance_dir1] = get_imbalance(rmsValues(1), rmsValues(5), threshold_SI);
    [SI2, imbalance_dir2] = get_imbalance(rmsValues(2), rmsValues(6), threshold_SI);
    
    % --- 2. Fatigue Analysis (Frequency Domain) ---
    % Calculate MPF for key channels (CH1, CH2, CH5, CH6)
    channelIndices = [1, 2, 5, 6];
    mpfValues = zeros(1, 4);
    for i = 1:4
        signal = dataBuffer(:, channelIndices(i));
        [pxx, f] = pwelch(signal, hann(256), 128, [], Fs); % Welch's method
        mpfValues(i) = sum(f .* pxx) / sum(pxx);            % Mean Power Frequency
    end
    
    % Update MPF history and detect fatigue
    [fatigue_flags, time_history, mpf_history] = detect_fatigue(mpfValues, time_history, mpf_history, threshold_MPF_slope);
    
    % --- 3. Display Results ---
    fprintf('=== Analysis Results ===\n');
    
    % 1. Print RMS values
    fprintf('RMS Values:\n');
    fprintf('CH1: %.2f μV | CH5 (Right): %.2f μV\n', rmsValues(1), rmsValues(5));
    fprintf('CH2: %.2f μV | CH6 (Right): %.2f μV\n', rmsValues(2), rmsValues(6));
    
    % 2. Muscle Imbalance Report
    fprintf('\nMuscle Imbalance:\n');
    print_imbalance('Left Leg (CH1) vs Right Leg (CH5)', SI1, imbalance_dir1, threshold_SI);
    print_imbalance('Left Leg (CH2) vs Right Leg (CH6)', SI2, imbalance_dir2, threshold_SI);
    
    % 3. Fatigue Report
    fprintf('\nFatigue Status:\n');
    fatigue_channels = {'CH1', 'CH2', 'CH5', 'CH6'};
    for i = 1:4
        if fatigue_flags(i)
            fprintf('%s: FATIGUE DETECTED (MPF slope < %.1f Hz/s)\n', fatigue_channels{i}, threshold_MPF_slope);
            beep;
        else
            fprintf('%s: Normal\n', fatigue_channels{i});
        end
    end
    
    fprintf('========================\n\n');
end

% --- Helper Functions ---
% --- Helper Functions ---
function [SI, direction] = get_imbalance(rms_left, rms_right, threshold)
    SI = abs((rms_left - rms_right) / (rms_left + rms_right)) * 100;
    if SI > threshold

        if rms_left > rms_right
            direction = 'left';
        else
            direction = 'right';
        end
    else
        direction = 'balanced';
    end
end

function print_imbalance(label, SI, direction, threshold)
    if strcmp(direction, 'balanced')
        fprintf('%s: Balanced (SI=%.1f%% < %.1f%%)\n', label, SI, threshold);
    else
        fprintf('%s: IMBALANCE! %s side dominant (SI=%.1f%% > %.1f%%)\n',...
                label, upper(direction), SI, threshold);
    end
end

function [fatigue_flags, time_out, mpf_out] = detect_fatigue(mpf_current, time_in, mpf_in, slope_threshold)
    % Initialize history
    time_out = [time_in, datetime('now')];
    mpf_out = [mpf_in; mpf_current];
    
    % Keep only last 5 data points for slope calculation
    if size(mpf_out, 1) > 5
        time_out(1) = [];
        mpf_out(1, :) = [];
    end
    
    % Calculate MPF slope (Hz/sec)
    fatigue_flags = false(1, 4);
    if size(mpf_out, 1) >= 2
        time_diff = seconds(time_out(end) - time_out(1));
        for ch = 1:4
            slope = (mpf_out(end, ch) - mpf_out(1, ch)) / time_diff;
            if slope < slope_threshold
                fatigue_flags(ch) = true;
            end
        end
    end
end