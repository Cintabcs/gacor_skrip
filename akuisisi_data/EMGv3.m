classdef EMGv3 < matlab.apps.AppBase

    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        ClassificationEditField       matlab.ui.control.EditField
        ClassificationEditFieldLabel  matlab.ui.control.Label
        RMSEditField                  matlab.ui.control.NumericEditField
        RMSEditFieldLabel             matlab.ui.control.Label
        ElapsedTimeEditField          matlab.ui.control.NumericEditField
        ElapsedTimeEditFieldLabel     matlab.ui.control.Label
        StopButton                    matlab.ui.control.Button
        StartButton                   matlab.ui.control.Button
        Label                         matlab.ui.control.Label
        MuscleActivityDetectionLabel  matlab.ui.control.Label
        UIAxes                        matlab.ui.control.UIAxes
    end

    properties (Access = private)
        SerialObj
        COMPort   = "COM10"
        Fs        = 1000;
        Baud      = 115200;
        EMGsignal = []
        stopFlag  = false
        CSVData
        CSVFileName
        b_notch
        a_notch
    end

    methods (Access = private)

        function buildFilter(app)
            f0 = 50; fn = app.Fs / 2;
            w0 = 2 * pi * f0 / app.Fs;
            bw = 0.1;
            nz = [exp(1i*w0), exp(-1i*w0)];
            np = (1 - bw) * nz;
            app.b_notch = real(poly(nz));
            app.a_notch = real(poly(np));
        end

        function initESP32(app)
            clc;
            plist = serialportfind;
            if ~isempty(plist); delete(plist); end
            app.SerialObj = serialport(app.COMPort, app.Baud, "Timeout", 10);
            configureTerminator(app.SerialObj, "LF");
            flush(app.SerialObj);
            disp("ESP32 terhubung di " + app.COMPort);
        end

        function main(app)
            tStart    = tic;
            winPlot   = app.Fs;
            maxData   = 2000000;
            tArr      = zeros(maxData, 1);
            rawArr    = zeros(maxData, 1);
            n         = 0;
            tLastPlot = tic;

            while ~app.stopFlag
                nBytes = app.SerialObj.NumBytesAvailable;
                if nBytes > 0
                    nLines = max(1, floor(nBytes / 8));
                    for k = 1:nLines
                        if app.SerialObj.NumBytesAvailable < 1; break; end
                        raw = str2double(strtrim(readline(app.SerialObj)));
                        if isfinite(raw)
                            n = n + 1;
                            rawArr(n) = raw;
                            tArr(n)   = toc(tStart);
                            app.EMGsignal(end+1) = raw;
                        end
                    end

                    if numel(app.EMGsignal) > app.Fs * 2
                        app.EMGsignal(1:end - app.Fs*2) = [];
                    end

                    if toc(tLastPlot) >= 0.1 && n > 0
                        tLastPlot = tic;

                        % --- Plot ---
                        sig = app.EMGsignal;
                        if numel(sig) > winPlot
                            sig = sig(end - winPlot + 1:end);
                        end
                        plot(app.UIAxes, (1:numel(sig))/app.Fs, sig);
                        xlabel(app.UIAxes, "Waktu (s)");
                        ylabel(app.UIAxes, "mV");
                        title(app.UIAxes, "Sinyal EMG Real-Time");
                        drawnow limitrate;

                        % --- Elapsed Time ---
                        et = tArr(n);
                        if isfinite(et) && et >= 0
                            app.ElapsedTimeEditField.Value = et;
                        end

                        % --- RMS & Klasifikasi ---
                        if numel(app.EMGsignal) >= round(app.Fs * 0.2)
                            app.updateRMSUI();
                        end
                    end
                else
                    % Jika belum ada data masuk, beri jeda agar UI tidak macet
                    pause(0.005);
                    drawnow limitrate;
                end
            end

            % =============================================
            % POST-PROCESSING setelah Stop
            % =============================================
            disp("Stop ditekan. Memproses dan menyimpan data...");
            tArr   = tArr(1:n);
            rawArr = rawArr(1:n);

            if n > 0
                emgC = rawArr - mean(rawArr);
                filt = real(filter(app.b_notch, app.a_notch, emgC));

                ws = round(app.Fs * 0.2);
                if n >= ws
                    allRMS = sqrt(movmean(filt.^2, [ws-1 0]));
                else
                    allRMS = zeros(n, 1);
                end

                allNorm   = allRMS / 13;
                % Klasifikasi label - pastikan bentuk kolom konsisten
                allLabels = cell(n, 1);
                for li = 1:n
                    if allNorm(li) >= 0.54
                        allLabels{li} = 'Kontraksi';
                    else
                        allLabels{li} = 'Relaksasi';
                    end
                end

                wkt = repmat(string(datetime('now','Format','dd-MM-yyyy HH:mm:ss')), n, 1);
                WaktuNyata  = wkt;
                ElapsedTime = tArr;
                Raw         = rawArr;
                Filtered    = filt;
                RMS         = allRMS;
                RMSNorm     = allNorm;
                Class       = allLabels;
                app.CSVData = table(WaktuNyata, ElapsedTime, Raw, Filtered, RMS, RMSNorm, Class);

                folder = "C:\Users\FILKOM\Downloads\utama\Data_CSV";
                if ~exist(folder, 'dir'); mkdir(folder); end
                fname = fullfile(folder, ['Hasil' datestr(now,'yyyymmdd_HHMMSS') '.csv']);
                app.CSVFileName = fname;
                writetable(app.CSVData, fname);
                disp("=== SELESAI! " + n + " baris tersimpan di: " + fname + " ===");
            else
                disp("Tidak ada data yang terekam.");
            end

            delete(app.SerialObj);
            disp("ESP32 disconnected.");
        end

        function updateRMSUI(app)
            sig = app.EMGsignal;
            if numel(sig) > app.Fs
                sig = sig(end - app.Fs + 1:end);
            end
            sig  = sig - mean(sig);
            filt = real(filter(app.b_notch, app.a_notch, sig));
            ws   = round(app.Fs * 0.2);
            if numel(filt) < ws; return; end
            rmsVal = sqrt(mean(filt(end - ws + 1:end).^2));
            if ~isfinite(rmsVal); rmsVal = 0; end
            rmsN = rmsVal / 13;

            if rmsN < 0.65
                app.ClassificationEditField.BackgroundColor = [1 0 0];
                app.ClassificationEditField.Value = 'Relaksasi';
            else
                app.ClassificationEditField.BackgroundColor = [0 1 0];
                app.ClassificationEditField.Value = 'Kontraksi';
            end
            app.RMSEditField.Value = rmsVal;
        end
    end

    % Callbacks
    methods (Access = private)

        function startupFcn(~)
        end

        function StartButtonPushed(app, ~)
            app.stopFlag  = false;
            app.EMGsignal = [];
            app.buildFilter();
            app.initESP32();
            app.main();
        end

        function StopButtonPushed(app, ~)
            app.stopFlag = true;
        end
    end

    % Komponen UI
    methods (Access = private)

        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'EMG v3 - Muscle Activity Detection';

            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'EMG Signal')
            xlabel(app.UIAxes, 'Time (s)')
            ylabel(app.UIAxes, 'Amplitude (mV)')
            app.UIAxes.Position = [20 128 604 208];

            app.MuscleActivityDetectionLabel = uilabel(app.UIFigure);
            app.MuscleActivityDetectionLabel.HorizontalAlignment = 'center';
            app.MuscleActivityDetectionLabel.FontSize = 24;
            app.MuscleActivityDetectionLabel.FontWeight = 'bold';
            app.MuscleActivityDetectionLabel.Position = [171 417 299 31];
            app.MuscleActivityDetectionLabel.Text = 'Muscle Activity Detection';

            app.Label = uilabel(app.UIFigure);
            app.Label.HorizontalAlignment = 'center';
            app.Label.Position = [118 400 409 22];
            app.Label.Text = 'Real-Time Estimation of Muscle Activity Based on Electromyogram Signals';

            app.StartButton = uibutton(app.UIFigure, 'push');
            app.StartButton.ButtonPushedFcn = createCallbackFcn(app, @StartButtonPushed, true);
            app.StartButton.Position = [49 344 70 22];
            app.StartButton.Text = 'Start';

            app.StopButton = uibutton(app.UIFigure, 'push');
            app.StopButton.ButtonPushedFcn = createCallbackFcn(app, @StopButtonPushed, true);
            app.StopButton.Position = [130 344 70 22];
            app.StopButton.Text = 'Stop';

            app.ElapsedTimeEditFieldLabel = uilabel(app.UIFigure);
            app.ElapsedTimeEditFieldLabel.HorizontalAlignment = 'right';
            app.ElapsedTimeEditFieldLabel.Position = [411 343 78 22];
            app.ElapsedTimeEditFieldLabel.Text = 'Elapsed Time';

            app.ElapsedTimeEditField = uieditfield(app.UIFigure, 'numeric');
            app.ElapsedTimeEditField.Limits = [0 86400];
            app.ElapsedTimeEditField.HorizontalAlignment = 'center';
            app.ElapsedTimeEditField.Position = [510 343 95 24];

            app.RMSEditFieldLabel = uilabel(app.UIFigure);
            app.RMSEditFieldLabel.HorizontalAlignment = 'right';
            app.RMSEditFieldLabel.Position = [130 64 32 22];
            app.RMSEditFieldLabel.Text = 'RMS';

            app.RMSEditField = uieditfield(app.UIFigure, 'numeric');
            app.RMSEditField.Limits = [0 1000];
            app.RMSEditField.HorizontalAlignment = 'center';
            app.RMSEditField.Position = [183 64 95 24];

            app.ClassificationEditFieldLabel = uilabel(app.UIFigure);
            app.ClassificationEditFieldLabel.HorizontalAlignment = 'right';
            app.ClassificationEditFieldLabel.Position = [443 107 76 22];
            app.ClassificationEditFieldLabel.Text = 'Classification';

            app.ClassificationEditField = uieditfield(app.UIFigure, 'text');
            app.ClassificationEditField.HorizontalAlignment = 'center';
            app.ClassificationEditField.Position = [364 19 233 89];

            app.UIFigure.Visible = 'on';
        end
    end

    % Konstruktor & destruktor
    methods (Access = public)

        function app = EMGv3
            createComponents(app)
            registerApp(app, app.UIFigure)
            runStartupFcn(app, @startupFcn)
            if nargout == 0; clear app; end
        end

        function delete(app)
            delete(app.UIFigure)
        end
    end
end
