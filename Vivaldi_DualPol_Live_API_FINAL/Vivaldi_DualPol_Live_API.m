function fig = Vivaldi_DualPol_Live_API(varargin)
    % VIVALDI_DUALPOL_LIVE_API One-command MATLAB GUI, persistent direct HFSS COM.
    % Target: Windows MATLAB R2021a+ and HFSS 2021 R2. Preview also works offline.
    % Optional: Vivaldi_DualPol_Live_API('Visible','off') for desktop regression.
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'core'), fullfile(root, 'com'), fullfile(root, 'results'));
    assert(~verLessThan('matlab', '9.10'), 'Vivaldi:MATLABVersion', 'Cần MATLAB R2021a trở lên.');
    opts = inputParser;
    addParameter(opts, 'Visible', 'on');
    parse(opts, varargin{:});
    [p, meta] = vivaldiDefaultParams();
    draftValid = true;
    busy = false;
    closing = false;
    workFolder = fullfile(root, 'work');
    if ~isfolder(workFolder)
        mkdir(workFolder);
    end
    logFolder = fullfile(root, 'logs');
    if ~isfolder(logFolder)
        mkdir(logFolder);
    end
    [~, token] = fileparts(tempname);
    diagnostics = HFSSDiagnostics(fullfile(logFolder, ['Live_' token '.txt']));
    session = HFSSCOMConnection(diagnostics);
    manager = HFSSProjectManager(session, fullfile(root, 'reference', '17_10_2026_vivaldi.aedt'));
    monitor = HFSSSessionMonitor(session, @sessionChanged);
    imported = [];
    simcfg = HFSSSimulationSetup.defaults();
    fig = uifigure('Name', 'Vivaldi Dual-Polarized Antenna — Live HFSS Designer Pro', ...
                   'Position', [60 60 1400 880], 'Visible', 'off', 'CloseRequestFcn', @closeApp);
    outer = uigridlayout(fig, [2 1]);
    outer.RowHeight = {'1x', 48};
    tabs = uitabgroup(outer);
    banner = uilabel(outer, 'WordWrap', 'on', 'FontColor', [.1 .25 .45]);
    t1 = uitab(tabs, 'Title', 'ANTENNA PARAMETERS');
    t2 = uitab(tabs, 'Title', 'GEOMETRY PREVIEW');
    t3 = uitab(tabs, 'Title', 'LIVE HFSS CONNECTION');
    t4 = uitab(tabs, 'Title', 'SIMULATION');
    t5 = uitab(tabs, 'Title', 'DEBUG & DIAGNOSTICS');

    % Numeric fields impose no slider or preset limits. Derived fields are read-only.
    a = uigridlayout(t1, [3 2]);
    a.RowHeight = {'1x', 58, 44};
    a.ColumnWidth = {'1x', '1x'};
    paramPanel = uipanel(a, 'Title', '19 biến độc lập — mm / deg');
    paramPanel.Layout.Row = 1;
    paramPanel.Layout.Column = 1;
    pgrid = uigridlayout(paramPanel, [numel(meta) 2]);
    pgrid.Scrollable = 'on';
    pgrid.RowHeight = repmat({34}, 1, numel(meta));
    pgrid.ColumnWidth = {'1x', 140};
    fields = struct();
    for k = 1:numel(meta)
        n = meta(k).name;
        label = uilabel(pgrid, 'Text', [n ' (' meta(k).unit ')'], 'Interpreter', 'none');
        label.Tooltip = [meta(k).group ' | ' meta(k).label ' | ' meta(k).tip];
        fields.(n) = uieditfield(pgrid, 'numeric', 'Value', p.(n), 'Limits', [-Inf Inf], ...
                                 'ValueDisplayFormat', '%.12g', 'Tag', ['Parameter_' n], ...
                                 'ValueChangedFcn', @(~, ~)parameterChanged());
    end
    derivedPanel = uipanel(a, 'Title', '12 biến dẫn xuất — không sửa trực tiếp');
    derived = uitable(derivedPanel, 'Data', {}, 'ColumnName', {'Biến', 'Giá trị', 'Biểu thức'}, ...
                      'ColumnEditable', [false false false]);
    derived.Position = [8 8 600 590];
    derivedPanel.SizeChangedFcn = @(~, ~)sizeTable();
    paramButtons = uigridlayout(a, [1 7]);
    paramButtons.Layout.Row = 2;
    paramButtons.Layout.Column = [1 2];
    makeButton(paramButtons, 'Calculate', @(~, ~)parameterChanged(), 'Calculate');
    makeButton(paramButtons, 'Validate', @(~, ~)validateDraft(), 'ValidateParameters');
    makeButton(paramButtons, 'Reset Defaults', @(~, ~)resetDefaults(), 'ResetDefaults');
    makeButton(paramButtons, 'Target Length', @(~, ~)targetLength(), 'TargetLength');
    makeButton(paramButtons, 'Apply Changes', @(~, ~)parameterChanged(), 'ApplyChanges');
    makeButton(paramButtons, 'Update HFSS', @(~, ~)execute('Live Update', @updateGeometry), 'UpdateHFSS');
    makeButton(paramButtons, 'Save/Load JSON', @(~, ~)configuration(), 'ParameterConfig');
    paramStatus = uilabel(a, 'WordWrap', 'on');
    paramStatus.Layout.Row = 3;
    paramStatus.Layout.Column = [1 2];

    v = uigridlayout(t2, [3 1]);
    v.RowHeight = {42, '1x', 42};
    viewSelect = uidropdown(v, 'Items', {'Isometric', 'Front', 'Side', 'Top'}, 'ValueChangedFcn', @(~, ~)drawPreview());
    preview = uiaxes(v, 'Tag', 'GeometryPreview');
    axtoolbar(preview, {'rotate', 'pan', 'zoomin', 'zoomout', 'restoreview'});
    uilabel(v, 'Text', 'Preview lấy mẫu từ công thức và polyshape, có transition/slot/cavity/coax; chưa phải CAD HFSS đã validate.', ...
            'WordWrap', 'on', 'FontColor', [.6 .25 .05]);

    c = uigridlayout(t3, [5 1]);
    c.RowHeight = {48, 42, 100, 100, '1x'};
    workingPath = uieditfield(c, 'text', 'Value', fullfile(workFolder, 'Vivaldi_DualPol_Working.aedt'), 'Tag', 'WorkingProjectPath');
    progID = uieditfield(c, 'text', 'Value', 'Ansoft.ElectronicsDesktop.2021.2', 'Tag', 'COMProgID');
    connButtons = uigridlayout(c, [2 5]);
    makeButton(connButtons, 'Detect HFSS', @(~, ~)execute('Detect', @detectHFSS), 'DetectHFSS');
    makeButton(connButtons, 'Connect', @(~, ~)execute('Connect', @connectHFSS), 'ConnectHFSS');
    makeButton(connButtons, 'Reconnect', @(~, ~)execute('Reconnect', @reconnectHFSS), 'ReconnectHFSS');
    makeButton(connButtons, 'Create Working Copy', @(~, ~)execute('Create Copy', @createCopy), 'CreateWorkingCopy');
    makeButton(connButtons, 'Open Working Project', @(~, ~)execute('Open', @openProject), 'OpenWorkingProject');
    makeButton(connButtons, 'Build From Scratch', @(~, ~)execute('Build', @buildProject), 'BuildFromScratch');
    makeButton(connButtons, 'Update Geometry', @(~, ~)execute('Live Update', @updateGeometry), 'UpdateGeometry');
    makeButton(connButtons, 'Validate Geometry', @(~, ~)execute('Validate', @validateGeometry), 'ValidateGeometry');
    makeButton(connButtons, 'Save', @(~, ~)execute('Save', @saveProject), 'SaveWorkingProject');
    makeButton(connButtons, 'Save As', @(~, ~)execute('Save As', @saveAs), 'SaveAs');
    extra = uigridlayout(c, [2 3]);
    makeButton(extra, 'Browse Working Path', @(~, ~)chooseWorkingPath(), 'BrowseWorkingPath');
    makeButton(extra, 'Open HFSS Window', @(~, ~)execute('HFSS Window', @restoreWindow), 'OpenHFSSWindow');
    makeButton(extra, 'Reload Last Saved Version', @(~, ~)reloadProject(), 'ReloadLastSaved');
    makeButton(extra, 'Restore Last Valid Parameters', @(~, ~)execute('Restore', @restoreParameters), 'RestoreLastValid');
    makeButton(extra, 'COM Compatibility Test', @(~, ~)execute('COM Test', @compatibilityTest), 'COMCompatibilityTest');
    uilabel(extra, 'Text', 'Direct COM; không sinh VBScript.', 'WordWrap', 'on');
    connectionStatus = uitextarea(c, 'Editable', 'off', 'Tag', 'ConnectionStatus');

    % Simulation and actual CSV only. Solver runs exclusively from the Run button.
    s = uigridlayout(t4, [5 1]);
    s.RowHeight = {160, 42, 80, '1x', 48};
    simgrid = uigridlayout(s, [3 8]);
    simFields = struct();
    simNames = {'adaptiveGHz', 'startGHz', 'stopGHz', 'stepGHz', 'deltaS', 'minimumPasses', 'maximumPasses', 'fieldGHz'};
    for k = 1:8
        uilabel(simgrid, 'Text', simNames{k}, 'Interpreter', 'none');
    end
    for k = 1:8
        n = simNames{k};
        simFields.(n) = uieditfield(simgrid, 'numeric', 'Value', simcfg.(n), 'ValueDisplayFormat', '%.12g');
    end
    excitation = uidropdown(simgrid, 'Items', {'Excite Port1', 'Excite Port2', 'Custom Excitation'}, ...
                            'ValueChangedFcn', @(~, ~)excitationChanged());
    power1 = uieditfield(simgrid, 'numeric', 'Value', 1, 'Tooltip', 'Port1 W');
    power2 = uieditfield(simgrid, 'numeric', 'Value', 0, 'Tooltip', 'Port2 W');
    phase1 = uieditfield(simgrid, 'numeric', 'Value', 0, 'Tooltip', 'Port1 phase deg');
    phase2 = uieditfield(simgrid, 'numeric', 'Value', 0, 'Tooltip', 'Port2 phase deg');
    uilabel(simgrid, 'Text', 'Công suất W; phase deg');
    uilabel(simgrid, 'Text', 'Frequency GHz; Sweep Discrete');
    uilabel(simgrid, 'Text', '5–20 GHz / 0.25 GHz mặc định');
    simButtons = uigridlayout(s, [1 5]);
    makeButton(simButtons, 'Validate', @(~, ~)execute('Validate', @validateGeometry), 'SimulationValidate');
    makeButton(simButtons, 'Apply Solver Settings', @(~, ~)execute('Solver Config', @applySolver), 'ApplySolver');
    makeButton(simButtons, 'RUN SIMULATION', @(~, ~)runSimulation(), 'RunSimulation');
    makeButton(simButtons, 'Export HFSS Results', @(~, ~)execute('Export', @exportResults), 'ExportHFSSResults');
    makeButton(simButtons, 'Import Results CSV', @(~, ~)importCSV(), 'ImportResults');
    selectors = uigridlayout(s, [2 5]);
    uilabel(selectors, 'Text', 'X / Theta column');
    uilabel(selectors, 'Text', 'Y / Gain column');
    uilabel(selectors, 'Text', 'Phi column (3D)');
    uilabel(selectors, 'Text', 'Kiểu đồ thị');
    makeButton(selectors, 'HPBW', @(~, ~)measureHPBW(), 'HPBW');
    xColumn = uidropdown(selectors, 'Items', {'No data'});
    yColumn = uidropdown(selectors, 'Items', {'No data'});
    phiColumn = uidropdown(selectors, 'Items', {'No data'});
    plotKind = uidropdown(selectors, 'Items', {'2D: selected curve', '3D: Theta/Phi/Gain'});
    makeButton(selectors, 'Plot S / Gain / Pattern', @(~, ~)plotResults(), 'PlotResults');
    resultAxes = uiaxes(s, 'Tag', 'ResultsAxes');
    resultStatus = uilabel(s, 'Text', 'NOT SIMULATED', 'WordWrap', 'on', 'Tag', 'ResultsState');

    z = uigridlayout(t5, [3 1]);
    z.RowHeight = {52, 90, '1x'};
    debugControls = uigridlayout(z, [1 3]);
    makeButton(debugControls, 'Debug Build Step-by-Step', @(~, ~)execute('Debug Build', @debugBuild), 'DebugBuild');
    pauseBuild = uicheckbox(debugControls, 'Text', 'Dừng ở mỗi checkpoint', 'Value', true);
    makeButton(debugControls, 'Show Failed Step', @(~, ~)showFailed(), 'ShowFailedStep');
    debugButtons = uigridlayout(z, [2 4]);
    makeButton(debugButtons, 'Export Log TXT', @(~, ~)exportLogs(), 'ExportLog');
    makeButton(debugButtons, 'View Object Tree', @(~, ~)execute('Object Tree', @objectTree), 'ViewObjectTree');
    makeButton(debugButtons, 'Validate Geometry', @(~, ~)execute('Validate', @validateGeometry), 'DebugValidate');
    makeButton(debugButtons, 'Restore Last Valid Parameters', @(~, ~)execute('Restore', @restoreParameters), 'DebugRestore');
    makeButton(debugButtons, 'Open Working Folder', @(~, ~)openFolder(), 'OpenWorkingFolder');
    makeButton(debugButtons, 'Export Diagnostic JSON', @(~, ~)exportDiagnostics(), 'ExportDiagnostics');
    makeButton(debugButtons, 'Dependency Graph', @(~, ~)showDependencies(), 'DependencyGraph');
    uilabel(debugButtons, 'Text', 'PASS / FAIL / PENDING / UNSUPPORTED', 'WordWrap', 'on');
    debugText = uitextarea(z, 'Editable', 'off', 'FontName', 'Consolas', 'Tag', 'Diagnostics');
    fig.UserData = struct('session', session, 'manager', manager, 'monitor', monitor, 'diagnostics', diagnostics);
    parameterChanged();
    refresh();
    monitor.start();
    fig.Visible = opts.Results.Visible;

    function b = makeButton(parent, label, callback, tag)
        b = uibutton(parent, 'Text', label, 'ButtonPushedFcn', callback, 'Tag', tag);
    end

    function sizeTable()
        if isvalid(derivedPanel)
            derived.Position = [8 8 max(10, derivedPanel.Position(3) - 16) max(10, derivedPanel.Position(4) - 35)];
        end
    end

    function parameterChanged()
        if busy || closing
            return
        end
        names = fieldnames(fields);
        for j = 1:numel(names)
            p.(names{j}) = fields.(names{j}).Value;
        end
        [draftValid, errors, warnings, g] = vivaldiValidateParams(p);
        if draftValid
            rows = {};
            for j = 1:size(g.expressions, 1)
                name = g.expressions{j, 1};
                if isfield(p, name)
                    continue
                end
                rows(end + 1, :) = {name, g.(name), g.expressions{j, 2}}; %#ok<AGROW>
            end
            derived.Data = rows;
            paramStatus.Text = sprintf('L_patch = %.9f mm | L_flare = %.9f mm | Đại số hợp lệ; HFSS cần validate.', g.L_patch, g.L_flare);
            drawPreview();
        else
            paramStatus.Text = strjoin(errors, ' | ');
            derived.Data = {};
        end
        diagnostics.Parameters = p;
        debugText.Value = [{'PARAMETER CHECK'}, errors(:)', warnings(:)'];
        fig.UserData.parameters = p;
    end

    function drawPreview()
        if ~draftValid || closing
            return
        end
        try
            vivaldiPreview3D(preview, p, [], struct('view', viewSelect.Value, 'coax', true, 'coordinates', false, 'dimensions', true));
        catch ex
            diagnostics.record('PREVIEW', 'FAIL', {}, ex.message);
            paramStatus.Text = ['Preview error: ' ex.message];
        end
    end

    function validateDraft()
        parameterChanged();
        if draftValid
            notify('Đại số hợp lệ. Boolean, tiếp xúc và port cần kiểm tra HFSS.');
        else
            notify(paramStatus.Text);
        end
    end

    function setParameters(q)
        p = q;
        names = fieldnames(fields);
        for j = 1:numel(names)
            fields.(names{j}).Value = p.(names{j});
        end
    end

    function resetDefaults()
        if busy
            return
        end
        setParameters(vivaldiDefaultParams());
        parameterChanged();
    end

    function targetLength()
        if busy
            return
        end
        answer = inputdlg('L_patch mục tiêu (mm), khác chiều dài flare:', 'Target Antenna Length', 1, {'57.35'});
        if isempty(answer)
            return
        end
        try
            [q, r] = vivaldiSolveTargetLength(p, str2double(answer{1}));
            setParameters(q);
            parameterChanged();
            notify(sprintf('L_flare_1=%.12g mm; residual=%.3g mm.', q.L_flare_1, r.residual));
        catch ex
            notify(ex.message);
        end
    end

    function configuration()
        if busy
            return
        end
        choice = uiconfirm(fig, 'JSON chỉ là cấu hình tùy chọn.', 'Parameters', 'Options', {'Save', 'Load', 'Cancel'}, 'CancelOption', 3);
        try
            if strcmp(choice, 'Save')
                [f, d] = uiputfile('*.json');
                if isequal(f, 0)
                    return
                end
                vivaldiWriteJSON(fullfile(d, f), struct('schema', 'VivaldiLiveAPI/1', 'parameters', p));
            elseif strcmp(choice, 'Load')
                [f, d] = uigetfile('*.json');
                if isequal(f, 0)
                    return
                end
                config = jsondecode(fileread(fullfile(d, f)));
                assert(strcmp(config.schema, 'VivaldiLiveAPI/1'), 'Vivaldi:Config', 'Sai schema JSON.');
                [ok, errors] = vivaldiValidateParams(config.parameters);
                assert(ok, 'Vivaldi:Config', '%s', strjoin(errors, newline));
                setParameters(config.parameters);
                parameterChanged();
            end
        catch ex
            notify(ex.message);
        end
    end

    function execute(label, operation)
        if busy || closing
            return
        end
        parameterChanged();
        busy = true;
        monitor.Busy = true;
        banner.Text = [label ' đang thực hiện — lời gọi COM có thể chặn MATLAB.'];
        drawnow;
        try
            operation();
        catch ex
            diagnostics.record(label, 'FAIL', {}, [ex.identifier ': ' ex.message]);
            notify([ex.identifier newline ex.message]);
        end
        busy = false;
        monitor.Busy = false;
        if ~closing && isvalid(fig)
            parameterChanged();
            refresh();
        end
    end

    function detectHFSS()
        ids = session.detect();
        diagnostics.record('DETECT', 'PENDING', ids, 'ProgID có thể dùng; chỉ Connect/Test mới xác minh được COM.');
        if isempty(ids)
            notify('Không có ProgID được đăng ký. Cần Windows và HFSS 2021 R2.');
        else
            notify(strjoin(ids, newline));
        end
    end

    function connectHFSS()
        session.connect(true, progID.Value);
    end

    function reconnectHFSS()
        session.connect(true, progID.Value);
        manager.Healthy = false;
        if ~isempty(manager.WorkingPath)
            notify('Đã Reconnect. Nhấn Open Working Project để lấy lại handles và Validate; không tự đóng project cũ.');
            workingPath.Value = manager.WorkingPath;
        end
    end

    function path = chosenPath()
        path = workingPath.Value;
        if isempty(path)
            error('Vivaldi:Path', 'Chọn đường dẫn Working Project.');
        end
    end

    function createCopy()
        manager.createWorkingCopy(chosenPath());
        if ~isempty(manager.LastValid)
            setParameters(manager.LastValid);
        end
    end

    function openProject()
        manager.open(chosenPath());
        setParameters(HFSSVariableManager.read(session));
    end

    function buildProject()
        assert(draftValid, 'Vivaldi:Parameters', 'Sửa tham số không hợp lệ trước.');
        diagnostics.PauseCallback = [];
        manager.build(chosenPath(), p, readSimulation());
    end

    function debugBuild()
        assert(draftValid, 'Vivaldi:Parameters', 'Sửa tham số không hợp lệ trước.');
        diagnostics.PauseCallback = @pauseCheckpoint;
        try
            manager.build(chosenPath(), p, readSimulation());
        catch ex
            diagnostics.PauseCallback = [];
            rethrow(ex);
        end
        diagnostics.PauseCallback = [];
    end

    function pauseCheckpoint(step, objects)
        debugText.Value = {[step ' PASS'], strjoin(objects, ', '), 'Inspect geometry in HFSS before Continue.'};
        drawnow;
        if pauseBuild.Value
            choice = uiconfirm(fig, [step newline strjoin(objects, ', ')], 'Debug checkpoint', ...
                               'Options', {'Continue', 'Stop'}, 'CancelOption', 2);
            if strcmp(choice, 'Stop')
                error('Vivaldi:DebugStopped', 'Người dùng dừng ở %s; CAD chưa lưu.', step);
            end
        end
    end

    function updateGeometry()
        assert(draftValid, 'Vivaldi:Parameters', 'Sửa tham số không hợp lệ trước.');
        manager.update(p);
    end

    function validateGeometry()
        report = manager.validate();
        assert(strcmp(report.status, 'PASS'), 'Vivaldi:Geometry', '%s', report.message);
        current = HFSSVariableManager.read(session);
        manager.LastValid = current;
    end

    function saveProject()
        manager.save();
    end

    function saveAs()
        [f, d] = uiputfile('*.aedt', 'Save As New Version', workingPath.Value);
        if isequal(f, 0)
            return
        end
        manager.save(fullfile(d, f));
        workingPath.Value = manager.WorkingPath;
    end

    function reloadProject()
        if busy
            return
        end
        choice = uiconfirm(fig, 'Đóng Working Project hiện tại và bỏ thay đổi chưa lưu? Project tham chiếu không bị mở.', ...
                           'Reload Last Saved Version', 'Options', {'Reload', 'Cancel'}, 'CancelOption', 2);
        if strcmp(choice, 'Reload')
            execute('Reload', @doReload);
        end
    end

    function doReload()
        manager.reload();
        if ~isempty(manager.LastValid)
            setParameters(manager.LastValid);
        end
    end

    function restoreParameters()
        manager.restore();
        setParameters(manager.LastValid);
    end

    function restoreWindow()
        assert(session.ping(), 'Vivaldi:Disconnected', 'Connect trước.');
        session.call(session.Desktop, 'RestoreWindow');
    end

    function chooseWorkingPath()
        if busy
            return
        end
        [f, d] = uiputfile('*.aedt', 'Chọn tên Working Project', workingPath.Value);
        if ~isequal(f, 0)
            workingPath.Value = fullfile(d, f);
        end
    end

    function compatibilityTest()
        addpath(fullfile(root, 'tests'));
        report = runCOMCompatibilityTests(logFolder, progID.Value);
        notify([report.status newline report.message]);
    end

    function c = readSimulation()
        c = simcfg;
        for j = 1:numel(simNames)
            c.(simNames{j}) = simFields.(simNames{j}).Value;
        end
        c.powerW = [power1.Value power2.Value];
        c.phaseDeg = [phase1.Value phase2.Value];
        HFSSSimulationSetup.validate(c);
    end

    function excitationChanged()
        if strcmp(excitation.Value, 'Excite Port1')
            power1.Value = 1;
            power2.Value = 0;
            phase1.Value = 0;
            phase2.Value = 0;
        elseif strcmp(excitation.Value, 'Excite Port2')
            power1.Value = 0;
            power2.Value = 1;
            phase1.Value = 0;
            phase2.Value = 0;
        end
    end

    function applySolver()
        simcfg = readSimulation();
        HFSSSimulationSetup.apply(manager, simcfg);
    end

    function runSimulation()
        if busy
            return
        end
        choice = uiconfirm(fig, 'Chạy Setup1 với cấu hình hiện tại? HFSS dùng license và có thể giải lâu. MATLAB chờ COM trả về.', ...
                           'RUN SIMULATION', 'Options', {'Run Setup1', 'Cancel'}, 'CancelOption', 2);
        if strcmp(choice, 'Run Setup1')
            execute('Analyze Setup1', @doRun);
        end
    end

    function doRun()
        simcfg = readSimulation();
        HFSSSimulationSetup.run(manager, simcfg);
    end

    function exportResults()
        folder = uigetdir(workFolder, 'Thư mục xuất CSV HFSS');
        if isequal(folder, 0)
            return
        end
        HFSSResultExporter.export(manager, simcfg, folder);
    end

    function importCSV()
        if busy
            return
        end
        [f, d] = uigetfile('*.csv', 'CSV thực xuất từ HFSS');
        if isequal(f, 0)
            return
        end
        try
            imported = HFSSResultImporter.read(fullfile(d, f));
            xColumn.Items = imported.headers;
            yColumn.Items = imported.headers;
            phiColumn.Items = imported.headers;
            xColumn.Value = imported.headers{1};
            yColumn.Value = imported.headers{2};
            if numel(imported.headers) > 2
                phiColumn.Value = imported.headers{3};
            end
            plotResults();
        catch ex
            notify(ex.message);
        end
    end

    function plotResults()
        if isempty(imported)
            notify('Import CSV thực trước.');
            return
        end
        try
            x = find(strcmp(imported.headers, xColumn.Value));
            y = find(strcmp(imported.headers, yColumn.Value));
            if startsWith(plotKind.Value, '3D')
                phi = find(strcmp(imported.headers, phiColumn.Value));
                HFSSResultImporter.plot3D(resultAxes, imported, x, phi, y);
            else
                HFSSResultImporter.plot(resultAxes, imported, x, y);
            end
            resultStatus.Text = [manager.ResultsState ' | ' imported.status];
        catch ex
            notify(ex.message);
        end
    end

    function measureHPBW()
        if isempty(imported)
            notify('Import một mặt cắt pattern: góc độ và gain dB.');
            return
        end
        try
            x = find(strcmp(imported.headers, xColumn.Value));
            y = find(strcmp(imported.headers, yColumn.Value));
            r = HFSSResultImporter.hpbw(imported.values(:, x), imported.values(:, y));
            notify(sprintf('%s | HPBW = %.8g deg', r.status, r.widthDeg));
        catch ex
            notify(ex.message);
        end
    end

    function objectTree()
        manager.assertIdentity();
        names = HFSSCAD.names(session);
        debugText.Value = [{'HFSS MODEL OBJECTS'}, names];
        diagnostics.record('OBJECT_TREE', 'PASS', names, 'Names read from HFSS; inspect faces/operations in HFSS Modeler.');
    end

    function showFailed()
        records = diagnostics.Records;
        index = find(strcmp({records.status}, 'FAIL'), 1, 'last');
        if isempty(index)
            notify('Chưa có lỗi ghi nhận.');
        else
            debugText.Value = {records(index).step, records(index).message, jsonencode(records(index).parameters)};
        end
    end

    function exportLogs()
        [f, d] = uiputfile('*.txt', 'Export Log');
        if isequal(f, 0)
            return
        end
        try
            if ~isfile(diagnostics.LogPath)
                diagnostics.record('LOG', 'PENDING', {}, 'Session log initialized.');
            end
            [ok, msg] = copyfile(diagnostics.LogPath, fullfile(d, f));
            assert(ok, 'Vivaldi:Log', '%s', msg);
        catch ex
            notify(ex.message);
        end
    end

    function exportDiagnostics()
        [f, d] = uiputfile('*.json', 'Diagnostic JSON');
        if isequal(f, 0)
            return
        end
        try
            diagnostics.export(fullfile(d, f));
        catch ex
            notify(ex.message);
        end
    end

    function showDependencies()
        graph = vivaldiDependencyGraph(p);
        lines = cell(1, numel(graph));
        for j = 1:numel(graph)
            lines{j} = [graph(j).name ' <- ' strjoin(graph(j).dependsOn, ', ')];
        end
        debugText.Value = lines;
    end

    function openFolder()
        if isempty(manager.WorkingPath)
            folder = fileparts(workingPath.Value);
        else
            folder = fileparts(manager.WorkingPath);
        end
        if ispc && isfolder(folder)
            winopen(folder);
        else
            notify(folder);
        end
    end

    function sessionChanged(alive)
        if closing || ~isvalid(fig)
            return
        end
        if ~alive
            manager.Healthy = false;
            if ~isempty(manager.ResultSignature)
                manager.ResultsState = 'RESULTS OUTDATED — RE-SIMULATION REQUIRED';
                manager.ResultSignature = '';
            end
        end
        refresh();
    end

    function refresh()
        if closing || ~isvalid(fig)
            return
        end
        connectionStatus.Value = {sprintf('Connection: %d | Version: %s | ProgID: %s', session.Connected, session.Version, session.ProgID), ...
                                  ['Active Project: ' manager.ProjectName], ['Active Design: ' manager.DesignName], ...
                                  ['Working Path: ' manager.WorkingPath], ['Mode: ' manager.Mode], ...
                                  ['Last Validation: ' manager.LastValidation.status ' | ' manager.LastValidation.message], ...
                                ['Last Update: ' manager.LastUpdateStatus], ...
                                  sprintf('Unsaved Changes: %d | Geometry healthy: %d', manager.Dirty, manager.Healthy), ...
                                  'Direct COM compatibility: PENDING until Windows integration test report is PASS.'};
        resultStatus.Text = manager.ResultsState;
        if ~isempty(imported)
            resultStatus.Text = [resultStatus.Text ' | Imported CSV provenance unverified'];
        end
        if isempty(diagnostics.Records)
            debugText.Value = {'No HFSS operations yet.'};
        else
            records = diagnostics.Records;
            lines = cell(1, numel(records));
            for j = 1:numel(records)
                lines{j} = [records(j).time ' | ' records(j).step ' | ' records(j).status ' | ' records(j).message];
            end
            debugText.Value = lines;
        end
        draftDifferent = ~isempty(manager.LastValid) && ~isequal(p, manager.LastValid);
        banner.Text = sprintf('COM %d | CAD %s | Unsaved %d | GUI draft differs %d | %s', session.Connected, manager.LastValidation.status, manager.Dirty, draftDifferent, manager.ResultsState);
        fig.UserData.parameters = p;
    end

    function notify(message)
        if ~closing && isvalid(fig)
            if strcmp(opts.Results.Visible, 'off')
                diagnostics.record('UI_MESSAGE', 'PENDING', {}, message);
            else
                uialert(fig, message, 'Vivaldi Live API', 'Icon', 'info');
            end
        end
    end

    function closeApp(~, ~)
        if busy
            notify('Đợi thao tác COM hoàn tất trước khi đóng.');
            return
        end
        if manager.Dirty
            choice = uiconfirm(fig, 'Có thay đổi chưa lưu trong HFSS. Đóng GUI chỉ giải phóng COM handles; HFSS vẫn mở.', ...
                               'Unsaved Changes', 'Options', {'Close GUI', 'Cancel'}, 'CancelOption', 2);
            if strcmp(choice, 'Cancel')
                return
            end
        end
        closing = true;
        delete(monitor);
        session.disconnect();
        delete(fig);
    end

end
