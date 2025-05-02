% clear
clc; clear;

% Initialize serial port
s = serialport('COM5', 115200);
flush(s);

% Parameters
numChannels = 6;      % Total number of channels
windowSize = 1000;    % Number of samples per RMS calculation
maxPoints = 20;       % Maximum number of points to display in the plot

% Initialize data buffers(FIFO)
rmsHistory = nan(maxPoints, 4);  % Pre-filled with NaN, 4 columns corresponding to CH1/2/5/6
timeStamps = 1:maxPoints;        % X-axis 1-20

%  Set up the figure and scatter plots
figure;
hold on;
colors = {'r', 'g', 'b', 'k'};
markers = {'o', 's', 'd', '^'};
scatterHandles = gobjects(1, 4);

% Initialize scatterplot (all NaN)
for i = 1:4
    scatterHandles(i) = scatter(nan, nan, 50, colors{i}, markers{i}, 'filled');
end

% Graphic beautification
legend('CH1', 'CH2', 'CH5', 'CH6');
xlabel('Rolling Window Index (Latest → Oldest)');
ylabel('RMS Value');
title('Real-Time RMS (Sliding Window)');
xlim([0.5, maxPoints+0.5]);
ylim([0, 150]); 
grid on;
set(gca, 'XTick', 1:maxPoints);

% Data Acquisition Cycle
sampleCount = 0;
dataBuffer = zeros(windowSize, numChannels);

while true
    % 1000 samples collected
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
    
    % Calculated RMS (all channels)
    rmsValues = sqrt(mean(dataBuffer.^2, 1));
    
    % Update data buffer: old data shifted left, new data added to the end
    rmsHistory = [rmsHistory(2:end, :); rmsValues([1 2 5 6])]; % ← Key modify
    
    % Update scatterplot
    for i = 1:4
        set(scatterHandles(i), 'XData', timeStamps, 'YData', rmsHistory(:, i));
    end
    
    % Reset sample count
    sampleCount = 0;
    drawnow limitrate; 
end



% Dynamic Y-axis
% currentMax = max(rmsHistory(:), [], 'omitnan');
% if currentMax > ylimUpper || currentMax < ylimUpper*0.8
%     ylim([0, currentMax * 1.1]);
% end