classdef VivaldiHFSS < handle
    % Mục đích: điều phối hfss-api → VBScript → HFSS, theo dõi job bằng status.
    % Không giữ COM handle trong MATLAB; mã trả về launcher không chứng minh CAD đúng.
    properties
        Root
        ReferencePath
        WorkingPath = ''
        Executable = ''
        Offline = false
        ActiveJob = []
        LastJob = []
        LastValid = []
        LastSaved = []
        Healthy = false
        Dirty = false
        Connected = false
        Version = ''
        LastState = 'PENDING'
        LastMessage = 'Chưa có phản hồi HFSS.'
        ResultsState = 'Chưa mô phỏng'
        ResultSignature = ''
        LastReports = struct('label', {}, 'path', {})
        LastObjects = {}
        LastSimulation = []
        TimeoutSeconds = 600
        Records = struct('step', {}, 'execution', {}, 'geometry', {}, 'message', {})
    end
    methods

        function o = VivaldiHFSS(root)
            o.Root = root;
            o.ReferencePath = fullfile(root, 'reference', '17_10_2026_vivaldi.aedt');
            apiRoot = fullfile(root, 'third_party', 'hfss-api');
            addpath(apiRoot);
            hfssIncludePaths([apiRoot filesep]);
            o.Offline = ~ispc;
            o.Executable = o.detectExecutable();
        end

        function path = checkPath(o, path, mustBeNew)
            if nargin < 3
                mustBeNew = false;
            end
            path = vivaldiCanonicalPath(path);
            [folder, name, ext] = fileparts(path);
            assert(strcmpi(ext, '.aedt'), 'Vivaldi:Path', 'Đường dẫn phải có phần mở rộng .aedt.');
            reference = vivaldiCanonicalPath(o.ReferencePath);
            assert(~strcmpi(path, reference) && ~strcmpi(name, '17_10_2026_vivaldi') && ~strcmpi(folder, fileparts(reference)), ...
                   'Vivaldi:Reference', 'Không điều khiển hoặc ghi đè file/thư mục tham chiếu.');
            if mustBeNew
                assert(~isfile(path) && ~isfile([path '.lock']) && ~isfolder([path 'results']), 'Vivaldi:Exists', 'Đích đã tồn tại hoặc đang có khóa/kết quả. Chọn tên mới.');
            end
        end

        function copyReference(o, path)
            % Chỉ sửa literal có vấn đề trên bản sao riêng, giữ nguyên nguồn.
            assert(isempty(o.ActiveJob), 'Vivaldi:Busy', 'Đợi job hiện tại hoàn tất.');
            path = o.checkPath(path, true);
            text = fileread(o.ReferencePath);
            first = strfind(text, 'Name=''cable_mid_1''');
            assert(numel(first) == 1, 'Vivaldi:Source', 'Không xác định được middle cutter nguồn.');
            stop = strfind(text(first:end), '$end ''GeometryPart''');
            stop = first + stop(1) - 2;
            block = text(first:stop);
            old = 'TranslateVectorY=''2mm''';
            assert(numel(strfind(block, old)) == 1, 'Vivaldi:Source', 'Lịch sử Move của nguồn không khớp.');
            block = strrep(block, old, 'TranslateVectorY=''thickness''');
            text = [text(1:first - 1), block, text(stop + 1:end)];
            fid = fopen(path, 'w', 'n', 'UTF-8');
            assert(fid >= 0, 'Vivaldi:Write', 'Không ghi được bản sao.');
            cleanup = onCleanup(@()fclose(fid));
            fprintf(fid, '%s', text); %#ok<NASGU>
            o.WorkingPath = path;
            o.Healthy = false;
            o.LastValid = [];
            o.LastSaved = [];
            o.LastMessage = 'Đã tạo bản sao, chuẩn hóa Move middle cutter 2mm → thickness; cần Mở dự án và kiểm tra HFSS.';
        end

        function job = generate(o, action, p, cfg)
            % Sinh script không khởi chạy HFSS, dùng được trên Linux để kiểm thử.
            if nargin < 4
                cfg = struct();
            end
            cfg = o.configuration(action, p, cfg);
            p = cfg.params;
            w = VivaldiScriptWriter();
            w.stage('BAT_DAU');
            bootstrap(w, action, cfg);
            rb = VivaldiScriptWriter();
            rb.ErrorMode = 'raise';
            if ismember(action, {'build', 'compatibility'})
                w.lib(@hfssInsertDesign, {cfg.designName, 'driven modal'});
                % Chỉ lưu shell rỗng để định danh. CAD lỗi không tự lưu.
                w.require(['Not fs.FileExists(' w.q(cfg.projectPath) ')'], 'Đích dựng mới đã xuất hiện; không ghi đè');
                w.lib(@hfssSaveProject, {cfg.projectPath, false});
                if strcmp(action, 'compatibility')
                    compatibilityModel(w, p);
                else
                    VivaldiBuilder(w, p, cfg.simulation);
                end
            elseif strcmp(action, 'connect')
                % Chỉ xác minh Desktop/version; không tạo/mở project.
            else
                attach(w, cfg);
                switch action
                    case {'open', 'validate', 'restore'}
                        if strcmp(action, 'restore')
                            hfssVivaldiExtensions(w, 'variables', p, false, fieldnames(p));
                        end
                        VivaldiValidation('full', w, p, true);
                    case 'update'
                        % Xác minh baseline trước mutation; rollback dùng cùng design.
                        VivaldiValidation('variables', w, cfg.before);
                        if p.thickness ~= cfg.before.thickness
                            assert(~o.hasLiteralMove(cfg.projectPath), 'Vivaldi:LiteralMove', 'Working Project còn Move 2mm. Tạo bản sao chuẩn hóa hoặc dựng mới trước khi đổi thickness.');
                        end
                        names = fieldnames(p);
                        names = names(cellfun(@(n)p.(n) ~= cfg.before.(n), names));
                        w.line('vRollbackEnabled = True');
                        hfssVivaldiExtensions(w, 'variables', p, false, names);
                        VivaldiValidation('full', w, p, true);
                        w.line('vRollbackEnabled = False');
                        hfssVivaldiExtensions(rb, 'variables', cfg.before, false, names);
                        VivaldiValidation('full', rb, cfg.before, true);
                        VivaldiValidation('parameters', rb);
                    case {'save', 'saveas'}
                        VivaldiValidation('full', w, p, true);
                        if strcmp(action, 'save')
                            w.call('oProject.Save', 'Lưu Working Project hiện tại');
                        else
                            w.require(['Not fs.FileExists(' w.q(cfg.destination) ')'], 'Đích Save As đã tồn tại');
                            w.lib(@hfssSaveProject, {cfg.destination, false});
                        end
                        w.require(['fs.FileExists(' w.q(cfg.destination) ')'], 'File AEDT chưa được lưu');
                    case 'simulate'
                        VivaldiValidation('full', w, p, true);
                        VivaldiSimulation('run', w, cfg.simulation);
                        VivaldiValidation('variables', w, p);
                    case 'reports'
                        VivaldiValidation('variables', w, p);
                        VivaldiSimulation('reports', w, cfg.simulation, cfg.resultsDir, cfg.id);
                    case 'reload'
                        % Reload có xác nhận GUI; đóng đúng working project rồi mở lại.
                        w.call(['oDesktop.CloseProject ' w.q(cfg.projectName)], 'Bỏ thay đổi chưa lưu và mở lại bản lưu');
                        attach(w, cfg);
                        VivaldiValidation('full', w, p, true);
                    case 'window'
                        w.call('oDesktop.RestoreWindow', 'Đưa cửa sổ HFSS ra trước');
                    case 'objects'
                        w.call('WriteStatus "OBJECTS|" & Join(ObjectNames(),",")', 'Đọc cây đối tượng HFSS');
                    otherwise
                        error('Vivaldi:Action', 'Thao tác chưa hỗ trợ: %s.', action);
                end
            end
            if ~strcmp(action, 'connect')
                VivaldiValidation('parameters', w);
            end
            w.line('WriteStatus "VERIFIED|1"');
            w.line(['WriteStatus "STATE|' cfg.terminal '"']);
            job = struct('id', cfg.id, 'action', action, 'cfg', cfg, 'params', p, 'before', cfg.before, ...
                         'scriptPath', cfg.scriptPath, 'statusPath', cfg.statusPath, 'process', [], ...
                         'startedAt', now, 'timeoutSeconds', cfg.timeoutSeconds, 'helpers', {unique([w.UsedHelpers rb.UsedHelpers])}, 'acknowledged', false);
            runtime = fileread(fullfile(o.Root, 'automation', 'VivaldiRuntime.vbs'));
            declarations = ['Option Explicit' newline ...
                            'Dim fs,oHfssApp,oDesktop,oProject,oDesign,oEditor,oModule,oBoundary,oMaterials,oSolutions,oReport' newline ...
                            'Dim sbErr,sbDesc,sbCondition,sbHasData,vStage,vJobId,vStatusPath,vRollbackEnabled,vDebug,vOpened,vVersion' newline ...
                            'SetLocale 1033' newline 'Set fs = CreateObject("Scripting.FileSystemObject")' newline];
            init = ['vStatusPath = ' w.q(cfg.statusPath) newline 'vJobId = ' w.q(cfg.id) newline ...
                    'vDebug = ' w.literal(cfg.debug) newline 'vRollbackEnabled = False' newline ...
                    'CreateStatus' newline 'Main' newline];
            create = ['Sub CreateStatus' newline '  Dim stream' newline ...
                      '  Set stream = fs.CreateTextFile(vStatusPath,True,True)' newline ...
                      '  stream.WriteLine "JOB|" & vJobId' newline '  stream.Close' newline 'End Sub' newline];
            content = [declarations init runtime newline create ...
                       'Sub RestorePrevious' newline strjoin(rb.Lines, newline) newline 'End Sub' newline ...
                       'Sub Main' newline strjoin(w.Lines, newline) newline 'End Sub' newline];
            o.writeUTF16(cfg.scriptPath, content);
            vivaldiWriteJSON([cfg.scriptPath '.json'], struct('action', action, 'helpers', {job.helpers}, 'parameters', p, ...
                                                              'architecture', 'hfss-api -> VBScript -> HFSS; không phải persistent COM trong MATLAB', ...
                                                              'runtimeStatus', 'PENDING', 'id', cfg.id));
        end

        function job = start(o, action, p, cfg)
            if nargin < 4
                cfg = struct();
            end
            assert(isempty(o.ActiveJob), 'Vivaldi:Busy', 'Job trước chưa xác nhận kết thúc; kiểm tra lại trạng thái trước.');
            if ~o.Offline
                assert(ispc && usejava('jvm'), 'Vivaldi:Windows', 'Cần Windows MATLAB có JVM để chạy HFSS.');
                assert(isfile(o.Executable), 'Vivaldi:Executable', 'Chọn ansysedt.exe hợp lệ trong menu Nâng cao.');
                [~, name, ext] = fileparts(o.Executable);
                assert(strcmpi([name ext], 'ansysedt.exe'), 'Vivaldi:Executable', 'Cần chọn ansysedt.exe.');
            end
            if ismember(action, {'update', 'save', 'saveas', 'simulate', 'reports', 'restore'})
                assert(~isempty(o.LastValid), 'Vivaldi:Baseline', 'Mở/dựng dự án và xác nhận geometry trước.');
                if ~strcmp(action, 'restore')
                    assert(o.Healthy, 'Vivaldi:Geometry', 'Mô hình chưa được xác nhận; phục hồi hoặc mở lại bản lưu.');
                end
                selected = o.WorkingPath;
                if isfield(cfg, 'projectPath')
                    selected = cfg.projectPath;
                end
                assert(strcmpi(o.checkPath(selected, false), o.WorkingPath), 'Vivaldi:WorkingProject', ...
                       'Đường dẫn đã đổi; Mở dự án và kiểm tra trước khi cập nhật/lưu/mô phỏng.');
                cfg.before = o.LastValid;
            end
            if strcmp(action, 'reports')
                assert(strcmp(o.ResultSignature, jsonencode(o.LastValid)), 'Vivaldi:Stale', 'Kết quả đã cũ hoặc chưa giải trong phiên này. Chạy mô phỏng trước.');
                cfg.simulation = o.LastSimulation;
            end
            job = o.generate(action, p, cfg);
            o.LastJob = job;
            if o.Offline
                o.LastState = 'SCRIPT_READY';
                o.LastMessage = ['Chỉ tạo kịch bản, chưa chạy HFSS: ' job.scriptPath];
                return
            end
            if ismember(action, {'update', 'restore', 'simulate'})
                o.ResultsState = 'Kết quả đã cũ — cần mô phỏng lại';
                o.ResultSignature = '';
                o.Dirty = true;
            end
            if ismember(action, {'build', 'open', 'reload'})
                o.Healthy = false;
            end
            [code, process] = hfssExecuteScript(o.Executable, job.scriptPath, false, false, false);
            assert(code == 0, 'Vivaldi:Launch', 'Không khởi chạy được HFSS.');
            job.process = process;
            job.startedAt = now;
            o.ActiveJob = job;
            o.LastJob = job;
            o.LastState = 'RUNNING';
            o.LastMessage = 'Đã gửi script; đang chờ xác nhận HFSS, chưa kết luận thành công.';
        end

        function changed = poll(o)
            changed = false;
            if isempty(o.ActiveJob)
                return
            end
            job = o.ActiveJob;
            data = o.readStatus(job.statusPath, job.id);
            if data.acknowledged
                o.Records = data.records;
                job.acknowledged = true;
                o.ActiveJob = job;
                changed = true;
                if ~isempty(data.version)
                    o.Version = data.version;
                end
                if ~isempty(data.state)
                    if ismember(data.state, {'FAILED', 'FAILED_ROLLED_BACK'})
                        o.LastState = data.state;
                        o.LastMessage = 'HFSS báo thao tác thất bại; xem nhật ký. Không tự lưu mô hình lỗi.';
                        o.Healthy = false;
                        if strcmp(data.state, 'FAILED_ROLLED_BACK')
                            actual = o.paramsFromRecords(data.params);
                            o.assertParams(actual, job.before);
                            o.LastValid = job.before;
                            o.Healthy = true;
                            o.LastMessage = 'Cập nhật thất bại; đã phục hồi và kiểm tra lại bộ biến trước.';
                        end
                        o.LastJob = job;
                        o.ActiveJob = [];
                        return
                    end
                    assert(strcmp(data.state, job.cfg.terminal) && data.verified, 'Vivaldi:Status', 'Status chưa đủ bằng chứng cho thao tác hiện tại.');
                    if ~ismember(job.action, {'connect', 'window', 'objects'})
                        actual = o.paramsFromRecords(data.params);
                        o.assertParams(actual, job.params);
                    end
                    o.Connected = true;
                    o.LastMessage = 'HFSS đã phản hồi và hoàn thành các kiểm tra được ghi trong nhật ký.';
                    if ismember(job.action, {'build', 'open', 'reload', 'update', 'validate', 'restore'})
                        o.WorkingPath = job.cfg.projectPath;
                        o.LastValid = job.params;
                        o.Healthy = true;
                        if ~strcmp(job.action, 'validate')
                            o.ResultsState = 'Chưa mô phỏng';
                            o.ResultSignature = '';
                            if ismember(job.action, {'open', 'reload'})
                                o.Dirty = false;
                                o.LastSaved = job.params;
                            else
                                o.Dirty = true;
                            end
                        end
                    end
                    if ismember(job.action, {'save', 'saveas'})
                        o.verifySaved(job.cfg.destination, job.params);
                        o.WorkingPath = job.cfg.destination;
                        o.LastSaved = job.params;
                        o.Dirty = false;
                    end
                    if strcmp(job.action, 'simulate')
                        o.ResultSignature = jsonencode(job.params);
                        o.LastSimulation = job.cfg.simulation;
                        o.ResultsState = 'Có dữ liệu thực — cần xem hội tụ trong HFSS';
                    end
                    if strcmp(job.action, 'objects')
                        o.LastObjects = data.objects;
                        o.LastMessage = ['Đối tượng HFSS: ' strjoin(data.objects, ', ')];
                    end
                    if strcmp(job.action, 'reports')
                        o.LastReports = data.reports;
                        vivaldiWriteJSON(fullfile(job.cfg.resultsDir, [job.id '_metadata.json']), ...
                                         struct('project', job.cfg.projectPath, 'parameters', job.params, 'simulation', job.cfg.simulation, 'version', o.Version, 'reports', data.reports));
                    end
                    if ismember(job.action, {'build', 'open', 'reload', 'update', 'validate', 'restore', 'save', 'saveas'})
                        o.Healthy = true;
                    end
                    o.LastState = data.state;
                    o.LastJob = job;
                    o.ActiveJob = [];
                    return
                end
            end
            if (now - job.startedAt) * 86400 > job.timeoutSeconds
                o.LastState = 'TIMED_OUT';
                o.Healthy = false;
                o.LastMessage = 'Quá thời gian chờ. Job vẫn chưa xác nhận kết thúc; không gửi thao tác mới. Chọn Kiểm tra lại trạng thái hoặc xem HFSS.';
                changed = true;
            end
        end

        function exportLog(o, path)
            % Xuất log có bằng chứng runtime; job chỉ sinh script vẫn ghi PENDING.
            report = struct('state', o.LastState, 'message', o.LastMessage, 'records', o.Records, 'job', []);
            if ~isempty(o.LastJob)
                report.job = rmfield(o.LastJob, 'process');
            end
            [~, ~, ext] = fileparts(path);
            if strcmpi(ext, '.json')
                vivaldiWriteJSON(path, report);
                return
            end
            fid = fopen(path, 'w', 'n', 'UTF-8');
            assert(fid >= 0, 'Vivaldi:Log', 'Không ghi được nhật ký.');
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            fprintf(fid, 'Vivaldi — hfss-api/VBScript\nTrạng thái: %s\n%s\n', o.LastState, o.LastMessage);
            for k = 1:numel(o.Records)
                r = o.Records(k);
                fprintf(fid, '%s | thực thi=%s | hình học=%s | %s\n', r.step, r.execution, r.geometry, r.message);
            end
        end

        function cfg = configuration(o, action, p, cfg)
            % Kiểm tra đường dẫn và baseline trước khi mở tệp script.
            defaults = struct('projectPath', o.WorkingPath, 'destination', '', 'resultsDir', '', ...
                              'simulation', VivaldiSimulation('defaults'), 'before', [], 'debug', false, 'timeoutSeconds', o.TimeoutSeconds);
            for n = fieldnames(defaults)'
                if ~isfield(cfg, n{1})
                    cfg.(n{1}) = defaults.(n{1});
                end
            end
            VivaldiSimulation('validate', cfg.simulation);
            if strcmp(action, 'connect') && isempty(cfg.projectPath)
                cfg.projectPath = fullfile(o.Root, 'work', 'KiemTra.aedt');
            end
            if ~strcmp(action, 'connect')
                cfg.projectPath = o.checkPath(cfg.projectPath, ismember(action, {'build', 'compatibility'}));
                if ~ismember(action, {'build', 'compatibility'})
                    assert(isfile(cfg.projectPath), 'Vivaldi:Missing', 'Working Project không tồn tại.');
                end
                if ismember(action, {'open', 'reload'})
                    p = o.paramsFromFile(cfg.projectPath);
                end
                [ok, e] = vivaldiValidateParams(p);
                assert(ok, 'Vivaldi:Parameters', '%s', strjoin(e, newline));
            end
            if strcmp(action, 'update')
                assert(isstruct(cfg.before) && ~isempty(cfg.before), 'Vivaldi:Baseline', 'Thiếu bộ biến trước cập nhật.');
            end
            if strcmp(action, 'saveas')
                cfg.destination = o.checkPath(cfg.destination, true);
            else
                cfg.destination = cfg.projectPath;
            end
            if strcmp(action, 'reports')
                assert(isfolder(cfg.resultsDir), 'Vivaldi:Folder', 'Chọn thư mục kết quả hợp lệ.');
            end
            folder = fullfile(o.Root, 'work');
            if ~isfolder(folder)
                mkdir(folder);
            end
            [~, token] = fileparts(tempname(folder));
            cfg.id = ['VDB_' token];
            cfg.scriptPath = fullfile(folder, [cfg.id '_' action '.vbs']);
            cfg.statusPath = [cfg.scriptPath '.status'];
            cfg.designName = 'dual_pol_vivaldi_patch_Wflare_20';
            [~, cfg.projectName] = fileparts(cfg.projectPath);
            terminals = struct('connect', 'CONNECTED', 'compatibility', 'TESTED', 'build', 'BUILT', 'open', 'ATTACHED', 'reload', 'ATTACHED', ...
                               'update', 'UPDATED', 'validate', 'VALIDATED', 'restore', 'RESTORED', 'save', 'SAVED', 'saveas', 'SAVED', ...
                               'simulate', 'SIMULATED', 'reports', 'REPORTS', 'window', 'WINDOW', 'objects', 'OBJECTS');
            assert(isfield(terminals, action), 'Vivaldi:Action', 'Thao tác không hợp lệ.');
            cfg.terminal = terminals.(action);
            cfg.params = p;
            if strcmp(action, 'simulate') && cfg.timeoutSeconds == o.TimeoutSeconds
                cfg.timeoutSeconds = 14400;
            end
        end

    end
    methods (Static)

        function out = detectExecutable()
            % Chỉ dò vị trí thông dụng, không cố định đường dẫn ổ D.
            out = '';
            roots = {getenv('ANSYSEM_ROOT212'), getenv('ANSYSEM_ROOT'), getenv('ProgramFiles'), getenv('ProgramFiles(x86)'), ...
                     'C:\Program Files', 'D:\Program Files'};
            endings = {'ansysedt.exe', fullfile('Win64', 'ansysedt.exe'), ...
                       fullfile('AnsysEM', 'AnsysEM21.2', 'Win64', 'ansysedt.exe'), fullfile('AnsysEM21.2', 'Win64', 'ansysedt.exe'), ...
                       fullfile('ANSYS Inc', 'v212', 'AnsysEM', 'Win64', 'ansysedt.exe')};
            for r = roots
                if isempty(r{1})
                    continue
                end
                for e = endings
                    path = fullfile(r{1}, e{1});
                    if isfile(path)
                        out = path;
                        return
                    end
                end
            end
        end

        function p = paramsFromFile(path)
            info = vivaldiInspectReference(path);
            [p, meta] = vivaldiDefaultParams();
            for k = 1:numel(meta)
                row = find(strcmp(info.variables(:, 1), meta(k).name));
                assert(isscalar(row), 'Vivaldi:Variables', 'Biến %s không duy nhất.', meta(k).name);
                p.(meta(k).name) = VivaldiHFSS.literalNumber(info.variables{row, 2}, meta(k).unit);
            end
        end

        function p = paramsFromRecords(records)
            [p, meta] = vivaldiDefaultParams();
            for k = 1:numel(meta)
                row = find(strcmp(records(:, 1), meta(k).name), 1, 'last');
                assert(~isempty(row), 'Vivaldi:Readback', 'Thiếu giá trị đọc lại %s.', meta(k).name);
                p.(meta(k).name) = VivaldiHFSS.literalNumber(records{row, 2}, meta(k).unit);
            end
        end

        function value = literalNumber(text, unit)
            tok = regexp(strtrim(text), '^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*([A-Za-z]+)$', 'tokens', 'once');
            assert(~isempty(tok), 'Vivaldi:Literal', 'Biến độc lập phải là literal có đơn vị: %s.', text);
            if strcmp(unit, 'mm')
                units = {'mm', 'cm', 'm', 'um', 'in'};
                factors = [1 10 1000 .001 25.4];
            else
                units = {'deg', 'rad'};
                factors = [1 180 / pi];
            end
            k = find(strcmp(tok{2}, units), 1);
            assert(~isempty(k), 'Vivaldi:Unit', 'Đơn vị biến không hợp lệ.');
            value = str2double(tok{1}) * factors(k);
            assert(isfinite(value), 'Vivaldi:Literal', 'Giá trị biến không hữu hạn.');
        end

        function assertParams(actual, expected)
            for n = fieldnames(expected)'
                assert(abs(actual.(n{1}) - expected.(n{1})) <= 1e-10 * (1 + abs(expected.(n{1}))), 'Vivaldi:Readback', 'Giá trị đọc lại không khớp: %s.', n{1});
            end
        end

        function yes = hasLiteralMove(path)
            text = fileread(path);
            first = strfind(text, 'Name=''cable_mid_1''');
            yes = false;
            if isempty(first)
                return
            end
            stop = strfind(text(first(1):end), '$end ''GeometryPart''');
            if isempty(stop)
                yes = true;
                return
            end
            block = text(first(1):first(1) + stop(1) - 1);
            yes = ~isempty(strfind(block, 'TranslateVectorY=''2mm''')); %#ok<STREMP>
        end

        function verifySaved(path, p)
            assert(isfile(path), 'Vivaldi:Save', 'HFSS chưa tạo file AEDT.');
            info = vivaldiInspectReference(path);
            assert(info.portCount == 2 && info.radiationCount == 1 && info.noArray, 'Vivaldi:Save', 'File lưu thiếu port/radiation/NoArray.');
            VivaldiHFSS.assertParams(VivaldiHFSS.paramsFromFile(path), p);
            expected = vivaldiCalculateGeometry(p);
            for k = 1:size(expected.expressions, 1)
                name = expected.expressions{k, 1};
                if isfield(p, name)
                    continue
                end
                row = find(strcmp(info.variables(:, 1), name));
                assert(isscalar(row) && strcmp(regexprep(info.variables{row, 2}, '\s', ''), regexprep(expected.expressions{k, 2}, '\s', '')), ...
                       'Vivaldi:Save', 'Biểu thức %s không còn đúng trong file đã lưu.', name);
            end

        end

        function writeUTF16(path, text)
            fid = fopen(path, 'wb');
            assert(fid >= 0, 'Vivaldi:Write', 'Không ghi được script/status.');
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            fwrite(fid, uint8([255 254]), 'uint8');
            fwrite(fid, unicode2native(text, 'UTF-16LE'), 'uint8');
        end

        function text = readUTF16(path)
            fid = fopen(path, 'rb');
            assert(fid >= 0, 'Vivaldi:Read', 'Không đọc được status.');
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            b = fread(fid, Inf, '*uint8')';
            if numel(b) >= 2 && isequal(b(1:2), uint8([255 254]))
                b = b(3:end);
            end
            b = b(1:2 * floor(numel(b) / 2));
            text = native2unicode(b, 'UTF-16LE');
        end

        function data = readStatus(path, id)
            data = struct('acknowledged', false, 'verified', false, 'state', '', 'version', '', 'params', {cell(0, 2)}, ...
                          'records', struct('step', {}, 'execution', {}, 'geometry', {}, 'message', {}), 'reports', struct('label', {}, 'path', {}), 'objects', {{}});
            if ~isfile(path)
                return
            end
            text = VivaldiHFSS.readUTF16(path);
            last = find(text == char(10), 1, 'last');
            if isempty(last)
                return
            end
            lines = regexp(text(1:last), '\r?\n', 'split');
            if ~any(strcmp(lines, ['JOB|' id]))
                return
            end
            data.acknowledged = true;
            for k = 1:numel(lines)
                line = lines{k};
                parts = strsplit(line, '|', 'CollapseDelimiters', false);
                if numel(parts) < 2
                    continue
                end
                switch parts{1}
                    case 'STATE'
                        data.state = parts{2};
                    case 'VERIFIED'
                        data.verified = strcmp(parts{2}, '1');
                    case 'VERSION'
                        data.version = parts{2};
                    case 'PARAM'
                        if numel(parts) >= 3
                            data.params(end + 1, :) = {parts{2}, parts{3}};
                        end
                    case 'CHECK'
                        if numel(parts) >= 5
                            data.records(end + 1) = struct('step', parts{2}, 'execution', parts{3}, 'geometry', parts{4}, 'message', strjoin(parts(5:end), '|'));
                        end
                    case 'OBJECTS'
                        data.objects = strsplit(parts{2}, ',');
                    case 'UNAVAILABLE'
                        if numel(parts) >= 3
                            data.records(end + 1) = struct('step', ['KẾT_QUẢ_' parts{2}], ...
                                                           'execution', 'UNSUPPORTED', 'geometry', 'PENDING', 'message', strjoin(parts(3:end), '|'));
                        end
                    case 'CSV'
                        if numel(parts) >= 3
                            data.reports(end + 1) = struct('label', parts{2}, 'path', strjoin(parts(3:end), '|'));
                        end
                end
            end
        end

    end
