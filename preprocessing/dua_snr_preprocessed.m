% =========================================================
% SNR Calculation — EMG Data (Versi B)
% =========================================================
%
% Pipeline:
%   Data_baru/ (CSV akuisisi) --> hitung SNR per file DATA
%
% Formula SNR:
%   raw_dc   = Raw - mean(Raw)          % buang DC offset elektroda/ADC
%   noise    = raw_dc - Filtered        % komponen yang dibuang filter
%   P_signal = mean(Filtered .^ 2)      % daya sinyal EMG bersih
%   P_noise  = mean(noise .^ 2)         % daya noise yang dieliminasi filter
%   SNR_dB   = 10 * log10(P_signal / P_noise)
%              ^--- hasil sudah dalam satuan dB, TIDAK perlu konversi lagi
%
% Catatan Raw vs Raw DC Removed:
%   Raw          = sinyal ADC mentah, mengandung DC offset besar (~1380)
%                  akibat bias elektroda + ADC reference
%   Raw DC Removed = Raw - mean(Raw)
%                  = komponen AC saja (sinyal EMG + noise frekuensi)
%   --> DC offset BUKAN noise frekuensi, sehingga harus dibuang dulu
%       sebelum menghitung daya noise agar SNR tidak bias
%
% Input  : Data_baru/**/*_DATA*_HASIL.csv  (file akuisisi, bukan latihan)
% Output : preprocessing/versi_B/matlab/output/snr/
%          - snr_results.csv      (tabel nilai SNR per file)
%          - snr_chart.png        (bar chart SNR)
%          - snr_histogram.png    (distribusi SNR)
%          - plot per file        (Raw DC Removed + Filtered vs Time)
% =========================================================

clear; clc;

Fs          = 1000;
data_dir    = 'C:\Users\FILKOM\Downloads\utama\Data_baru';
out_snr_dir = 'C:\Users\FILKOM\Downloads\utama\preprocessing\versi_B\matlab\output\snr';
out_plt_dir = fullfile(out_snr_dir, 'plots');

if ~exist(out_snr_dir, 'dir'); mkdir(out_snr_dir); end
if ~exist(out_plt_dir, 'dir'); mkdir(out_plt_dir); end

% ---- Keyword yang di-skip (bukan data pengukuran utama) ----
skip_keywords = {'BACKUP','SEMPET','ANESTESI','LATIHAN','TEST','COBA'};

% ---- Cari semua file CSV di Data_baru ----
csv_files = dir(fullfile(data_dir, '**', '*.csv'));
fprintf('Total file CSV ditemukan: %d\n', length(csv_files));

filenames  = {};
pasien_ids = {};
n_samples  = [];
durations  = [];
snr_values = [];

fprintf('\n--- Proses file ---\n');

for i = 1:length(csv_files)
    fname = csv_files(i).name;
    fpath = fullfile(csv_files(i).folder, fname);
    fprintf('  [%d] %s\n', i, fname);

    % Skip file latihan / backup / anestesi
    fname_up  = upper(fname);
    skip_flag = false;
    for k = 1:length(skip_keywords)
        if contains(fname_up, skip_keywords{k})
            fprintf('      -> Skip: kata kunci "%s"\n', skip_keywords{k});
            skip_flag = true;
            break;
        end
    end
    if skip_flag; continue; end

    % Hanya proses file yang ada "_DATA" di namanya
    if ~contains(fname_up, '_DATA')
        fprintf('      -> Skip: bukan file data utama\n');
        continue;
    end

    % Baca file
    try
        df = readtable(fpath, 'VariableNamingRule', 'preserve');
    catch
        fprintf('      -> Skip: gagal dibaca\n');
        continue;
    end

    % Cek kolom yang dibutuhkan
    vars = df.Properties.VariableNames;
    if ~ismember('Raw', vars) || ~ismember('Filtered', vars)
        fprintf('      -> Skip: kolom Raw / Filtered tidak ada\n');
        continue;
    end

    raw      = df.Raw;
    filtered = df.Filtered;
    N        = length(raw);

    % Validasi panjang & NaN
    if N < 100
        fprintf('      -> Skip: terlalu pendek (%d sampel)\n', N);
        continue;
    end
    if any(~isfinite(raw)) || any(~isfinite(filtered))
        fprintf('      -> Skip: mengandung NaN / Inf\n');
        continue;
    end

    % ---- Hitung SNR ----
    % Buang DC offset elektroda/ADC terlebih dahulu
    raw_dc  = raw - mean(raw);          % Raw DC Removed
    noise   = raw_dc - filtered;        % komponen yang dibuang filter
    p_sig   = mean(filtered .^ 2);      % daya sinyal EMG bersih
    p_noi   = mean(noise    .^ 2);      % daya noise

    if p_sig == 0 || p_noi == 0
        snr_db = NaN;
        fprintf('      -> SNR tidak terdefinisi (P = 0)\n');
    else
        snr_db = 10 * log10(p_sig / p_noi);  % satuan dB
        fprintf('      -> SNR = %.2f dB\n', snr_db);
    end

    % ---- Plot sinyal per file: Raw DC Removed & Filtered vs Time ----
    time_s = (0:N-1)' / Fs;

    fig = figure('Visible', 'off', 'Position', [100 100 1200 500]);
    plot(time_s, raw_dc,   'Color', [0.5 0.5 0.5], 'LineWidth', 0.5);
    hold on;
    plot(time_s, filtered, 'Color', [0.18 0.55 0.85], 'LineWidth', 0.8);
    xlabel('Waktu (s)');
    ylabel('Amplitudo (\muV)');
    if isfinite(snr_db)
        title_str = sprintf('%s  |  SNR = %.2f dB', strrep(fname, '_', '\_'), snr_db);
    else
        title_str = sprintf('%s  |  SNR = N/A', strrep(fname, '_', '\_'));
    end
    title(title_str, 'FontSize', 10);
    legend('Raw DC Removed', 'Filtered (Preprocessed)', 'Location', 'best');
    grid on;
    saveas(fig, fullfile(out_plt_dir, strrep(fname, '.csv', '_snr.png')));
    close(fig);

    % Simpan ke array hasil
    filenames{end+1}  = fname;                          %#ok<AGROW>
    pasien_ids{end+1} = csv_files(i).folder(end-max(0,length(csv_files(i).folder)-length(data_dir)-2):end); %#ok<AGROW>
    n_samples(end+1)  = N;                              %#ok<AGROW>
    durations(end+1)  = N / Fs;                         %#ok<AGROW>
    snr_values(end+1) = snr_db;                         %#ok<AGROW>
