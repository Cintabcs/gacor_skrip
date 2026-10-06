% =========================================================
% SNR pada Sinyal RAW (Versi A - SEBELUM Preprocessing)
% MATLAB Reference Script
% Output: preprocessing/matlab/output/snr_raw/
% =========================================================

Fs      = 1000;
raw_dir = 'C:\Users\FILKOM\Downloads\utama\Data_CSV';
out_dir = 'C:\Users\FILKOM\Downloads\utama\preprocessing\versi_A\matlab\output\snr_raw';

if ~exist(out_dir, 'dir'); mkdir(out_dir); end

% Filter design
[b_bp, a_bp]       = butter(4, [20 450]/(Fs/2), 'bandpass');
Wo                 = 50/(Fs/2);
[b_notch, a_notch] = iirnotch(Wo, Wo/30);

files = dir(fullfile(raw_dir, '*.csv'));
fprintf('Ditemukan %d file RAW.\n\n', length(files));

filenames  = {};
n_samples  = [];
durations  = [];
snr_values = [];

for i = 1:length(files)
    fpath = fullfile(files(i).folder, files(i).name);
    fname = files(i).name;
    fprintf('  SNR-RAW: %s\n', fname);

    try
        df = readtable(fpath);
    catch
        fprintf('    -> Skip: gagal dibaca\n'); continue;
    end
    if ~ismember('Raw', df.Properties.VariableNames)
        fprintf('    -> Skip: kolom Raw tidak ada\n'); continue;
    end

    raw = df.Raw;
    if length(raw) <= 27
        fprintf('    -> Skip: data terlalu pendek (%d sampel)\n', length(raw)); continue;
    end
    if any(~isfinite(raw))
        fprintf('    -> Skip: mengandung NaN/Inf\n'); continue;
    end

    % Hitung SNR
    raw_dc = raw - mean(raw);
    sig    = filtfilt(b_bp, a_bp, raw_dc);
    sig    = filtfilt(b_notch, a_notch, sig);
    noise  = raw_dc - sig;

    p_sig = mean(sig .^ 2);
    p_noi = mean(noise .^ 2);
    if p_sig == 0 || p_noi == 0
        snr_db = NaN;
    else
        snr_db = 10 * log10(p_sig / p_noi);
    end

    filenames{end+1}  = fname;
    n_samples(end+1)  = length(raw);
    durations(end+1)  = length(raw) / Fs;
    snr_values(end+1) = snr_db;
end

% Simpan CSV
T = table(filenames', n_samples', durations', snr_values', ...
    'VariableNames', {'Filename','N_Samples','Duration_s','SNR_dB'});
writetable(T, fullfile(out_dir, 'snr_raw_results.csv'));

valid_snr = snr_values(isfinite(snr_values));
fprintf('\n===== RINGKASAN SNR-RAW (Versi A) =====\n');
fprintf('Jumlah file  : %d\n', length(filenames));
fprintf('SNR rata-rata: %.2f dB\n', mean(valid_snr));
fprintf('SNR median   : %.2f dB\n', median(valid_snr));
fprintf('SNR min      : %.2f dB\n', min(valid_snr));
fprintf('SNR max      : %.2f dB\n', max(valid_snr));
fprintf('========================================\n');

% Bar chart
fig1 = figure('Visible','off','Position',[100 100 1400 500]);
bar(snr_values); hold on;
yline(10,'--g','SNR=10dB','LineWidth',1.2);
yline(0,'--','SNR=0dB','Color',[1 0.5 0],'LineWidth',1.2);
yline(mean(valid_snr),'-c',sprintf('Mean=%.2f dB',mean(valid_snr)),'LineWidth',1.5);
xticks(1:length(filenames)); xticklabels(filenames); xtickangle(90);
xlabel('File'); ylabel('SNR (dB)');
title('[Versi A] SNR pada Sinyal RAW (Sebelum Preprocessing)');
grid on;
saveas(fig1, fullfile(out_dir,'snr_raw_chart.png')); close(fig1);

% Histogram
fig2 = figure('Visible','off','Position',[100 100 700 450]);
histogram(valid_snr, 20, 'FaceColor',[0.61 0.35 0.71],'EdgeColor','white');
hold on; xline(mean(valid_snr),'--r',sprintf('Mean=%.2f dB',mean(valid_snr)),'LineWidth',1.5);
xlabel('SNR (dB)'); ylabel('Jumlah File');
title('[Versi A] Distribusi SNR Sinyal RAW'); grid on;
saveas(fig2, fullfile(out_dir,'snr_raw_histogram.png')); close(fig2);

fprintf('\nSelesai! Output ada di: %s\n', out_dir);
