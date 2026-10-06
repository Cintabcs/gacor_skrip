% =========================================================
% SNR Calculation for RAW EMG Data (MATLAB Reference)
% Pipeline: baca preprocessed output -> hitung SNR per file
% =========================================================

% Konfigurasi
Fs               = 1000;
preprocessed_dir = 'C:\Users\FILKOM\Downloads\utama\preprocessing\versi_B\matlab\output\data';
out_snr_dir      = 'C:\Users\FILKOM\Downloads\utama\preprocessing\versi_B\matlab\output\snr';

if ~exist(out_snr_dir, 'dir')
    mkdir(out_snr_dir);
end

% Fungsi hitung SNR
%   signal = Preprocessed_EMG
%   noise  = Raw (DC removed) - Preprocessed_EMG
%   SNR    = 10 * log10(P_signal / P_noise)

csv_files = dir(fullfile(preprocessed_dir, '**', '*.csv'));

filenames  = {};
n_samples  = [];
durations  = [];
snr_values = [];

fprintf('Ditemukan %d file preprocessed.\n\n', length(csv_files));

for i = 1:length(csv_files)
    fpath = fullfile(csv_files(i).folder, csv_files(i).name);
    fname = csv_files(i).name;
    fprintf('  SNR: %s\n', fname);

    % Skip data latihan / backup
    if contains(upper(fname), 'BACKUP') || contains(upper(fname), 'SEMPET')
        fprintf('    -> Skip: File latihan / backup\n');
        continue;
    end

    try
        df = readtable(fpath);
    catch
        fprintf('    -> Skip: gagal dibaca\n');
        continue;
    end

    if ~ismember('Raw', df.Properties.VariableNames) || ...
       ~ismember('Preprocessed_EMG', df.Properties.VariableNames)
        fprintf('    -> Skip: kolom tidak lengkap\n');
        continue;
    end

    raw  = df.Raw;
    prep = df.Preprocessed_EMG;

    % Validasi NaN / Inf
    if any(~isfinite(raw)) || any(~isfinite(prep))
        fprintf('    -> Skip: mengandung NaN/Inf\n');
        continue;
    end

    % Hitung SNR (Noise = Raw Asli - Hasil Filter)
    noise  = raw - prep;
    p_sig  = mean(prep .^ 2);
    p_noi  = mean(noise .^ 2);

    if p_sig == 0 || p_noi == 0
        snr_db = NaN;
    else
        snr_db = 10 * log10(p_sig / p_noi);
    end

    filenames{end+1}  = fname;  %#ok<AGROW>
    n_samples(end+1)  = length(raw); %#ok<AGROW>
    durations(end+1)  = length(raw) / Fs; %#ok<AGROW>
    snr_values(end+1) = snr_db; %#ok<AGROW>
end

% --- Simpan tabel CSV ---
T = table(filenames', n_samples', durations', snr_values', ...
    'VariableNames', {'Filename','N_Samples','Duration_s','SNR_dB'});
out_csv = fullfile(out_snr_dir, 'snr_results.csv');
writetable(T, out_csv);
fprintf('\nHasil SNR disimpan: %s\n', out_csv);

% --- Ringkasan statistik ---
valid_snr = snr_values(isfinite(snr_values));
[min_val, min_idx] = min(valid_snr);
[max_val, max_idx] = max(valid_snr);

fprintf('\n===== RINGKASAN SNR =====\n');
fprintf('Jumlah file  : %d\n', length(filenames));
fprintf('SNR rata-rata: %.2f dB\n', mean(valid_snr));
fprintf('SNR median   : %.2f dB\n', median(valid_snr));
fprintf('SNR min      : %.2f dB\n', min_val);
fprintf('SNR max      : %.2f dB\n', max_val);
fprintf('=========================\n');

% --- Bar chart SNR ---
fig1 = figure('Visible', 'off', 'Position', [100 100 1400 500]);
bar_colors = zeros(length(snr_values), 3);
for k = 1:length(snr_values)
    if snr_values(k) >= 10
        bar_colors(k,:) = [0.18 0.80 0.44]; % hijau
    elseif snr_values(k) >= 0
        bar_colors(k,:) = [0.90 0.50 0.14]; % oranye
    else
        bar_colors(k,:) = [0.91 0.30 0.24]; % merah
    end
end
b = bar(snr_values, 'FaceColor', 'flat');
b.CData = bar_colors;
hold on;
yline(10, '--', 'SNR=10dB (Baik)', 'Color', 'green', 'LineWidth', 1.2);
yline(0,  '--', 'SNR=0dB (Batas)',  'Color', [1 0.5 0], 'LineWidth', 1.2);
yline(mean(valid_snr), '-', sprintf('Mean=%.2f dB', mean(valid_snr)), ...
      'Color', 'cyan', 'LineWidth', 1.5);
xticks(1:length(filenames));
xticklabels(filenames);
xtickangle(90);
xlabel('File'); ylabel('SNR (dB)');
title('Signal-to-Noise Ratio (SNR) per File RAW EMG');
grid on;
tight_layout = false; %#ok<NASGU>
saveas(fig1, fullfile(out_snr_dir, 'snr_chart.png'));
close(fig1);

% --- Histogram ---
fig2 = figure('Visible', 'off', 'Position', [100 100 700 450]);
histogram(valid_snr, 20, 'FaceColor', [0.20 0.60 0.86], 'EdgeColor', 'white');
hold on;
xline(mean(valid_snr), '--r', sprintf('Mean = %.2f dB', mean(valid_snr)), 'LineWidth', 1.5);
xlabel('SNR (dB)'); ylabel('Jumlah File');
title('Distribusi SNR Seluruh File EMG');
grid on;
saveas(fig2, fullfile(out_snr_dir, 'snr_histogram.png'));
close(fig2);

fprintf('\nSelesai! Semua output SNR ada di:\n  %s\n', out_snr_dir);
