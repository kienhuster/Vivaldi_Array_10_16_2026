function report = runHFSSAPIIntegration(outputDir, executable, fullBuild)
    % Mục đích: kiểm tra thư viện và CAD trên Windows thật; không giả lập khi thiếu HFSS.
    % fullBuild=true bổ sung dựng anten, đổi kích thước, lưu và mở lại cùng project.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root, fullfile(root, 'core'), fullfile(root, 'automation'), fullfile(root, 'custom_helpers'), fullfile(root, 'results'));
    if nargin < 1
        outputDir = fullfile(root, 'work', 'kiem_tra_api');
    end
    if nargin < 2
        executable = VivaldiHFSS.detectExecutable();
    end
    if nargin < 3
        fullBuild = false;
    end
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end
    report = struct('status', 'PENDING', 'message', 'Cần Windows MATLAB và HFSS 2021 R2; chưa chạy kiểm thử thực tế.', ...
                    'basicAPI', 'PENDING', 'antennaCAD', 'PENDING', 'liveUpdate', 'PENDING', 'saveReopen', 'PENDING', 'solver', 'PENDING');
    if ~ispc || exist('OCTAVE_VERSION', 'builtin')
        vivaldiWriteJSON(fullfile(outputDir, 'hfss-api-integration.json'), report);
        return
    end
    backend = VivaldiHFSS(root);
    backend.Executable = executable;
    backend.Offline = false;
    p = vivaldiDefaultParams();
    [~, token] = fileparts(tempname);
    path = fullfile(outputDir, ['KiemTra_' token '.aedt']);
    try
        backend.start('compatibility', p, struct('projectPath', path));
        waitForJob(backend);
        assert(strcmp(backend.LastState, 'TESTED'), 'Vivaldi:Compatibility', '%s', backend.LastMessage);
        report.basicAPI = 'PASS';
        report.status = 'PASS';
        report.message = 'Helper thư viện, đổi biến, Box, sheet rỗng và BothSides đã chạy trên HFSS. Anten đầy đủ là kiểm tra riêng.';
        if fullBuild
            path = fullfile(outputDir, ['Anten_' token '.aedt']);
            backend.start('build', p, struct('projectPath', path));
            waitForJob(backend);
            assert(backend.Healthy, 'Vivaldi:CAD', '%s', backend.LastMessage);
            report.antennaCAD = 'PASS';
            q = p;
            q.L_flare_1 = 43.287;
            backend.start('update', q);
            waitForJob(backend);
            assert(backend.Healthy);
            q.aperture_w = 24.635;
            q.cavity_w = 1.725;
            q.thickness = 2.35;
            backend.start('update', q);
            waitForJob(backend);
            assert(backend.Healthy);
            assert(strcmp(backend.WorkingPath, path));
            report.liveUpdate = 'PASS';
            backend.start('save', q);
            waitForJob(backend);
            assert(~backend.Dirty);
            backend.start('reload', q);
            waitForJob(backend);
            VivaldiHFSS.assertParams(backend.LastValid, q);
            report.saveReopen = 'PASS';
            if strcmp(getenv('VIVALDI_RUN_SOLVER_TESTS'), '1')
                backend.start('simulate', q);
                waitForJob(backend);
                assert(strcmp(backend.LastState, 'SIMULATED'));
                report.solver = 'PASS';
            end
            report.message = 'Đã chạy CAD, cập nhật cùng project, Save/Reload. Pha port, ảnh nguồn và hội tụ RF cần đối chiếu riêng.';
        end
    catch ex
        report.status = 'FAIL';
        report.message = [ex.identifier ': ' ex.message];
    end
    backend.exportLog(fullfile(outputDir, ['chi_tiet_' token '.json']));
    vivaldiWriteJSON(fullfile(outputDir, 'hfss-api-integration.json'), report);
end

function waitForJob(backend)
    % Launcher bất đồng bộ; chỉ chấp nhận terminal đúng job hoặc báo lỗi/timeout.
    while ~isempty(backend.ActiveJob)
        pause(.25);
        drawnow;
        backend.poll();
        assert(~strcmp(backend.LastState, 'TIMED_OUT'), 'Vivaldi:Timeout', '%s', backend.LastMessage);
    end
    assert(~ismember(backend.LastState, {'FAILED', 'FAILED_ROLLED_BACK'}), 'Vivaldi:HFSS', '%s', backend.LastMessage);
end
