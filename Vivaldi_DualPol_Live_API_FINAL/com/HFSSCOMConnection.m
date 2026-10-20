classdef HFSSCOMConnection < handle
    % Persistent Direct COM. No script launcher, subprocess or silent fallback.
    properties
        Application = []
        Desktop = []
        Project = []
        Design = []
        Editor = []
        Modules = struct()
        Version = ''
        ProgID = ''
        Connected = false
        Diagnostics
        Transport = [] % Explicit test injection only. Never used by production GUI.
        Calls = struct('target', {}, 'method', {}, 'arguments', {})
    end
    methods

        function o = HFSSCOMConnection(diagnostics, transport)
            if nargin < 1
                diagnostics = HFSSDiagnostics();
            end
            o.Diagnostics = diagnostics;
            if nargin > 1
                o.Transport = transport;
            end
        end

        function candidates = detect(o) %#ok<MANU>
            candidates = {'Ansoft.ElectronicsDesktop.2021.2', 'Ansoft.ElectronicsDesktop'};
            if ~ispc
                return
            end
            for k = 1:numel(candidates)
                try
                    winqueryreg('HKEY_CLASSES_ROOT', [candidates{k} '\CLSID']);
                catch
                    candidates{k} = '';
                end
            end
            candidates = candidates(~cellfun(@isempty, candidates));
        end

        function connect(o, allowNew, requestedProgID)
            if nargin < 2
                allowNew = true;
            end
            if nargin < 3
                requestedProgID = '';
            end
            assert(ispc && exist('actxserver', 'file') ~= 0, 'Vivaldi:COMPlatform', ...
                   'PENDING — requires Windows MATLAB + HFSS. COM không có trong môi trường này.');
            o.disconnect();
            candidates = o.detect();
            if ~isempty(requestedProgID)
                candidates = unique([{char(requestedProgID)}, candidates], 'stable');
            end
            assert(~isempty(candidates), 'Vivaldi:COMRegistration', 'Không tìm thấy ProgID đã đăng ký; kiểm tra cài đặt AEDT.');
            errors = {};
            % Attach all eligible running servers before creating any new one.
            for mode = 1:(1 + logical(allowNew))
                for k = 1:numel(candidates)
                    app = [];
                    try
                        if mode == 1
                            app = actxGetRunningServer(candidates{k});
                        else
                            app = actxserver(candidates{k});
                        end
                        desktop = invoke(app, 'GetAppDesktop');
                        version = char(invoke(desktop, 'GetVersion'));
                        assert(~isempty(regexp(version, '^2021\.2(?:\D|$)', 'once')), ...
                               'Vivaldi:Version', 'Cần HFSS 2021 R2; server trả về %s.', version);
                        o.Application = app;
                        o.Desktop = desktop;
                        o.Version = version;
                        o.ProgID = candidates{k};
                        o.Connected = true;
                        o.Diagnostics.record('COM_CONNECT', 'PASS', {}, ['Connected: ' version ' / ' o.ProgID]);
                        return
                    catch ex
                        errors{end + 1} = [candidates{k} ': ' ex.message]; %#ok<AGROW>
                        if ~isempty(app)
                            try
                                delete(app);
                            catch
                            end
                        end
                    end
                end
            end
            error('Vivaldi:COMConnect', 'Không kết nối được. %s', strjoin(errors, ' | '));
        end

        function alive = ping(o)
            alive = false;
            if ~o.Connected
                return
            end
            try
                version = o.call(o.Desktop, 'GetVersion');
                alive = ~isempty(regexp(char(version), '^2021\.2(?:\D|$)', 'once'));
            catch
                alive = false;
            end
            if ~alive
                o.Connected = false;
                o.Diagnostics.record('COM_SESSION', 'FAIL', {}, 'HFSS đã đóng hoặc COM handle mất hiệu lực. Reconnect để tiếp tục.');
            end
        end

        function varargout = call(o, target, method, varargin)
            o.Calls(end + 1) = struct('target', class(target), 'method', method, 'arguments', {varargin});
            try
                if ~isempty(o.Transport)
                    [varargout{1:nargout}] = o.Transport(target, method, varargin{:});
                else
                    assert(o.Connected, 'Vivaldi:Disconnected', 'Chưa kết nối HFSS.');
                    [varargout{1:nargout}] = invoke(target, method, varargin{:});
                end
            catch ex
                o.Diagnostics.record(o.Diagnostics.CurrentStep, 'FAIL', {}, [method ': ' ex.identifier ' / ' ex.message]);
                rethrow(ex);
            end
        end

        function module = module(o, name)
            key = matlab.lang.makeValidName(name);
            if ~isfield(o.Modules, key)
                o.Modules.(key) = o.call(o.Design, 'GetModule', name);
            end
            module = o.Modules.(key);
        end

        function bind(o, project, designName)
            o.Project = project;
            o.Design = o.call(project, 'SetActiveDesign', designName);
            assert(~isempty(o.Design), 'Vivaldi:Design', 'Không tìm thấy design %s.', designName);
            kind = char(o.call(o.Design, 'GetSolutionType'));
            assert(strcmp(kind, 'DrivenModal'), 'Vivaldi:Design', 'Design phải là DrivenModal, nhận %s.', kind);
            o.Editor = o.call(o.Design, 'SetActiveEditor', '3D Modeler');
            o.Modules = struct();
        end

        function disconnect(o)
            % Release MATLAB proxies only; never QuitApplication or close user projects.
            o.Project = [];
            o.Design = [];
            o.Editor = [];
            o.Modules = struct();
            if ~isempty(o.Application) && isempty(o.Transport)
                try
                    delete(o.Application);
                catch
                end
            end
            o.Application = [];
            o.Desktop = [];
            o.Connected = false;
        end

        function delete(o)
            o.disconnect();
        end

    end
    methods (Static)

        function values = list(value)
            if isempty(value)
                values = {};
            elseif iscell(value)
                values = cellfun(@char, value(:)', 'UniformOutput', false);
            elseif ischar(value)
                values = {value};
            elseif isstring(value)
                values = cellstr(value(:)');
            else
                values = arrayfun(@num2str, value(:)', 'UniformOutput', false);
            end
        end

    end
end