end

if isempty(filenames)
    fprintf('\nTidak ada file yang berhasil diproses.\n');
    return;
end

% ---- Simpan tabel hasil SNR ke CSV ----
T = table(filenames', n_samples', durations', snr_values', ...
    'VariableNames', {'Filename', 'N_Samples', 'Duration_s', 'SNR_dB'});
out_csv = fullfile(out_snr_dir, 'snr_results.csv');
writetable(T, out_csv);
fprintf('\nHasil SNR disimpan ke: %s\n', out_csv);

% ---- Statistik deskriptif ----
valid_snr = snr_values(isfinite(snr_values));
fprintf('\n===== STATISTIK SNR =====\n');
fprintf('File diproses  : %d\n', length(filenames));
fprintf('SNR rata-rata  : %.4f dB\n', mean(valid_snr));
fprintf('SNR median     : %.4f dB\n', median(valid_snr));
fprintf('SNR min        : %.4f dB\n', min(valid_snr));
fprintf('SNR max        : %.4f dB\n', max(valid_snr));
fprintf('SNR std        : %.4f dB\n', std(valid_snr));
fprintf('=========================\n');

% ---- Bar chart SNR ----
% Catatan: tidak ada threshold "baik/buruk" — nilai ditampilkan apa adanya.
% Garis referensi hanya mean dan median dari data ini sendiri.
fig1 = figure('Visible', 'off', 'Position', [100 100 max(800, length(filenames)*60) 500]);
b = bar(snr_values, 'FaceColor', [0.20 0.55 0.85], 'EdgeColor', 'white');
hold on;
yline(mean(valid_snr),   '-',  sprintf('Mean = %.2f dB',   mean(valid_snr)),   ...
      'Color', [0.85 0.33 0.10], 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
yline(median(valid_snr), '--', sprintf('Median = %.2f dB', median(valid_snr)), ...
      'Color', [0.49 0.18 0.56], 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'right');
xticks(1:length(filenames));
xticklabels(filenames);
xtickangle(45);
xlabel('File');
ylabel('SNR (dB)');
title('Signal-to-Noise Ratio (SNR) per File EMG — Versi B');
grid on; box on;
saveas(fig1, fullfile(out_snr_dir, 'snr_chart.png'));
close(fig1);

% ---- Histogram distribusi SNR ----
fig2 = figure('Visible', 'off', 'Position', [100 100 700 450]);
histogram(valid_snr, 'FaceColor', [0.20 0.55 0.85], 'EdgeColor', 'white', ...
          'Normalization', 'count');
hold on;
xline(mean(valid_snr),   '-',  sprintf('Mean = %.2f dB',   mean(valid_snr)),   ...
      'Color', [0.85 0.33 0.10], 'LineWidth', 1.5);
xline(median(valid_snr), '--', sprintf('Median = %.2f dB', median(valid_snr)), ...
      'Color', [0.49 0.18 0.56], 'LineWidth', 1.2);
xlabel('SNR (dB)');
ylabel('Jumlah File');
title('Distribusi SNR — EMG Versi B');
grid on;
saveas(fig2, fullfile(out_snr_dir, 'snr_histogram.png'));
close(fig2);

fprintf('\nSelesai! Semua output SNR tersimpan di:\n  %s\n', out_snr_dir);
fprintf('  - snr_results.csv\n');
fprintf('  - snr_chart.png\n');
fprintf('  - snr_histogram.png\n');
fprintf('  - plots/ (per file)\n');
