% =========================================================================
% Script 4: Analisis Korelasi Spearman (RMS, MNF, MDF vs Time) 
%           & Uji Statistik Wilcoxon Signed Rank Test
% =========================================================================
% Rujukan Metodologi:
%   Garouche, M., & Thamsuwan, O. (2023). "Development of a Low-Cost Portable 
%   EMG for Measuring the Muscular Activity of Workers in the Field."
%   Sensors, 23(18), 7873.
%
% Output:
%   1. Trend parameter EMG vs Time (RMS, MNF, MDF) + garis regresi (Gambar 1)
%   2. Boxplot Korelasi Spearman EMG vs Time dengan scatter dots (Gambar 2)
%   3. Uji Statistik Wilcoxon Signed Rank Test (signrank)
% =========================================================================

clear; clc; close all;

% ---- Konfigurasi ----
Fs          = 1000;         % Frekuensi sampling (Hz)
win_ms      = 1000;         % Panjang window (ms) -> 1 detik untuk resolusi FFT 1 Hz
overlap_pct = 0.5;          % 50% overlap
win_samples = round(win_ms * Fs / 1000);             % 1000 sampel
step_samples = round(win_samples * (1 - overlap_pct)); % 500 sampel

% Path
script_dir  = fileparts(mfilename('fullpath'));
data_dir    = fullfile(script_dir, 'versi_B', 'matlab', 'output', 'data');
out_base    = fullfile(script_dir, 'versi_B', 'matlab', 'output', 'korelasi_wilcoxon');
out_plots   = fullfile(out_base, 'plots_trend');

if ~exist(out_base, 'dir');  mkdir(out_base);  end
if ~exist(out_plots, 'dir'); mkdir(out_plots); end

% Cari semua file preprocessed CSV
csv_files = dir(fullfile(data_dir, '**', '*.csv'));
fprintf('Ditemukan %d file CSV di folder output data.\n\n', length(csv_files));

skip_keywords = {'BACKUP', 'LATIHAN', 'TEST', 'COBA'};

% Array penampung hasil
filenames     = {};
patient_ids   = {};
corr_rms_all  = [];
pval_rms_all  = [];
corr_mnf_all  = [];
pval_mnf_all  = [];
corr_mdf_all  = [];
pval_mdf_all  = [];

% Simpan data tren untuk beberapa file contoh untuk membuat grid composite
sample_trends = struct();
sample_idx = 0;

fprintf('--- Memproses Ekstraksi Fitur & Korelasi Spearman ---\n');

