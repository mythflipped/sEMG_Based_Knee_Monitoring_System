% Read your sEMG data
filename = 'Test_FIle.csv';
data = readmatrix(filename);  % or use readtable() if your file has headers

Fs = 500;  % Sampling frequency in Hz (adjust to your actual value)
L = size(data, 1);  % Number of samples
f = Fs * (0:(L/2)) / L;  % Frequency vector (one-sided)

% Plot FFT for each channel
figure;
for ch = 1:size(data, 2)
    signal = data(:, ch);

    % Remove DC offset
    signal = signal - mean(signal);

    % Perform FFT
    Y = fft(signal);
    P2 = abs(Y / L);        % Two-sided spectrum
    P1 = P2(1:L/2+1);       % One-sided spectrum
    P1(2:end-1) = 2*P1(2:end-1);  % Multiply by 2 (except DC and Nyquist)

    subplot(3, 2, ch);  % Adjust subplot size based on number of channels
    plot(f, P1);
    title(sprintf('FFT of CH%d', ch));
    xlabel('Frequency (Hz)');
    ylabel('|P1(f)|');
    xlim([0 Fs/2]);  % Limit to Nyquist frequency
end
sgtitle('Frequency Analysis of sEMG Channels');


% 
% % Power spectral density (optional, using FFT result)
% power_spectrum = P1.^2;
% total_power = sum(power_spectrum);
% mean_freq = sum(f .* power_spectrum) / total_power;
% 
% % Median frequency
% cum_power = cumsum(power_spectrum);
% median_freq = f(find(cum_power >= total_power/2, 1));
% 
% fprintf('Mean Frequency: %.2f Hz\n', mean_freq);
% fprintf('Median Frequency: %.2f Hz\n', median_freq);