end

function bootstrap(w, action, cfg)
    % Tái sử dụng phần khởi tạo của helper gốc, thay ProgID cũ bằng bản 2021.2.
    if ismember(action, {'build', 'compatibility'})
        text = w.capture(@hfssNewProject, {});
    else
        text = w.capture(@hfssOpenProject, {cfg.projectPath});
    end
    lines = regexp(text, '\r?\n', 'split');
    prefix = {};
    tail = {};
    for k = 1:numel(lines)
        l = strtrim(lines{k});
        if isempty(l) || startsWith(l, 'Dim ')
            continue
        end
        if startsWith(l, 'Set oHfssApp') || startsWith(l, 'Set oDesktop') || strcmp(l, 'oDesktop.RestoreWindow')
            prefix{end + 1} = strrep(l, 'AnsoftHfss.HfssScriptInterface', 'Ansoft.ElectronicsDesktop.2021.2'); %#ok<AGROW>
        elseif ismember(action, {'build', 'compatibility'})
            tail{end + 1} = l;
        end %#ok<AGROW>
    end
    w.call(strjoin(prefix, newline), 'Kết nối HFSS bằng script thư viện');
    w.require('Left(CStr(oDesktop.GetVersion()),6) = "2021.2"', 'Cần HFSS 2021 R2');
    w.call('WriteStatus "VERSION|" & CStr(oDesktop.GetVersion())', 'Đọc phiên bản HFSS');
    if ismember(action, {'build', 'compatibility'})
        w.call(strjoin(tail, newline), 'Tạo project trống bằng hfssNewProject');
    end