for i = 1:length(csv_files)
    fname = csv_files(i).name;
    fpath = fullfile(csv_files(i).folder, fname);
    
    % Filter file yang di-skip
    fname_up = upper(fname);
    skip_flag = false;
    for k = 1:length(skip_keywords)
        if contains(fname_up, skip_keywords{k})
            skip_flag = true;
            break;
        end
    end
    if skip_flag; continue; end
    
    % Baca data
    try
        df = readtable(fpath);
    catch
        fprintf('  [SKIP] Gagal membaca: %s\n', fname);
        continue;
    end
    
    if ~ismember('Preprocessed_EMG', df.Properties.VariableNames)
        fprintf('  [SKIP] Kolom Preprocessed_EMG tidak ada: %s\n', fname);
        continue;
    end
    
    sig = df.Preprocessed_EMG;
    if length(sig) < (win_samples * 2) || any(~isfinite(sig))
        fprintf('  [SKIP] Data terlalu pendek / tidak valid: %s\n', fname);
        continue;
    end
    
    % Ekstrak Patient ID dari nama folder
    [~, parent_folder] = fileparts(csv_files(i).folder);
    
    % ---- Windowing: Ekstraksi RMS, MNF, MDF ----
    n_windows = floor((length(sig) - win_samples) / step_samples) + 1;
    time_w = zeros(n_windows, 1);
    rms_w  = zeros(n_windows, 1);
    mnf_w  = zeros(n_windows, 1);
    mdf_w  = zeros(n_windows, 1);
    
    f_res = Fs * (0:(win_samples/2))' / win_samples;
    freq_mask = (f_res >= 20) & (f_res <= 450);
    f_band = f_res(freq_mask);
    
    h_win = hamming(win_samples);
    
    for w = 1:n_windows
        idx_start = (w-1)*step_samples + 1;
        idx_end   = idx_start + win_samples - 1;
        w_data    = sig(idx_start:idx_end);
        
        % 1. Waktu tengah window (s)
        time_w(w) = (idx_start + win_samples/2 - 1) / Fs;
        
        % 2. RMS
        rms_w(w) = sqrt(mean(w_data .^ 2));
        
        % 3. FFT & Power Spectral Density
        w_spec = abs(fft(w_data .* h_win)).^2 / win_samples;
        p_band = w_spec(1:length(f_res));
        p_band = p_band(freq_mask);
        
        total_power = sum(p_band);
        if total_power > 0
            % Mean Power Frequency (MNF)
            mnf_w(w) = sum(f_band .* p_band) / total_power;
            
            % Median Power Frequency (MDF)
            cum_p = cumsum(p_band);
            idx_mdf = find(cum_p >= total_power / 2, 1, 'first');
            if ~isempty(idx_mdf)
                mdf_w(w) = f_band(idx_mdf);
            else
                mdf_w(w) = NaN;
            end
        else
            mnf_w(w) = NaN;
            mdf_w(w) = NaN;
        end
    end
    
    % Normalisasi RMS ke persentase (%) seperti pada Gambar 1
    max_rms = max(rms_w);
    if max_rms == 0; max_rms = 1; end
    rms_pct = (rms_w / max_rms) * 100;
    
    % Validasi finiteness
    valid_idx = isfinite(time_w) & isfinite(rms_pct) & isfinite(mnf_w) & isfinite(mdf_w);
    t_v   = time_w(valid_idx);
    rms_v = rms_pct(valid_idx);
    mnf_v = mnf_w(valid_idx);
    mdf_v = mdf_w(valid_idx);
    
    if length(t_v) < 5
        continue;
    end
    
    % ---- Hitung Korelasi Spearman vs Time ----
    [r_rms, p_rms] = corr(t_v, rms_v, 'Type', 'Spearman');
    [r_mnf, p_mnf] = corr(t_v, mnf_v, 'Type', 'Spearman');
    [r_mdf, p_mdf] = corr(t_v, mdf_v, 'Type', 'Spearman');
    
    % Simpan ke daftar
    filenames{end+1}    = fname;
    patient_ids{end+1}  = parent_folder;
    corr_rms_all(end+1) = r_rms;
    pval_rms_all(end+1) = p_rms;
    corr_mnf_all(end+1) = r_mnf;
    pval_mnf_all(end+1) = p_mnf;
    corr_mdf_all(end+1) = r_mdf;
    pval_mdf_all(end+1) = p_mdf;
    
    fprintf('  Processed [%d]: %s -> r_RMS=%.2f, r_MNF=%.2f, r_MDF=%.2f\n', ...
            length(filenames), fname, r_rms, r_mnf, r_mdf);
        
    % ---- Plot Gambar 1 per File: RMS, MNF, MDF vs Time + Regresi Linier ----
    fig1 = figure('Visible', 'off', 'Position', [100, 100, 1200, 360], 'Color', 'w');
    
    % Subplot 1: RMS (%) vs Time (s)
    subplot(1, 3, 1);
    plot(t_v, rms_v, 'Color', [0.18 0.53 0.79], 'LineWidth', 1.2); hold on;
    p_fit1 = polyfit(t_v, rms_v, 1);
    plot(t_v, polyval(p_fit1, t_v), 'r-', 'LineWidth', 1.5);
    title_rms = sprintf('Coeff: %.2f, %s', r_rms, format_pval(p_rms));
    title(title_rms, 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
    xlabel('Time (s)', 'Color', 'k'); ylabel('RMS (%)', 'Color', 'k');
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    grid on; box on;
    
    % Subplot 2: MNF (Hz) vs Time (s)
    subplot(1, 3, 2);
    plot(t_v, mnf_v, 'Color', [0.18 0.53 0.79], 'LineWidth', 1.2); hold on;
    p_fit2 = polyfit(t_v, mnf_v, 1);
    plot(t_v, polyval(p_fit2, t_v), 'r-', 'LineWidth', 1.5);
    title_mnf = sprintf('Coeff: %.2f, %s', r_mnf, format_pval(p_mnf));
    title(title_mnf, 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
    xlabel('Time (s)', 'Color', 'k'); ylabel('MNF (Hz)', 'Color', 'k');
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    grid on; box on;
    
    % Subplot 3: MDF (Hz) vs Time (s)
    subplot(1, 3, 3);
    plot(t_v, mdf_v, 'Color', [0.18 0.53 0.79], 'LineWidth', 1.2); hold on;
    p_fit3 = polyfit(t_v, mdf_v, 1);
    plot(t_v, polyval(p_fit3, t_v), 'r-', 'LineWidth', 1.5);
    title_mdf = sprintf('Coeff: %.2f, %s', r_mdf, format_pval(p_mdf));
    title(title_mdf, 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
    xlabel('Time (s)', 'Color', 'k'); ylabel('MDF (Hz)', 'Color', 'k');
    set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
    grid on; box on;
    
    plot_save_path = fullfile(out_plots, strrep(fname, '.csv', '_trend.png'));
    saveas(fig1, plot_save_path);
    close(fig1);
    
    % Simpan sample representatif untuk composite grid (Gambar 1 style)
    if contains(fname, '_DATA1') && sample_idx < 2
        sample_idx = sample_idx + 1;
        sample_trends(sample_idx).fname = fname;
        sample_trends(sample_idx).t     = t_v;
        sample_trends(sample_idx).rms   = rms_v;
        sample_trends(sample_idx).mnf   = mnf_v;
        sample_trends(sample_idx).mdf   = mdf_v;
        sample_trends(sample_idx).r_rms = r_rms;
        sample_trends(sample_idx).p_rms = p_rms;
        sample_trends(sample_idx).r_mnf = r_mnf;
        sample_trends(sample_idx).p_mnf = p_mnf;
        sample_trends(sample_idx).r_mdf = r_mdf;
        sample_trends(sample_idx).p_mdf = p_mdf;
    end
end

% ---- Buat Gambar 1: Multi-Row Composite (Row A & Row B) ----
if sample_idx >= 2
    fig_comp = figure('Visible', 'off', 'Position', [100, 100, 1200, 650], 'Color', 'w');
    labels_row = {'(A)', '(B)'};
    for r = 1:2
        t_v   = sample_trends(r).t;
        rms_v = sample_trends(r).rms;
        mnf_v = sample_trends(r).mnf;
        mdf_v = sample_trends(r).mdf;
        
        % Col 1: RMS
        subplot(2, 3, (r-1)*3 + 1);
        plot(t_v, rms_v, 'Color', [0.18 0.53 0.79], 'LineWidth', 1.2); hold on;
        p1 = polyfit(t_v, rms_v, 1);
        plot(t_v, polyval(p1, t_v), 'r-', 'LineWidth', 1.5);
        title(sprintf('Coeff: %.2f, %s', sample_trends(r).r_rms, format_pval(sample_trends(r).p_rms)), ...
              'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
        xlabel('Time (s)', 'Color', 'k'); ylabel(sprintf('%s  RMS (%%)', labels_row{r}), 'Color', 'k');
        set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
        grid on; box on;
        
        % Col 2: MNF
        subplot(2, 3, (r-1)*3 + 2);
        plot(t_v, mnf_v, 'Color', [0.18 0.53 0.79], 'LineWidth', 1.2); hold on;
        p2 = polyfit(t_v, mnf_v, 1);
        plot(t_v, polyval(p2, t_v), 'r-', 'LineWidth', 1.5);
        title(sprintf('Coeff: %.2f, %s', sample_trends(r).r_mnf, format_pval(sample_trends(r).p_mnf)), ...
              'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
        xlabel('Time (s)', 'Color', 'k'); ylabel(sprintf('%s  MNF (Hz)', labels_row{r}), 'Color', 'k');
        set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
        grid on; box on;
        
        % Col 3: MDF
        subplot(2, 3, (r-1)*3 + 3);
        plot(t_v, mdf_v, 'Color', [0.18 0.53 0.79], 'LineWidth', 1.2); hold on;
        p3 = polyfit(t_v, mdf_v, 1);
        plot(t_v, polyval(p3, t_v), 'r-', 'LineWidth', 1.5);
        title(sprintf('Coeff: %.2f, %s', sample_trends(r).r_mdf, format_pval(sample_trends(r).p_mdf)), ...
              'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
        xlabel('Time (s)', 'Color', 'k'); ylabel(sprintf('%s  MDF (Hz)', labels_row{r}), 'Color', 'k');
        set(gca, 'Color', 'w', 'XColor', 'k', 'YColor', 'k');
        grid on; box on;
    end
    sgtitle('Correlation Analysis Between EMG Parameters (RMS, MNF, MDF) and Time', ...
            'FontWeight', 'bold', 'Color', 'k');
    saveas(fig_comp, fullfile(out_base, 'gambar1_korelasi_emg_vs_time.png'));
    close(fig_comp);
    fprintf('\n[OK] Gambar 1 berhasil disimpan: gambar1_korelasi_emg_vs_time.png\n');
end

% ---- Simpan Tabel Ringkasan Korelasi Spearman ----
T_spearman = table(filenames', patient_ids', ...
    corr_rms_all', pval_rms_all', ...
    corr_mdf_all', pval_mdf_all', ...
    corr_mnf_all', pval_mnf_all', ...
    'VariableNames', {'Filename', 'Patient', ...
                     'Spearman_RMS_time', 'Pval_RMS', ...
                     'Spearman_MDF_time', 'Pval_MDF', ...
                     'Spearman_MNF_time', 'Pval_MNF'});
writetable(T_spearman, fullfile(out_base, 'spearman_correlation_summary.csv'));
fprintf('[OK] Tabel ringkasan disimpan: spearman_correlation_summary.csv\n');

% ---- Buat Gambar 2: Boxplot of Spearman Correlation with Scatter Jitter ----
fig2 = figure('Visible', 'off', 'Position', [100, 100, 850, 520], 'Color', 'w');

data_matrix = [corr_rms_all', corr_mdf_all', corr_mnf_all'];
group_names = {'RMS-time', 'MDF-time', 'MNF-time'};

% Buat boxplot
h_box = boxplot(data_matrix, 'Labels', group_names, 'Colors', [0.0 0.65 0.75], ...
        'Symbol', '', 'Widths', 0.45);
set(h_box, 'LineWidth', 1.3);
hold on;

% Tambahkan jitter dots (scatter individual) seperti pada Gambar 2
rng(42); % seed reproducible
for col = 1:3
    y_col = data_matrix(:, col);
    x_jitter = col + (rand(size(y_col)) - 0.5) * 0.18;
    scatter(x_jitter, y_col, 30, [0.15 0.15 0.15], 'filled', ...
            'MarkerFaceAlpha', 0.85);
end

% Garis referensi korelasi 0
yline(0, '--', 'Color', [0.55 0.55 0.55], 'LineWidth', 1.2);

ylim([-1.05, 1.05]);
yticks(-1:0.25:1);
title('Boxplot of the Spearman correlation between EMG and time', ...
      'FontSize', 12, 'FontWeight', 'bold', 'Color', 'k');
xlabel('Parameters', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
ylabel('Spearman Correlation', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'k');
set(gca, 'Color', [0.95 0.95 0.95], 'XColor', 'k', 'YColor', 'k', ...
         'GridColor', [0.85 0.85 0.85], 'GridAlpha', 0.8);
grid on; box on;

saveas(fig2, fullfile(out_base, 'gambar2_boxplot_spearman_correlation.png'));
close(fig2);
fprintf('[OK] Gambar 2 berhasil disimpan: gambar2_boxplot_spearman_correlation.png\n');

% ---- Hitung Uji Statistik Wilcoxon Signed Rank Test (signrank) ----
fprintf('\n=======================================================\n');
fprintf('       HASIL UJI WILCOXON SIGNED RANK TEST (signrank)   \n');
fprintf('=======================================================\n');

% Uji 1: Apakah korelasi RMS-time berbeda signifikan dari 0?
[p_w_rms, h_w_rms, stats_rms] = signrank(corr_rms_all);

% Uji 2: Apakah korelasi MDF-time berbeda signifikan dari 0?
[p_w_mdf, h_w_mdf, stats_mdf] = signrank(corr_mdf_all);

% Uji 3: Apakah korelasi MNF-time berbeda signifikan dari 0?
[p_w_mnf, h_w_mnf, stats_mnf] = signrank(corr_mnf_all);

% Uji Komparatif Berpasangan: RMS vs MDF
[p_w_pair1, ~, stats_pair1] = signrank(corr_rms_all, corr_mdf_all);

% Uji Komparatif Berpasangan: MDF vs MNF
[p_w_pair2, ~, stats_pair2] = signrank(corr_mdf_all, corr_mnf_all);

% Tampilkan di Command Window
fprintf('1. Uji Satu Sampel terhadap Nol (Uji Signifikansi Tren Relaksasi/Kelelahan):\n');
fprintf('   - RMS-time : Median = %+.3f, p-value = %.4e %s\n', ...
        median(corr_rms_all), p_w_rms, sig_mark(p_w_rms));
fprintf('   - MDF-time : Median = %+.3f, p-value = %.4e %s\n', ...
        median(corr_mdf_all), p_w_mdf, sig_mark(p_w_mdf));
fprintf('   - MNF-time : Median = %+.3f, p-value = %.4e %s\n', ...
        median(corr_mnf_all), p_w_mnf, sig_mark(p_w_mnf));

fprintf('\n2. Uji Komparatif Berpasangan Antar Parameter:\n');
fprintf('   - RMS-time vs MDF-time : p-value = %.4e %s\n', p_w_pair1, sig_mark(p_w_pair1));
fprintf('   - MDF-time vs MNF-time : p-value = %.4e %s\n', p_w_pair2, sig_mark(p_w_pair2));
fprintf('=======================================================\n');

% Simpan hasil Wilcoxon ke CSV
T_wilcoxon = table(...
    {'RMS-time vs 0'; 'MDF-time vs 0'; 'MNF-time vs 0'; 'RMS-time vs MDF-time'; 'MDF-time vs MNF-time'}, ...
    [median(corr_rms_all); median(corr_mdf_all); median(corr_mnf_all); NaN; NaN], ...
    [p_w_rms; p_w_mdf; p_w_mnf; p_w_pair1; p_w_pair2], ...
    {sig_text(p_w_rms); sig_text(p_w_mdf); sig_text(p_w_mnf); sig_text(p_w_pair1); sig_text(p_w_pair2)}, ...
    'VariableNames', {'Uji_Hipotesis', 'Median_Spearman', 'P_Value_Wilcoxon', 'Keterangan'});
writetable(T_wilcoxon, fullfile(out_base, 'wilcoxon_test_results.csv'));
fprintf('[OK] Hasil uji Wilcoxon disimpan: wilcoxon_test_results.csv\n\n');

% ---- Helper Functions ----
function s = format_pval(p)
    if p < 0.001
        s = 'P < 0.001';
    elseif p < 0.05
        s = sprintf('P = %.3f (P < 0.05)', p);
    else
        s = sprintf('P = %.3f', p);
    end
end

function s = sig_mark(p)
    if p < 0.05
        s = '(Signifikan, p < 0.05)';
    else
        s = '(Tidak Signifikan, p >= 0.05)';
    end
end

function s = sig_text(p)
    if p < 0.05
        s = 'Signifikan (p < 0.05)';
    else
        s = 'Tidak Signifikan (p >= 0.05)';
    end
end
