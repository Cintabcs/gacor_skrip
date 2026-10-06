% =========================================================
% Windowing + Ekstraksi Fitur RMS + Thresholding
% MATLAB Reference Script (berlaku Versi A & Versi B)
% Input : preprocessing/matlab/output/data/
% Output: preprocessing/matlab/output/features/
% =========================================================

Fs          = 1000;
win_ms      = 200;                           % panjang window ms
overlap_pct = 0.5;                           % 50% overlap
threshold   = 0.65;                          % 65% sesuai proposal

win_samples  = round(win_ms * Fs / 1000);    % 200 sampel
step_samples = round(win_samples * (1 - overlap_pct)); % 100 sampel

prep_dir  = 'C:\Users\FILKOM\Downloads\utama\preprocessing\versi_A\matlab\output\data';
out_base  = 'C:\Users\FILKOM\Downloads\utama\preprocessing\versi_A\matlab\output\features';
out_data  = fullfile(out_base, 'data');
out_plots = fullfile(out_base, 'plots');

if ~exist(out_data,  'dir'); mkdir(out_data);  end
if ~exist(out_plots, 'dir'); mkdir(out_plots); end

files = dir(fullfile(prep_dir, '**', '*.csv'));
fprintf('Ditemukan %d file preprocessed.\n\n', length(files));
fprintf('Konfigurasi: Window=%dms | Overlap=%d%% | Threshold=%.2f\n\n', ...
        win_ms, round(overlap_pct*100), threshold);

summary_filenames   = {};
summary_n_samples   = [];
summary_n_windows   = [];
summary_rms_max     = [];
summary_rms_mean    = [];
summary_n_kontr     = [];
summary_n_relax     = [];
summary_pct_kontr   = [];

for i = 1:length(files)
    fpath = fullfile(files(i).folder, files(i).name);
    fname = files(i).name;
    fprintf('  Feature: %s\n', fname);

    try
        df = readtable(fpath);
    catch
        fprintf('    -> Skip: gagal dibaca\n'); continue;
    end
    if ~ismember('Preprocessed_EMG', df.Properties.VariableNames)
        fprintf('    -> Skip: kolom Preprocessed_EMG tidak ada\n'); continue;
    end

    sig = df.Preprocessed_EMG;
    if any(~isfinite(sig)) || length(sig) < win_samples
        fprintf('    -> Skip: data tidak valid\n'); continue;
    end

    % --- Windowing + RMS ---
    n_windows = floor((length(sig) - win_samples) / step_samples) + 1;
    rms_arr   = zeros(n_windows, 1);
    t_arr     = zeros(n_windows, 1);

    for w = 1:n_windows
        idx_start = (w-1)*step_samples + 1;
        idx_end   = idx_start + win_samples - 1;
        window_data = sig(idx_start:idx_end);
        rms_arr(w)  = sqrt(mean(window_data .^ 2));
        t_arr(w)    = (idx_start + win_samples/2 - 1) / Fs;
    end

    % --- Normalisasi & Klasifikasi ---
    rms_max  = max(rms_arr);
    if rms_max == 0; rms_max = 1; end
    rms_norm = rms_arr / rms_max;
    labels   = repmat({'Relaksasi'}, n_windows, 1);
    labels(rms_norm >= threshold) = {'Kontraksi'};

    n_kontr = sum(strcmp(labels, 'Kontraksi'));
    n_relax = n_windows - n_kontr;

    % --- Simpan CSV fitur ---
    T_feat = table(t_arr, rms_arr, repmat(rms_max,n_windows,1), rms_norm, labels, ...
        'VariableNames', {'Time_s','RMS','RMS_max','RMS_norm','Class'});
    writetable(T_feat, fullfile(out_data, fname));

    % --- Plot ---
    time_sig = (0:length(sig)-1)' / Fs;
    mask_k   = strcmp(labels, 'Kontraksi');

    fig = figure('Visible','off','Position',[100 100 1200 800]);

    subplot(3,1,1);
    plot(time_sig, sig,'Color',[0.27 0.51 0.71],'LineWidth',0.5);
    title(sprintf('Preprocessed EMG — %s', strrep(fname,'_','\_')));
    xlabel('Waktu (s)'); ylabel('Amplitudo'); grid on;

    subplot(3,1,2);
    plot(t_arr, rms_arr,'-o','Color',[1 0.55 0],'LineWidth',1,'MarkerSize',2);
    title('RMS per Window (200 ms, 50% overlap)');
    xlabel('Waktu (s)'); ylabel('RMS'); grid on;

    subplot(3,1,3);
    plot(t_arr, rms_norm,'-','Color',[0.5 0.5 0.5],'LineWidth',1); hold on;
    yline(threshold,'--r',sprintf('Threshold = %.2f', threshold),'LineWidth',1.2);
    scatter(t_arr(mask_k),  rms_norm(mask_k),  15,'g','filled','DisplayName','Kontraksi');
    scatter(t_arr(~mask_k), rms_norm(~mask_k), 10,'r','filled','DisplayName','Relaksasi');
    title('RMS Ternormalisasi & Klasifikasi');
    xlabel('Waktu (s)'); ylabel('RMS Norm');
    legend('Location','best','FontSize',8); grid on;

    saveas(fig, fullfile(out_plots, strrep(fname,'.csv','.png')));
    close(fig);

    summary_filenames{end+1} = fname;
    summary_n_samples(end+1) = length(sig);
    summary_n_windows(end+1) = n_windows;
    summary_rms_max(end+1)   = rms_max;
    summary_rms_mean(end+1)  = mean(rms_arr);
    summary_n_kontr(end+1)   = n_kontr;
    summary_n_relax(end+1)   = n_relax;
    summary_pct_kontr(end+1) = 100 * n_kontr / n_windows;
end

T_sum = table(summary_filenames', summary_n_samples', summary_n_windows', ...
    summary_rms_max', summary_rms_mean', summary_n_kontr', summary_n_relax', ...
    summary_pct_kontr', ...
    'VariableNames',{'Filename','N_Samples','N_Windows','RMS_max','RMS_mean', ...
                     'N_Kontraksi','N_Relaksasi','Pct_Kontraksi'});
writetable(T_sum, fullfile(out_base, 'feature_summary.csv'));

fprintf('\n===== RINGKASAN FITUR =====\n');
fprintf('File diproses        : %d\n', length(summary_filenames));
fprintf('Total window         : %d\n', sum(summary_n_windows));
fprintf('Rata-rata %%Kontraksi : %.2f%%\n', mean(summary_pct_kontr));
fprintf('===========================\n');
fprintf('\nSelesai! Output ada di: %s\n', out_base);
