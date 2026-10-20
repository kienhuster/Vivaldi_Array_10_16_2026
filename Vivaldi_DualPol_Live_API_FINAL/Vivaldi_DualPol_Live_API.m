function fig = Vivaldi_DualPol_Live_API(varargin)
    % Mục đích: giao diện tiếng Việt gọn cho hfss-api/VBScript, giữ entry point cũ.
    % Đầu vào: tùy chọn Visible='off' dành cho kiểm thử GUI trên MATLAB desktop.
    % Ghi chú: không có persistent COM trong MATLAB; kết quả HFSS cần status thật.
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'core'), fullfile(root, 'automation'), fullfile(root, 'custom_helpers'), fullfile(root, 'results'));
    assert(~verLessThan('matlab', '9.10'), 'Vivaldi:MATLAB', 'Cần MATLAB R2021a trở lên.');
    parser = inputParser;
    addParameter(parser, 'Visible', 'on');
    parse(parser, varargin{:});
    [p, meta] = vivaldiDefaultParams();
    cfg = VivaldiSimulation('defaults');
    backend = VivaldiHFSS(root);
    work = fullfile(root, 'work');
    if ~isfolder(work)
        mkdir(work);
    end
    valid = true;
    uiBusy = false;
    closing = false;
    imported = [];
    manualColumns = [];
    fig = uifigure('Name', 'Vivaldi hai phân cực — thiết kế bằng HFSS API', 'Position', [70 60 1280 810], ...
                   'Visible', 'off', 'CloseRequestFcn', @closeApp);
    outer = uigridlayout(fig, [2 1]);
    outer.RowHeight = {'1x', 52};
    tabs = uitabgroup(outer);
    banner = uilabel(outer, 'WordWrap', 'on');
    t1 = uitab(tabs, 'Title', 'Thông số anten');
    t2 = uitab(tabs, 'Title', 'Xem trước 3D');
    t3 = uitab(tabs, 'Title', 'Kết nối HFSS');
    t4 = uitab(tabs, 'Title', 'Mô phỏng');
    t5 = uitab(tabs, 'Title', 'Nhật ký & kiểm tra');
    %% 1. Tự tính khi nhập số: chỉ ba nút chính, không giới hạn theo preset
    paramsLayout = uigridlayout(t1, [3 2]);
    paramsLayout.RowHeight = {'1x', 48, 46};
    paramsLayout.ColumnWidth = {'1.2x', '1x'};
    paramsPanel = uipanel(paramsLayout, 'Title', 'Kích thước độc lập (mm, độ)');
    pg = uigridlayout(paramsPanel, [numel(meta) + 6 2]);
    pg.Scrollable = 'on';
    pg.ColumnWidth = {'1x', 140};
    pg.RowHeight = repmat({32}, 1, numel(meta) + 6);
    fields = struct();
    groups = unique({meta.group}, 'stable');
    row = 0;
    for k = 1:numel(groups)
        row = row + 1;
        label = uilabel(pg, 'Text', groupLabel(groups{k}), 'FontWeight', 'bold');
        label.Layout.Row = row;
        label.Layout.Column = [1 2];
        for j = find(strcmp({meta.group}, groups{k}))
            row = row + 1;
            n = meta(j).name;
            label = uilabel(pg, 'Text', [meta(j).label ' (' unitLabel(meta(j).unit) ')'], 'Tooltip', [n ': ' meta(j).tip]);
            label.Layout.Row = row;
            label.Layout.Column = 1;
            fields.(n) = uieditfield(pg, 'numeric', 'Value', p.(n), 'Limits', [-Inf Inf], ...
                                     'ValueDisplayFormat', '%.12g', 'Tag', ['Parameter_' n], 'ValueChangedFcn', @(~, ~)parametersChanged());
            fields.(n).Layout.Row = row;
            fields.(n).Layout.Column = 2;
        end
    end
    derivedPanel = uipanel(paramsLayout, 'Title', 'Thông số dẫn xuất — tự động tính');
    dg = uigridlayout(derivedPanel, [2 1]);
    dg.RowHeight = {'1x', 76};
    derived = uitable(dg, 'ColumnName', {'Biến', 'Giá trị', 'Biểu thức'}, 'ColumnEditable', [false false false]);
    uilabel(dg, 'Text', 'L_patch là chiều dài tổng; L_flare là chiều dài mặt loe. Miền số hợp lệ vẫn cần kiểm tra Boolean, tiếp xúc và cổng trong HFSS.', ...
            'WordWrap', 'on');
    pb = uigridlayout(paramsLayout, [1 3]);
    pb.Layout.Row = 2;
    pb.Layout.Column = [1 2];
    button(pb, 'Chiều dài mục tiêu', @(~, ~)targetLength(), 'TargetLength');
    button(pb, 'Khôi phục mặc định', @(~, ~)resetDefaults(), 'ResetDefaults');
    button(pb, 'Cập nhật HFSS', @(~, ~)execute(@()runAction('update')), 'UpdateHFSS');
    parameterStatus = uilabel(paramsLayout, 'WordWrap', 'on');
    parameterStatus.Layout.Row = 3;
    parameterStatus.Layout.Column = [1 2];
    %% 2. Preview chiếm phần lớn tab, góc nhìn dùng một lựa chọn
    v = uigridlayout(t2, [3 1]);
    v.RowHeight = {36, '1x', 42};
    viewSelect = uidropdown(v, 'Items', {'3D', 'Chính diện', 'Bên cạnh', 'Từ trên'}, 'ValueChangedFcn', @(~, ~)drawPreview());
    preview = uiaxes(v, 'Tag', 'GeometryPreview');
    axtoolbar(preview, {'rotate', 'pan', 'zoomin', 'zoomout', 'restoreview'});
    uilabel(v, 'Text', 'Hình xem trước lấy mẫu từ công thức, chưa phải ảnh CAD HFSS đã kiểm chứng. Dùng công cụ trục để xoay và phóng to.', ...
            'WordWrap', 'on');
    %% 3. Năm thao tác chính; chức năng ít dùng nằm trong menu Nâng cao
    c = uigridlayout(t3, [5 1]);
    c.RowHeight = {32, 34, 50, 90, '1x'};
    uilabel(c, 'Text', 'Đường dẫn dự án làm việc — file tham chiếu ngày 17/10 luôn được bảo vệ:');
    workingPath = uieditfield(c, 'text', 'Value', fullfile(work, 'Vivaldi_DualPol_Working.aedt'), 'Tag', 'WorkingProjectPath');
    cb = uigridlayout(c, [1 5]);
    button(cb, 'Kết nối HFSS', @(~, ~)execute(@()runAction('connect')), 'ConnectHFSS');
    button(cb, 'Mở dự án', @(~, ~)openProject(), 'OpenWorkingProject');
    button(cb, 'Dựng anten mới', @(~, ~)execute(@()runAction('build')), 'BuildFromScratch');
    button(cb, 'Cập nhật mô hình', @(~, ~)execute(@()runAction('update')), 'UpdateGeometry');
    button(cb, 'Lưu dự án', @(~, ~)execute(@()runAction('save')), 'SaveWorkingProject');
    uilabel(c, 'Text', ['MATLAB gọi helper hfss-api để sinh VBScript rồi giao HFSS thực thi. ' ...
                        'Kết nối chỉ ghi nhận lần HFSS phản hồi gần nhất; không phải phiên COM trực tiếp được giữ trong MATLAB. ' ...
                        'Cập nhật chỉ đổi biến trong cùng Working Project, không tự dựng lại hoặc chạy solver.'], 'WordWrap', 'on');
    connectionStatus = uitextarea(c, 'Editable', 'off', 'Tag', 'ConnectionStatus');
    %% 4. Hai nút kỹ thuật chính; đồ thị được chọn bằng một dropdown
    s = uigridlayout(t4, [5 1]);
    s.RowHeight = {94, 46, 36, '1x', 44};
    sg = uigridlayout(s, [2 5]);
    simNames = {'startGHz', 'stopGHz', 'stepGHz', 'adaptiveGHz'};
    labels = {'Tần số bắt đầu (GHz)', 'Tần số kết thúc (GHz)', 'Bước tần số (GHz)', 'Tần số adaptive (GHz)'};
    for k = 1:4
        uilabel(sg, 'Text', labels{k});
    end
    uilabel(sg, 'Text', 'Nguồn kích thích');
    simFields = struct();
    for k = 1:4
        n = simNames{k};
        simFields.(n) = uieditfield(sg, 'numeric', 'Value', cfg.(n), 'ValueDisplayFormat', '%.12g');
    end
    excitation = uidropdown(sg, 'Items', {'Chỉ cổng 1', 'Chỉ cổng 2', 'Tùy chỉnh hai cổng'}, 'ValueChangedFcn', @(~, ~)customExcitation());
    sb = uigridlayout(s, [1 2]);
    button(sb, 'Kiểm tra mô hình', @(~, ~)execute(@()runAction('validate')), 'SimulationValidate');
    button(sb, 'Chạy mô phỏng', @(~, ~)runSimulation(), 'RunSimulation');
    graph = uidropdown(s, 'Items', {'S11', 'S22', 'S21', 'S12', 'VSWR cổng 1', 'VSWR cổng 2', 'Gain', 'Giản đồ bức xạ', 'Giản đồ 3D', 'Trở kháng', 'Hiệu suất'}, ...
                       'ValueChangedFcn', @(~, ~)plotResults(), 'Tag', 'ResultSelection');
    resultAxes = uiaxes(s, 'Tag', 'ResultsAxes');
    resultStatus = uilabel(s, 'Text', 'Chưa mô phỏng', 'WordWrap', 'on', 'Tag', 'ResultsState');
    %% 5. Nhật ký có thể chọn dòng để xem chi tiết, chỉ một nút xuất chính
    z = uigridlayout(t5, [3 1]);
    z.RowHeight = {42, '2x', '1x'};
    button(z, 'Xuất nhật ký', @(~, ~)exportLog(false), 'ExportLog');
    logTable = uitable(z, 'ColumnName', {'Bước', 'Thực thi', 'Hình học', 'Nội dung'}, 'ColumnEditable', [false false false false], ...
                       'CellSelectionCallback', @(~, event)selectLog(event), 'Tag', 'Diagnostics');
    logDetail = uitextarea(z, 'Editable', 'off', 'Value', {'Chọn một dòng nhật ký để xem chi tiết.'});
    %% 6. Menu nâng cao giữ các chức năng kỹ thuật, không thêm nút trùng lặp
    advanced = uimenu(fig, 'Text', 'Nâng cao');
    projectMenu = uimenu(advanced, 'Text', 'Dự án và tham số');
    menu(projectMenu, 'Chọn đường dẫn dự án', @(~, ~)choosePath());
    menu(projectMenu, 'Tạo bản làm việc từ nguồn', @(~, ~)execute(@copyWorking));
    menu(projectMenu, 'Lưu thành phiên bản mới', @(~, ~)execute(@saveAs));
    menu(projectMenu, 'Khôi phục bộ biến hợp lệ trước', @(~, ~)execute(@()runAction('restore')));
    menu(projectMenu, 'Mở lại phiên bản đã lưu', @(~, ~)reloadProject());
    menu(projectMenu, 'Lưu cấu hình JSON', @(~, ~)configuration(true));
    menu(projectMenu, 'Đọc cấu hình JSON', @(~, ~)configuration(false));
    hfssMenu = uimenu(advanced, 'Text', 'HFSS và kiểm tra');
    menu(hfssMenu, 'Chọn chương trình ansysedt.exe', @(~, ~)chooseExecutable());
    menu(hfssMenu, 'Kết nối lại / kiểm tra phản hồi', @(~, ~)execute(@()runAction('connect')));
    menu(hfssMenu, 'Hiện cửa sổ HFSS', @(~, ~)execute(@()runAction('window')));
    menu(hfssMenu, 'Kiểm tra tương thích HFSS API', @(~, ~)execute(@compatibility));
    menu(hfssMenu, 'Dựng và dừng tại từng bước', @(~, ~)execute(@debugBuild));
    menu(hfssMenu, 'Xem cây đối tượng HFSS', @(~, ~)execute(@()runAction('objects')));
    menu(hfssMenu, 'Kiểm tra lại trạng thái job', @(~, ~)pollJob());
    menu(hfssMenu, 'Mở thư mục dự án', @(~, ~)openFolder());
    offlineItem = uimenu(hfssMenu, 'Text', 'Chỉ tạo kịch bản, chưa chạy HFSS', 'Checked', onOff(backend.Offline), 'MenuSelectedFcn', @(~, ~)toggleOffline());
    resultMenu = uimenu(advanced, 'Text', 'Kết quả và chẩn đoán');
    menu(resultMenu, 'Thiết lập solver và nguồn nâng cao', @(~, ~)advancedSolver());
    menu(resultMenu, 'Xuất kết quả thực từ HFSS', @(~, ~)execute(@exportResults));
    menu(resultMenu, 'Nhập CSV thực từ HFSS', @(~, ~)importResults());
    menu(resultMenu, 'Chọn cột đồ thị CSV', @(~, ~)chooseColumns());
    menu(resultMenu, 'Tính độ rộng búp sóng nửa công suất', @(~, ~)measureHPBW());
    menu(resultMenu, 'Xuất chẩn đoán JSON', @(~, ~)exportLog(true));
    menu(resultMenu, 'Xem quan hệ phụ thuộc tham số', @(~, ~)showDependencies());
    fig.UserData = struct('backend', backend, 'parameters', p, 'timer', []);
    parametersChanged();
    refresh();
    timerHandle = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'BusyMode', 'drop', 'TimerFcn', @(~, ~)pollJob());
    fig.UserData.timer = timerHandle;
    start(timerHandle);
    fig.Visible = parser.Results.Visible;

    function b = button(parent, text, callback, tag)
        b = uibutton(parent, 'Text', text, 'ButtonPushedFcn', callback, 'Tag', tag);
    end

    function menu(parent, text, callback)
        uimenu(parent, 'Text', text, 'MenuSelectedFcn', callback);
    end

    function parametersChanged()
        if closing || uiBusy
            return
        end
        for n = fieldnames(fields)'
            p.(n{1}) = fields.(n{1}).Value;
        end
        [valid, errors, ~, g] = vivaldiValidateParams(p);
        if valid
            rows = {};
            for j = 1:size(g.expressions, 1)
                n = g.expressions{j, 1};
                if ~isfield(p, n)
                    rows(end + 1, :) = {n, g.(n), g.expressions{j, 2}};
                end %#ok<AGROW>
            end
            derived.Data = rows;
            parameterStatus.Text = sprintf('L_patch = %.9f mm; L_flare = %.9f mm. Đại số hợp lệ, CAD cần kiểm tra HFSS.', g.L_patch, g.L_flare);
            drawPreview();
        else
            derived.Data = {};
            parameterStatus.Text = strjoin(errors, ' | ');
        end
        fig.UserData.parameters = p;
    end

    function setParameters(q)
        p = q;
        for n = fieldnames(fields)'
            fields.(n{1}).Value = p.(n{1});
        end
    end

    function drawPreview()
        if ~valid || closing
            return
        end
        views = {'3D', 'front', 'side', 'top'};
        items = {'3D', 'Chính diện', 'Bên cạnh', 'Từ trên'};
        try
            vivaldiPreview3D(preview, p, [], struct('view', views{strcmp(items, viewSelect.Value)}, 'dimensions', true, 'coax', true));
        catch ex
            parameterStatus.Text = ['Không tạo được xem trước: ' ex.message];
        end
    end

    function resetDefaults()
        if ~isempty(backend.ActiveJob)
            return
        end
        setParameters(vivaldiDefaultParams());
        parametersChanged();
    end

    function targetLength()
        if ~isempty(backend.ActiveJob)
            return
        end
        answer = inputdlg('Chiều dài tổng L_patch mục tiêu (mm):', 'Chiều dài mục tiêu', 1, {'57.35'});
        if isempty(answer)
            return
        end
        try
            [q, r] = vivaldiSolveTargetLength(p, str2double(answer{1}));
            setParameters(q);
            parametersChanged();
            notify(sprintf('Đã tìm L_flare_1 = %.12g mm; sai số %.3g mm.', q.L_flare_1, r.residual));
        catch ex
            notify(ex.message);
        end
    end

    function execute(operation)
        if uiBusy || closing
            return
        end
        if ~isempty(backend.ActiveJob)
            notify('Tác vụ HFSS trước chưa kết thúc; kiểm tra nhật ký hoặc trạng thái.');
            return
        end
        parametersChanged();
        uiBusy = true;
        try
            operation();
        catch ex
            backend.LastState = 'FAIL';
            backend.LastMessage = ex.message;
            notify(ex.message);
        end
        uiBusy = false;
        refresh();
    end

    function runAction(action, extra)
        if nargin < 2
            extra = struct();
        end
        c = extra;
        c.projectPath = workingPath.Value;
        c.simulation = readSimulation();
        q = p;
        if ~ismember(action, {'build', 'update', 'connect', 'open', 'reload'})
            if ~isempty(backend.LastValid)
                q = backend.LastValid;
            elseif isfile(workingPath.Value)
                q = VivaldiHFSS.paramsFromFile(workingPath.Value);
            end
        end
        if ismember(action, {'build', 'update'})
            assert(valid, 'Vivaldi:Parameters', 'Sửa các thông số không hợp lệ trước.');
        end
        backend.start(action, q, c);
    end

    function openProject()
        if ~isempty(backend.ActiveJob)
            return
        end
        [f, d] = uigetfile('*.aedt', 'Mở Working Project', workingPath.Value);
        if isequal(f, 0)
            return
        end
        workingPath.Value = fullfile(d, f);
        execute(@()runAction('open'));
    end

    function choosePath()
        if ~isempty(backend.ActiveJob)
            return
        end
        [f, d] = uiputfile('*.aedt', 'Chọn tên Working Project', workingPath.Value);
        if ~isequal(f, 0)
            workingPath.Value = fullfile(d, f);
        end
    end

    function copyWorking()
        backend.copyReference(workingPath.Value);
        runAction('open');
    end

    function saveAs()
        [f, d] = uiputfile('*.aedt', 'Lưu thành phiên bản mới', workingPath.Value);
        if isequal(f, 0)
            return
        end
        runAction('saveas', struct('destination', fullfile(d, f)));
    end

    function reloadProject()
        choice = uiconfirm(fig, 'Bỏ thay đổi chưa lưu trong Working Project và mở lại bản lưu?', 'Mở lại dự án', 'Options', {'Mở lại', 'Hủy'}, 'CancelOption', 2);
        if strcmp(choice, 'Mở lại')
            execute(@()runAction('reload'));
        end
    end

    function debugBuild()
        runAction('build', struct('debug', true));
    end

    function chooseExecutable()
        [f, d] = uigetfile('*.exe', 'Chọn ansysedt.exe', backend.Executable);
        if ~isequal(f, 0)
            backend.Executable = fullfile(d, f);
            refresh();
        end
    end

    function toggleOffline()
        if ~isempty(backend.ActiveJob)
            notify('Không đổi chế độ khi job chưa kết thúc.');
            return
        end
        backend.Offline = ~backend.Offline;
        offlineItem.Checked = onOff(backend.Offline);
        refresh();
    end

    function compatibility()
        addpath(fullfile(root, 'tests'));
        report = runHFSSAPIIntegration(fullfile(work, 'kiem_tra_api'), backend.Executable, false);
        notify([statusLabel(report.status) ': ' report.message]);
    end

    function c = readSimulation()
        c = cfg;
        for n = simNames
            c.(n{1}) = simFields.(n{1}).Value;
        end
        if strcmp(excitation.Value, 'Chỉ cổng 1')
            c.powerW = [1 0];
            c.phaseDeg = [0 0];
        elseif strcmp(excitation.Value, 'Chỉ cổng 2')
            c.powerW = [0 1];
            c.phaseDeg = [0 0];
        end
        VivaldiSimulation('validate', c);
    end

    function customExcitation()
        if ~strcmp(excitation.Value, 'Tùy chỉnh hai cổng')
            return
        end
        a = inputdlg({'Công suất cổng 1 (W)', 'Công suất cổng 2 (W)', 'Pha cổng 1 (độ)', 'Pha cổng 2 (độ)'}, ...
                     'Nguồn kích thích', 1, cellfun(@num2str, num2cell([cfg.powerW cfg.phaseDeg]), 'UniformOutput', false));
        if isempty(a)
            return
        end
        try
            v = cellfun(@str2double, a);
            trial = cfg;
            trial.powerW = v(1:2)';
            trial.phaseDeg = v(3:4)';
            VivaldiSimulation('validate', trial);
            cfg = trial;
        catch ex
            notify(ex.message);
        end
    end

    function advancedSolver()
        a = inputdlg({'Sai số hội tụ delta S', 'Số vòng tối thiểu', 'Số vòng tối đa', 'Tần số trường xa (GHz)'}, ...
                     'Thiết lập solver nâng cao', 1, cellfun(@num2str, num2cell([cfg.deltaS cfg.minimumPasses cfg.maximumPasses cfg.fieldGHz]), 'UniformOutput', false));
        if isempty(a)
            return
        end
        try
            v = cellfun(@str2double, a);
            trial = cfg;
            trial.deltaS = v(1);
            trial.minimumPasses = v(2);
            trial.maximumPasses = v(3);
            trial.fieldGHz = v(4);
            VivaldiSimulation('validate', trial);
            cfg = trial;
        catch ex
            notify(ex.message);
        end
    end

    function runSimulation()
        choice = uiconfirm(fig, 'Chạy riêng Setup1 với cấu hình hiện tại? HFSS cần license và thời gian giải.', 'Chạy mô phỏng', 'Options', {'Chạy', 'Hủy'}, 'CancelOption', 2);
        if strcmp(choice, 'Chạy')
            execute(@()runAction('simulate'));
        end
    end

    function exportResults()
        folder = uigetdir(work, 'Thư mục xuất CSV kết quả thực');
        if isequal(folder, 0)
            return
        end
        runAction('reports', struct('resultsDir', folder));
    end

    function importResults()
        [f, d] = uigetfile('*.csv', 'Chọn CSV thật xuất từ HFSS');
        if isequal(f, 0)
            return
        end
        try
            imported = HFSSResultImporter.read(fullfile(d, f));
            manualColumns = [];
            plotResults();
        catch ex
            notify(ex.message);
        end
    end

    function plotResults()
        try
            choice = graph.Value;
            reportLabels = {'SParameters', 'SParameters', 'SParameters', 'SParameters', 'VSWR', 'VSWR', 'Gain', 'Pattern', 'Pattern3D', 'Impedance', 'Efficiency'};
            items = graph.Items;
            idx = find(strcmp(items, choice));
            if ~isempty(backend.LastReports)
                match = find(strcmp({backend.LastReports.label}, reportLabels{idx}), 1, 'last');
                if ~isempty(match) && (isempty(imported) || ~strcmp(imported.path, backend.LastReports(match).path))
                    imported = HFSSResultImporter.read(backend.LastReports(match).path);
                    manualColumns = [];
                end
            end
            if isempty(imported)
                resultStatus.Text = 'Chưa có dữ liệu. Chọn Nâng cao → Kết quả và chẩn đoán → Nhập CSV thực từ HFSS.';
                return
            end
            expressions = {'dB(S(1,1))', 'dB(S(2,2))', 'dB(S(2,1))', 'dB(S(1,2))', 'VSWR(1)', 'VSWR(2)', 'dB(RealizedGainTotal)', 'dB(RealizedGainTotal)', 'dB(RealizedGainTotal)', 're(Z(1,1))', 'RadiationEfficiency'};
            x = 1;
            y = find(cellfun(@(h)~isempty(strfind(h, expressions{idx})), imported.headers), 1); %#ok<STREMP>
            if ~isempty(manualColumns)
                x = manualColumns(1);
                y = manualColumns(2);
            end
            assert(~isempty(y), 'Vivaldi:CSV', 'Không nhận diện cột kết quả; dùng menu Chọn cột đồ thị CSV.');
            if strcmp(choice, 'Giản đồ 3D')
                theta = find(cellfun(@(h)~isempty(strfind(h, 'Theta')), imported.headers), 1);
                phi = find(cellfun(@(h)~isempty(strfind(h, 'Phi')), imported.headers), 1); %#ok<STREMP>
                if numel(manualColumns) == 3
                    theta = x;
                    phi = manualColumns(3);
                end
                assert(~isempty(theta) && ~isempty(phi), 'Vivaldi:CSV', 'Cần cột Theta và Phi theo độ cho giản đồ 3D.');
                HFSSResultImporter.plot3D(resultAxes, imported, theta, phi, y);
            else
                HFSSResultImporter.plot(resultAxes, imported, x, y);
            end
            resultStatus.Text = [backend.ResultsState ' | CSV riêng chưa xác nhận trùng hình học hiện tại.'];
        catch ex
            notify(ex.message);
        end
    end

    function chooseColumns()
        if isempty(imported)
            notify('Nhập CSV trước khi chọn cột.');
            return
        end
        [x, ok] = listdlg('ListString', imported.headers, 'SelectionMode', 'single', 'PromptString', 'Chọn cột X / Theta');
        if ~ok
            return
        end
        [y, ok] = listdlg('ListString', imported.headers, 'SelectionMode', 'single', 'PromptString', 'Chọn cột Y / Gain');
        if ~ok
            return
        end
        manualColumns = [x y];
        if strcmp(graph.Value, 'Giản đồ 3D')
            [phi, ok] = listdlg('ListString', imported.headers, 'SelectionMode', 'single', 'PromptString', 'Chọn cột Phi');
            if ok
                manualColumns(3) = phi;
            end
        end
        plotResults();
    end

    function measureHPBW()
        if isempty(imported)
            notify('Nhập một mặt cắt góc độ và gain dB trước.');
            return
        end
        try
            if isempty(manualColumns)
                columns = [1 2];
            else
                columns = manualColumns;
            end
            r = HFSSResultImporter.hpbw(imported.values(:, columns(1)), imported.values(:, columns(2)));
            notify(sprintf('%s; độ rộng búp sóng = %.8g độ.', statusLabel(r.status), r.widthDeg));
        catch ex
            notify(ex.message);
        end
    end

    function exportLog(asJSON)
        if asJSON
            filter = '*.json';
        else
            filter = '*.txt';
        end
        [f, d] = uiputfile(filter, 'Xuất nhật ký');
        if isequal(f, 0)
            return
        end
        try
            backend.exportLog(fullfile(d, f));
        catch ex
            notify(ex.message);
        end
    end

    function selectLog(event)
        if isempty(event.Indices)
            return
        end
        k = event.Indices(1, 1);
        r = backend.Records(k);
        logDetail.Value = {['Bước: ' r.step], ['Thực thi: ' statusLabel(r.execution)], ['Hình học: ' statusLabel(r.geometry)], r.message, ...
                           ['Dự án: ' backend.WorkingPath], ['Thông số tác vụ: ' jobParameters()]};
    end

    function out = jobParameters()
        if isempty(backend.LastJob)
            out = jsonencode(p);
        else
            out = jsonencode(backend.LastJob.params);
        end
    end

    function showDependencies()
        g = vivaldiDependencyGraph(p);
        lines = cell(1, numel(g));
        for j = 1:numel(g)
            lines{j} = [g(j).name ' ← ' strjoin(g(j).dependsOn, ', ')];
        end
        logDetail.Value = lines;
    end

    function configuration(save)
        if ~isempty(backend.ActiveJob)
            notify('Đợi job hiện tại hoàn tất trước khi đổi cấu hình.');
            return
        end
        try
            if save
                [f, d] = uiputfile('*.json', 'Lưu cấu hình tùy chọn');
                if isequal(f, 0)
                    return
                end
                vivaldiWriteJSON(fullfile(d, f), struct('schema', 'VivaldiHFSSAPI/2', 'parameters', p));
            else
                [f, d] = uigetfile('*.json', 'Đọc cấu hình tùy chọn');
                if isequal(f, 0)
                    return
                end
                value = jsondecode(fileread(fullfile(d, f)));
                [ok, e] = vivaldiValidateParams(value.parameters);
                assert(ok, 'Vivaldi:Config', '%s', strjoin(e, newline));
                setParameters(value.parameters);
                parametersChanged();
            end
        catch ex
            notify(ex.message);
        end
    end

    function openFolder()
        folder = fileparts(workingPath.Value);
        if ispc && isfolder(folder)
            winopen(folder);
        else
            notify(folder);
        end
    end

    function pollJob()
        if closing || uiBusy || ~isvalid(fig)
            return
        end
        hadJob = ~isempty(backend.ActiveJob);
        action = '';
        if hadJob
            action = backend.ActiveJob.action;
        end
        try
            backend.poll();
            if hadJob && isempty(backend.ActiveJob) && ~isempty(backend.LastValid) && ismember(action, {'build', 'open', 'reload', 'update', 'restore'})
                setParameters(backend.LastValid);
                parametersChanged();
                workingPath.Value = backend.WorkingPath;
            end
            refresh();
            if hadJob && isempty(backend.ActiveJob) && strcmp(action, 'objects')
                logDetail.Value = [{'Cây đối tượng HFSS'}, backend.LastObjects];
            end
            if ~isempty(backend.WorkingPath)
                workingPath.Value = backend.WorkingPath;
            end
        catch ex
            backend.Healthy = false;
            backend.LastMessage = ['Chưa xác nhận trạng thái: ' ex.message];
            refresh();
        end
    end

    function refresh()
        if closing || ~isvalid(fig)
            return
        end
        if backend.Offline
            mode = 'Chỉ tạo kịch bản — chưa chạy HFSS';
        else
            mode = 'Sinh và chạy VBScript qua hfss-api';
        end
        connectionStatus.Value = {['Cơ chế: ' mode], ['HFSS (lần phản hồi gần nhất): ' onOffVietnamese(backend.Connected)], ...
                                  ['Phiên bản: ' backend.Version], ['Dự án: ' backend.WorkingPath], ...
                                  'Thiết kế HFSS: dual_pol_vivaldi_patch_Wflare_20', ['Chương trình: ' backend.Executable], ...
                                  ['Trạng thái: ' statusLabel(backend.LastState)], ['Chưa lưu: ' onOffVietnamese(backend.Dirty)], backend.LastMessage};
        rows = cell(numel(backend.Records), 4);
        for j = 1:numel(backend.Records)
            r = backend.Records(j);
            rows(j, :) = {r.step, statusLabel(r.execution), statusLabel(r.geometry), r.message};
        end
        logTable.Data = rows;
        draft = ~isempty(backend.LastValid) && ~isequal(p, backend.LastValid);
        banner.Text = sprintf('%s | %s | Thông số đang nhập khác mô hình HFSS: %s', mode, backend.LastMessage, onOffVietnamese(draft));
        resultStatus.Text = backend.ResultsState;
        enabled = onOff(isempty(backend.ActiveJob));
        for n = fieldnames(fields)'
            fields.(n{1}).Enable = enabled;
        end
        buttons = findall(fig, 'Type', 'uibutton');
        for j = 1:numel(buttons)
            if ~strcmp(buttons(j).Tag, 'ExportLog')
                buttons(j).Enable = enabled;
            end
        end
        fig.UserData.parameters = p;
    end

    function notify(message)
        if closing || ~isvalid(fig)
            return
        end
        if strcmp(parser.Results.Visible, 'off')
            backend.LastMessage = message;
        else
            uialert(fig, message, 'Thông báo Vivaldi', 'Icon', 'info');
        end
    end

    function closeApp(~, ~)
        if ~isempty(backend.ActiveJob) || backend.Dirty
            choice = uiconfirm(fig, 'Đóng giao diện? HFSS có thể còn chạy hoặc có thay đổi chưa lưu; ứng dụng không tự đóng HFSS.', 'Đóng chương trình', 'Options', {'Đóng', 'Hủy'}, 'CancelOption', 2);
            if strcmp(choice, 'Hủy')
                return
            end
        end
        closing = true;
        stop(timerHandle);
        delete(timerHandle);
        delete(fig);
    end

