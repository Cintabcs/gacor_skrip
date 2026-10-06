% Preprocessing EMG Data (MATLAB version)
% Pipeline: RAW -> Bandpass 20-450 Hz -> Notch 50 Hz

% Konfigurasi
Fs = 1000; % Sampling frequency
raw_dir = 'C:\Users\FILKOM\Downloads\utama\Data_CSV';
out_base_dir = 'C:\Users\FILKOM\Downloads\utama\preprocessing\versi_A\matlab\output';
out_data_dir = fullfile(out_base_dir, 'data');
out_plots_dir = fullfile(out_base_dir, 'plots');

% Buat folder output
if ~exist(out_data_dir, 'dir')
    mkdir(out_data_dir);
end
if ~exist(out_plots_dir, 'dir')
    mkdir(out_plots_dir);
end

% Bandpass filter (20 - 450 Hz)
[b_bp, a_bp] = butter(4, [20 450]/(Fs/2), 'bandpass');

% Notch filter (50 Hz)
Wo = 50/(Fs/2);
BW = Wo/30; % Q-factor = 30
[b_notch, a_notch] = iirnotch(Wo, BW);

% Dapatkan list file CSV
files = dir(fullfile(raw_dir, '**', '*.csv'));

count = 0;
for i = 1:length(files)
    file_path = fullfile(files(i).folder, files(i).name);
    
    % Get relative path to maintain folder structure
    rel_folder = strrep(files(i).folder, raw_dir, '');
    if startsWith(rel_folder, '\')
        rel_folder = extractAfter(rel_folder, 1);
    end
    
    curr_out_data_dir = fullfile(out_data_dir, rel_folder);
    curr_out_plots_dir = fullfile(out_plots_dir, rel_folder);
    
    if ~exist(curr_out_data_dir, 'dir')
        mkdir(curr_out_data_dir);
    end
    if ~exist(curr_out_plots_dir, 'dir')
        mkdir(curr_out_plots_dir);
    end
    
    out_data_path = fullfile(curr_out_data_dir, files(i).name);
    out_plot_path = fullfile(curr_out_plots_dir, strrep(files(i).name, '.csv', '.png'));
    
    fprintf('Processing: %s\n', files(i).name);
    
    % Read data
    try
        df = readtable(file_path);
    catch
        fprintf('  -> Failed to read %s\n', files(i).name);
        continue;
    end
    
    if ~ismember('Raw', df.Properties.VariableNames)
        fprintf('  -> Skipping %s, "Raw" column not found.\n', files(i).name);
        continue;
    end
    
    raw_sig = df.Raw;
    
    % Check if enough data points for filtfilt (MATLAB needs > 24 for order-4 Butterworth)
    if length(raw_sig) <= 24
        fprintf('  -> Skipping %s, signal too short for filtfilt (%d <= 24).\n', files(i).name, length(raw_sig));
        continue;
    end
    
    % Preprocessing with zero-phase filtering
    bp_sig = filtfilt(b_bp, a_bp, raw_sig);
    final_sig = filtfilt(b_notch, a_notch, bp_sig);
    
    % Save data
    df.Preprocessed_EMG = final_sig;
    writetable(df, out_data_path);
    
    % Plotting
    time = (0:length(raw_sig)-1) / Fs;
    
    fig = figure('Visible', 'off', 'Position', [100, 100, 1200, 800]);
    
    % Time Domain Plots
    subplot(3, 2, 1);
    plot(time, raw_sig, 'Color', [0.5 0.5 0.5]);
    title('RAW EMG'); xlabel('Time (s)'); ylabel('Amplitude');
    
    subplot(3, 2, 3);
    plot(time, bp_sig, 'b');
    title('After Band-pass Filter (20-450 Hz)'); xlabel('Time (s)'); ylabel('Amplitude');
    
    subplot(3, 2, 5);
    plot(time, final_sig, 'g');
    title('After Notch Filter (50 Hz)'); xlabel('Time (s)'); ylabel('Amplitude');
    
    % PSD calculation parameters
    nfft = min(1024, length(raw_sig));
    window = hanning(nfft);
    
    noverlap = floor(nfft/2);
    
    subplot(3, 2, 2);
    [pxx, f] = pwelch(raw_sig, window, noverlap, nfft, Fs);
    semilogy(f, pxx, 'Color', [0.5 0.5 0.5]);
    title('PSD - RAW'); xlabel('Frequency (Hz)'); ylabel('PSD');
    
    subplot(3, 2, 4);
    [pxx, f] = pwelch(bp_sig, window, noverlap, nfft, Fs);
    semilogy(f, pxx, 'b');
    title('PSD - Bandpass'); xlabel('Frequency (Hz)'); ylabel('PSD');
    
    subplot(3, 2, 6);
    [pxx, f] = pwelch(final_sig, window, noverlap, nfft, Fs);
    semilogy(f, pxx, 'g');
    title('PSD - Final'); xlabel('Frequency (Hz)'); ylabel('PSD');
    
    saveas(fig, out_plot_path);
    close(fig);
    
    count = coually processed %d files.\n', count);
