classdef HFSSProjectManager < handle
    % Single working project, explicit saves; failed updates are never auto-saved.
    properties
        Session
        ReferencePath
        WorkingPath = ''
        ProjectName = ''
        DesignName = 'dual_pol_vivaldi_patch_Wflare_20'
        Mode = ''
        Dirty = false
        Healthy = false
        LastValid = []
        LastSaved = []
        LastValidation = struct('status', 'PENDING', 'message', 'Chưa kiểm tra HFSS.')
        ResultsState = 'NOT SIMULATED'
        ResultSignature = ''
        LastUpdateStatus = 'PENDING — no update yet'
        ParameterizedMiddleMove = false
        Validator = [] % Mock seam used only in protocol regression tests.
    end
    methods

        function o = HFSSProjectManager(session, reference)
            o.Session = session;
            o.ReferencePath = vivaldiCanonicalPath(reference);
        end

        function path = checkDestination(o, path, mustBeNew)
            if nargin < 3
                mustBeNew = false;
            end
            path = vivaldiCanonicalPath(path);
            [folder, name, ext] = fileparts(path);
            assert(strcmpi(ext, '.aedt'), 'Vivaldi:ProjectPath', 'Chọn file .aedt.');
            assert(isfolder(folder), 'Vivaldi:ProjectFolder', 'Thư mục đích chưa tồn tại.');
            assert(~strcmpi(path, o.ReferencePath) && ~strcmpi(name, '17_10_2026_vivaldi'), ...
                   'Vivaldi:ReferenceProtected', 'File AEDT tham chiếu không được ghi hoặc điều khiển.');
            assert(~strcmpi(folder, fileparts(o.ReferencePath)), ...
                   'Vivaldi:ReferenceProtected', 'Chọn Working Project ngoài thư mục reference.');
            if mustBeNew
                assert(~isfile(path) && ~isfile([path '.lock']), 'Vivaldi:ProjectExists', 'Đích đã tồn tại/khóa. Chọn tên mới.');
            end
        end

        function createWorkingCopy(o, path)
            s = o.Session;
            assert(s.ping(), 'Vivaldi:Disconnected', 'Connect HFSS trước.');
            path = o.checkDestination(path, true);
            [ok, msg] = copyfile(o.ReferencePath, path);
            assert(ok, 'Vivaldi:Copy', '%s', msg);
            % Only the newly created copy is normalized; source remains byte-identical.
            text = fileread(path);
            first = strfind(text, 'Name=''cable_mid_1''');
            assert(numel(first) == 1, 'Vivaldi:CopyHistory', 'Không xác định được middle cutter trong bản sao.');
            stop = strfind(text(first:end), '$end ''GeometryPart''');
            stop = first + stop(1) - 2;
            block = text(first:stop);
            old = 'TranslateVectorY=''2mm''';
            new = 'TranslateVectorY=''thickness''';
            assert(numel(strfind(block, old)) == 1, 'Vivaldi:CopyHistory', 'Move literal nguồn không khớp.');
            block = strrep(block, old, new);
            text = [text(1:first - 1), block, text(stop + 1:end)];
            fid = fopen(path, 'w', 'n', 'UTF-8');
            assert(fid >= 0, 'Vivaldi:CopyWrite', 'Không ghi được bản sao.');
            cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
            fprintf(fid, '%s', text);
            clear cleanup;
            s.Diagnostics.record('CREATE_WORKING_COPY', 'PASS', {}, ...
                                 'Bản sao riêng; chỉ cable_mid_1 Move Y: 2mm -> thickness. Chưa validate CAD.');
            o.open(path);
            o.Mode = 'Reference copy (one Move expression normalized)';
        end

        function open(o, path)
            s = o.Session;
            assert(s.ping(), 'Vivaldi:Disconnected', 'Connect/Reconnect HFSS trước.');
            path = o.checkDestination(path, false);
            assert(isfile(path), 'Vivaldi:MissingProject', 'Không có %s.', path);
            [~, name] = fileparts(path);
            projects = HFSSCOMConnection.list(s.call(s.Desktop, 'GetProjectList'));
            if ismember(name, projects)
                project = s.call(s.Desktop, 'SetActiveProject', name);
                actual = fullfile(char(s.call(project, 'GetPath')), [char(s.call(project, 'GetName')) '.aedt']);
                assert(strcmpi(vivaldiCanonicalPath(actual), path), 'Vivaldi:ProjectCollision', 'Project cùng tên đang mở tại đường dẫn khác.');
            else
                project = s.call(s.Desktop, 'OpenProject', path);
            end
            s.bind(project, o.DesignName);
            o.WorkingPath = path;
            o.ProjectName = name;
            o.Mode = 'Attach existing working project';
            o.LastUpdateStatus = 'PENDING — working project newly attached';
            o.Dirty = false;
            o.Healthy = false;
            o.LastValid = [];
            o.LastSaved = [];
            o.ResultsState = 'NOT SIMULATED';
            o.LastUpdateStatus = 'PENDING — no update on this project yet';
            o.ResultSignature = '';
            s.Diagnostics.ProjectPath = path;
            text = fileread(path);
            o.ParameterizedMiddleMove = ~HFSSProjectManager.hasLiteralMiddleMove(text);
            current = HFSSVariableManager.read(s);
            report = o.validate(current);
            if strcmp(report.status, 'PASS')
                o.LastValid = current;
                o.LastSaved = current;
                o.Healthy = true;
            end
            s.Diagnostics.record('ATTACH_PROJECT', report.status, {}, report.message);
        end

        function build(o, path, p, simulation)
            if nargin < 4
                simulation = HFSSSimulationSetup.defaults();
            end
            s = o.Session;
            assert(s.ping(), 'Vivaldi:Disconnected', 'Connect HFSS trước.');
            path = o.checkDestination(path, true);
            [valid, errors] = vivaldiValidateParams(p);
            assert(valid, 'Vivaldi:Parameters', '%s', strjoin(errors, newline));
            [~, name] = fileparts(path);
            projects = HFSSCOMConnection.list(s.call(s.Desktop, 'GetProjectList'));
            assert(~ismember(name, projects), 'Vivaldi:ProjectCollision', 'Tên project đang được dùng.');
            project = s.call(s.Desktop, 'NewProject');
            % Save only an empty shell to establish the working path. Failed CAD
            % remains unsaved in memory, with this empty recovery file on disk.
            s.call(project, 'SaveAs', path, true);
            s.call(project, 'InsertDesign', 'HFSS', o.DesignName, 'DrivenModal', '');
            s.bind(project, o.DesignName);
            o.WorkingPath = path;
            o.ProjectName = name;
            o.Mode = 'Direct COM build from empty design';
            o.ParameterizedMiddleMove = true;
            o.Dirty = true;
            o.Healthy = false;
            o.LastValid = [];
            o.LastSaved = [];
            o.ResultsState = 'NOT SIMULATED';
            o.LastUpdateStatus = 'PENDING — no update on this project yet';
            s.Diagnostics.ProjectPath = path;
            try
                HFSSGeometryBuilder(s, p);
                HFSSSimulationSetup.create(s, p, simulation);
                report = o.validate(p);
                assert(strcmp(report.status, 'PASS'), 'Vivaldi:BuildValidation', '%s', report.message);
                o.LastValid = p;
                o.Healthy = true;
                s.Diagnostics.record('BUILD_COMPLETE', 'PASS', HFSSCAD.names(s), 'CAD checks passed; changes remain unsaved until Save.');
            catch ex
                o.Healthy = false;
                o.LastValidation = struct('status', 'FAIL', 'message', ex.message);
                rethrow(ex);
            end
        end

        function assertIdentity(o)
            s = o.Session;
            assert(s.ping() && ~isempty(s.Project) && ~isempty(o.WorkingPath), 'Vivaldi:Disconnected', 'Mở lại Working Project sau Reconnect.');
            o.checkDestination(o.WorkingPath, false);
            actual = fullfile(char(s.call(s.Project, 'GetPath')), [char(s.call(s.Project, 'GetName')) '.aedt']);
            assert(strcmpi(vivaldiCanonicalPath(actual), o.WorkingPath), 'Vivaldi:ProjectIdentity', 'COM Project không còn trỏ tới Working Project đã chọn.');
            assert(strcmp(char(s.call(s.Design, 'GetName')), o.DesignName), 'Vivaldi:DesignIdentity', 'Design handle đã thay đổi.');
        end

        function report = validate(o, p)
            o.assertIdentity();
            if nargin < 2
                p = HFSSVariableManager.read(o.Session);
                if ~isempty(o.LastValid) && ~isequal(p, o.LastValid)
                    o.ResultsState = 'RESULTS OUTDATED — RE-SIMULATION REQUIRED';
                    o.ResultSignature = '';
                    o.Dirty = true;
                end
            end
            if isempty(o.Validator)
                report = HFSSGeometryValidator.run(o.Session, p, true);
            else
                report = o.Validator(o.Session, p);
            end
            o.LastValidation = report;
            o.Healthy = strcmp(report.status, 'PASS');
        end

        function report = update(o, p)
            o.assertIdentity();
            assert(o.Healthy && ~isempty(o.LastValid), 'Vivaldi:NoBaseline', 'Cần Validate thành công trước khi Live Update; mô hình lỗi phải Reload.');
            [valid, errors] = vivaldiValidateParams(p);
            assert(valid, 'Vivaldi:Parameters', '%s', strjoin(errors, newline));
            assert(o.ParameterizedMiddleMove || p.thickness == o.LastValid.thickness, ...
                   'Vivaldi:LiteralMiddleMove', 'Project có cable_mid_1 Move Y=2mm. Dùng Create Working Copy chuẩn hóa hoặc Build From Scratch trước khi đổi thickness.');
            % Refuse to overwrite edits made independently in HFSS.
            try
                HFSSVariableManager.verify(o.Session, o.LastValid);
            catch ex
                o.Healthy = false;
                o.Dirty = true;
                o.ResultsState = 'RESULTS OUTDATED — RE-SIMULATION REQUIRED';
                o.ResultSignature = '';
                o.LastUpdateStatus = 'FAIL — external variable edits; validate again';
                rethrow(ex);
            end
            before = o.LastValid;
            dirtyBefore = o.Dirty;
            o.ResultsState = 'RESULTS OUTDATED — RE-SIMULATION REQUIRED';
            o.ResultSignature = '';
            o.Dirty = true;
            o.Healthy = false;
            o.Session.Diagnostics.Parameters = p;
            try
                HFSSVariableManager.write(o.Session, p);
                report = o.validate(p);
                assert(strcmp(report.status, 'PASS'), 'Vivaldi:UpdateValidation', '%s', report.message);
                o.LastValid = p;
                o.Healthy = true;
                o.LastUpdateStatus = 'PASS — same project/design; unsaved';
                o.Session.Diagnostics.record('LIVE_UPDATE', 'PASS', {}, 'Same project/design; variables and geometry read back. NOT SAVED.');
            catch ex
                o.Session.Diagnostics.record('LIVE_UPDATE', 'FAIL', {}, ex.message);
                o.LastUpdateStatus = 'FAIL — attempting rollback';
                rollbackMessage = '';
                try
                    o.Session.Diagnostics.Parameters = before;
                    HFSSVariableManager.write(o.Session, before);
                    recovered = o.validate(before);
                    assert(strcmp(recovered.status, 'PASS'), 'Vivaldi:RollbackValidation', '%s', recovered.message);
                    o.LastValid = before;
                    o.Dirty = dirtyBefore;
                    o.Healthy = true;
                    rollbackMessage = 'Đã phục hồi tham số trước và validate lại; update mới THẤT BẠI.';
                    o.LastUpdateStatus = 'FAIL — restored previous valid parameters';
                    o.Session.Diagnostics.record('ROLLBACK', 'PASS', {}, rollbackMessage);
                catch rollbackError
                    o.Healthy = false;
                    o.Dirty = true;
                    rollbackMessage = ['Phục hồi thất bại: ' rollbackError.message '. Reload Last Saved Version; KHÔNG Save.'];
                    o.LastUpdateStatus = 'FAIL — rollback failed; reload required';
                    o.Session.Diagnostics.record('ROLLBACK', 'FAIL', {}, rollbackMessage);
                end
                error('Vivaldi:UpdateFailed', '%s | %s', ex.message, rollbackMessage);
            end
        end

        function restore(o)
            o.assertIdentity();
            assert(~isempty(o.LastValid), 'Vivaldi:NoBaseline', 'Chưa có bộ tham số đã validate.');
            o.ResultsState = 'RESULTS OUTDATED — RE-SIMULATION REQUIRED';
            o.ResultSignature = '';
            o.Dirty = true;
            o.Healthy = false;
            HFSSVariableManager.write(o.Session, o.LastValid);
            report = o.validate(o.LastValid);
            assert(strcmp(report.status, 'PASS'), 'Vivaldi:Restore', 'Phục hồi chưa validate được; Reload bản lưu.');
        end

        function save(o, newPath)
            o.assertIdentity();
            assert(o.Healthy && ~isempty(o.LastValid), 'Vivaldi:UnsafeSave', 'Không lưu mô hình chưa validate.');
            report = o.validate(o.LastValid);
            assert(strcmp(report.status, 'PASS'), 'Vivaldi:UnsafeSave', '%s', report.message);
            if nargin > 1 && ~isempty(newPath)
                path = o.checkDestination(newPath, true);
                o.Session.call(o.Session.Project, 'SaveAs', path, true);
                o.WorkingPath = path;
                [~, o.ProjectName] = fileparts(path);
                o.Session.Diagnostics.ProjectPath = path;
            else
                o.Session.call(o.Session.Project, 'Save');
            end
            assert(isfile(o.WorkingPath), 'Vivaldi:SaveReadback', 'HFSS chưa tạo file AEDT.');
            info = vivaldiInspectReference(o.WorkingPath, o.DesignName);
            assert(info.portCount == 2 && info.radiationCount == 1 && info.noArray, ...
                   'Vivaldi:SavedInventory', 'File lưu thiếu 2 ports/Open1/NoArray. Kiểm tra HFSS.');
            expected = vivaldiCalculateGeometry(o.LastValid);
            [~, meta] = vivaldiDefaultParams();
            for k = 1:size(expected.expressions, 1)
                name = expected.expressions{k, 1};
                row = find(strcmp(info.variables(:, 1), name));
                assert(isscalar(row), 'Vivaldi:SavedVariables', 'Biến %s không duy nhất trong file lưu.', name);
                value = info.variables{row, 2};
                if isfield(o.LastValid, name)
                    index = find(strcmp({meta.name}, name));
                    number = HFSSVariableManager.parseLiteral(value, meta(index).unit);
                    assert(abs(number - o.LastValid.(name)) < max(1, abs(number)) * 1e-10, ...
                           'Vivaldi:SavedVariables', 'Biến %s trong file lưu không đúng.', name);
                else
                    assert(strcmp(regexprep(value, '\s', ''), regexprep(expected.expressions{k, 2}, '\s', '')), ...
                           'Vivaldi:SavedVariables', 'Biểu thức %s trong file lưu không đúng.', name);
                end
            end
            o.LastSaved = o.LastValid;
            o.Dirty = false;
            vivaldiWriteJSON([o.WorkingPath '.live.json'], struct('parameters', o.LastValid, ...
                                                                  'mode', o.Mode, 'validation', o.LastValidation, 'time', datestr(now, 30), 'HFSSVersion', o.Session.Version));
        end

        function reload(o)
            o.assertIdentity();
            path = o.WorkingPath;
            o.Session.call(o.Session.Desktop, 'CloseProject', o.ProjectName);
            o.Session.Project = [];
            o.Session.Design = [];
            o.Session.Editor = [];
            o.Session.Modules = struct();
            o.WorkingPath = '';
            o.Healthy = false;
            o.open(path);
        end

    end
    methods (Static)

        function yes = hasLiteralMiddleMove(text)
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

    end
end