end

function out = groupLabel(in)
    % Tên nhóm chỉ dùng tiếng Việt; tên biến giữ nguyên để tương thích AEDT.
    names = {'Flare & Aperture', 'Slot & Transition', 'Cavity & Feed', 'Metal & Base', 'Coaxial Structure', 'Advanced Parameters'};
    values = {'Phần loe', 'Đoạn chuyển tiếp và khe', 'Cavity và cấp nguồn', 'Độ dày và đế', 'Cáp đồng trục', 'Tham số mở rộng'};
    k = find(strcmp(names, in), 1);
    if isempty(k)
        out = 'Thông số khác';
    else
        out = values{k};
    end
end

function out = unitLabel(in)
    if strcmp(in, 'deg')
        out = 'độ';
    else
        out = in;
    end
end

function out = onOff(value)
    if value
        out = 'on';
    else
        out = 'off';
    end
end

function out = onOffVietnamese(value)
    if value
        out = 'Có';
    else
        out = 'Không';
    end
end

function out = statusLabel(value)
    keys = {'PASS', 'FAIL', 'PENDING', 'UNSUPPORTED', 'SCRIPT_READY', 'RUNNING', 'TIMED_OUT', 'FAILED', 'FAILED_ROLLED_BACK', 'CONNECTED', 'BUILT', 'ATTACHED', 'UPDATED', 'VALIDATED', 'RESTORED', 'SAVED', 'SIMULATED', 'REPORTS', 'WINDOW', 'OBJECTS'};
    values = {'Đạt', 'Lỗi', 'Chờ kiểm chứng', 'Chưa hỗ trợ', 'Đã tạo kịch bản, chưa chạy', 'Đang thực hiện', 'Quá thời gian chờ', 'Thất bại', 'Thất bại, đã phục hồi', 'Đã nhận phản hồi HFSS', 'Đã dựng và kiểm tra', 'Đã mở và kiểm tra', 'Đã cập nhật', 'Đã kiểm tra', 'Đã phục hồi', 'Đã lưu', 'Có dữ liệu mô phỏng thực', 'Đã xuất kết quả', 'Đã hiện cửa sổ HFSS', 'Đã đọc cây đối tượng'};
    k = find(strcmp(keys, value), 1);
    if isempty(k)
        out = 'Chờ kiểm chứng';
    else
        out = values{k};
    end
end