end

function attach(w, cfg)
    % Không NewProject/InsertDesign khi cập nhật; chỉ mở nếu chưa có cùng tên/path.
    text = w.capture(@hfssOpenProject, {cfg.projectPath});
    lines = regexp(text, '\r?\n', 'split');
    openLine = '';
    activeLine = '';
    for k = 1:numel(lines)
        l = strtrim(lines{k});
        if startsWith(l, 'oDesktop.OpenProject ')
            openLine = l;
        elseif startsWith(l, 'Set oProject = oDesktop.SetActiveProject')
            activeLine = l;
        end
    end
    assert(~isempty(openLine) && ~isempty(activeLine), 'Vivaldi:LibraryFormat', 'Mẫu hfssOpenProject đã thay đổi.');
    w.call(['vOpened = HasName(oDesktop.GetProjectList(),' w.q(cfg.projectName) ')'], 'Kiểm tra project đã mở');
    w.line('If Not vOpened Then');
    w.call(openLine, 'Mở Working Project bằng hfssOpenProject');
    w.line('End If');
    w.call(activeLine, 'Chọn Working Project');
    w.require(['WorkingPathMatches(' w.q(cfg.projectPath) ')'], 'Project cùng tên đang trỏ sang đường dẫn khác');
    w.lib(@hfssSetDesign, {cfg.designName});
    w.require('oDesign.GetSolutionType() = "DrivenModal"', 'Design cần là DrivenModal');
end

function compatibilityModel(w, p)
    % Kiểm chứng helper thư viện, biến tham số và phép đo vùng rỗng trên project thử.
    hfssVivaldiExtensions(w, 'variables', p, true, {});
    w.call('oEditor.SetModelUnits Array("NAME:Units Parameter","Units:=","mm","Rescale:=",False)', 'Đặt đơn vị kiểm tra');
    hfssVivaldiExtensions(w, 'box', 'ProbeBox', {'0mm', '0mm', '0mm'}, {'L_flare_1', '4mm', '3mm'}, 'vacuum');
    w.require('BodyBoundsMatch("ProbeBox",Array(0,40,0,4,0,3))', 'Box thử không đúng kích thước đầu');
    q = p;
    q.L_flare_1 = 43.287;
    hfssVivaldiExtensions(w, 'variables', q, false, {'L_flare_1'});
    w.require('BodyBoundsMatch("ProbeBox",Array(0,43.287,0,4,0,3))', 'Đổi biến không cập nhật Box');
    hfssVivaldiExtensions(w, 'variables', p, false, {'L_flare_1'});
    hfssVivaldiExtensions(w, 'rectangle', 'ProbeSheet', {'50mm', '0mm'}, {'10mm', '10mm'});
    hfssVivaldiExtensions(w, 'rectangle', 'ProbeCutter', {'53mm', '3mm'}, {'4mm', '4mm'});
    w.lib(@hfssSubtract, {{'ProbeSheet'}, {'ProbeCutter'}, 'false'});
    w.require('PointMatches("ProbeSheet",Array(55,0,5),False)', 'Không đọc được vùng rỗng trên sheet');
    w.require('PointMatches("ProbeSheet",Array(51,0,5),True)', 'Không đọc được vùng kim loại trên sheet');
    hfssVivaldiExtensions(w, 'thicken', 'ProbeSheet');
    for sign = [-1 1]
        w.require(sprintf('PointMatches("ProbeSheet",Array(51,%.17g,5),True)', sign * .9), 'Thicken thiếu kim loại bên trong ±t/2');
        w.require(sprintf('PointMatches("ProbeSheet",Array(51,%.17g,5),False)', sign * 1.1), 'Thicken vượt chiều dày nguồn');
    end
    w.require('PointMatches("ProbeSheet",Array(55,0,5),False)', 'Thicken làm mất vùng rỗng');
    w.pass('KIEM_TRA_API', 'PASS', 'Helper thư viện, cập nhật biến, sheet rỗng và BothSides đã kiểm tra thật');
end
