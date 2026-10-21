function fig = Vivaldi_GUI(varargin)
% Mục đích: nhập kích thước, xem trước và chủ động dựng một anten HFSS mới mỗi lần bấm.
% Không tạo/mở project lúc khởi động; không có Live Update hoặc Working Project.
root = fileparts(mfilename('fullpath'));
library = Vivaldi_HFSS_Builder('initialize');
assert(strcmp(library.paths.root, root), 'Vivaldi:LibraryConflict', ...
    'Builder không cùng thư mục GUI. Mong đợi: %s. MATLAB đang nhận: %s.', root, library.paths.root);
[p, meta] = Vivaldi_Calculation('defaults');
job = []; built = []; busy = false; lastLog = ''; warned = false;
jobTimer = []; %#ok<NASGU>
fig = uifigure('Name', 'Vivaldi Dual-Pol — Dựng anten mới', 'Position', [80 60 1250 820], varargin{:});
fig.CloseRequestFcn = @closeWindow;
layout = uigridlayout(fig, [1 1]);
tabs = uitabgroup(layout);
t1 = uitab(tabs, 'Title', 'Thông số anten');
t2 = uitab(tabs, 'Title', 'Xem trước 3D');
t3 = uitab(tabs, 'Title', 'Tạo anten HFSS');
t4 = uitab(tabs, 'Title', 'Mô phỏng');
t5 = uitab(tabs, 'Title', 'Nhật ký');

%% 1. Ô nhập số thực tự do; công thức và xem trước tự tính khi nhập hợp lệ
paramsGrid = uigridlayout(t1, [numel(meta) + 3 3]);
paramsGrid.RowHeight = [repmat({27}, 1, numel(meta)), {32, 48, '1x'}];
paramsGrid.ColumnWidth = {285, 145, '1x'}; paramsGrid.Scrollable = 'on';
fields = struct();
for k = 1:numel(meta)
    label = uilabel(paramsGrid, 'Text', [meta(k).label ' (' meta(k).unit ')']);
    label.Layout.Row = k; label.Layout.Column = 1;
    fields.(meta(k).name) = uieditfield(paramsGrid, 'numeric', 'Value', p.(meta(k).name), ...
        'Limits', [-Inf Inf], 'ValueChangedFcn', @parameterChanged, 'Tooltip', meta(k).tip);
    fields.(meta(k).name).Layout.Row = k; fields.(meta(k).name).Layout.Column = 2;
    helpLabel = uilabel(paramsGrid, 'Text', meta(k).name, 'Interpreter', 'none');
    helpLabel.Layout.Row = k; helpLabel.Layout.Column = 3;
end
defaultButton = uibutton(paramsGrid, 'Text', 'Khôi phục mặc định', 'ButtonPushedFcn', @resetDefaults);
defaultButton.Layout.Row = numel(meta) + 1; defaultButton.Layout.Column = [1 2];
derived = uilabel(paramsGrid, 'Text', '', 'WordWrap', 'on');
derived.Layout.Row = numel(meta) + 2; derived.Layout.Column = [1 3];
parameterStatus = uilabel(paramsGrid, 'Text', '', 'WordWrap', 'on');
parameterStatus.Layout.Row = numel(meta) + 3; parameterStatus.Layout.Column = [1 3];

%% 2. Xem trước theo công thức, tách biệt xác nhận hình học HFSS thật
previewGrid = uigridlayout(t2, [2 1]); previewGrid.RowHeight = {30, '1x'};
viewChoice = uidropdown(previewGrid, 'Items', {'3D', 'Chính diện', 'Bên cạnh', 'Từ trên'}, ...
    'ItemsData', {'3D', 'front', 'side', 'top'}, 'ValueChangedFcn', @parameterChanged);
preview = uiaxes(previewGrid);

%% 3. Thư mục xuất và Ansys; mỗi lệnh dựng sinh một tên AEDT mới
buildGrid = uigridlayout(t3, [7 3]);
buildGrid.RowHeight = {35, 35, 45, 45, 30, 65, '1x'}; buildGrid.ColumnWidth = {150, '1x', 150};
uilabel(buildGrid, 'Text', 'Thư mục xuất');
outputField = uieditfield(buildGrid, 'text', 'Value', fullfile(root, 'output'));
outputChoose = uibutton(buildGrid, 'Text', 'Chọn thư mục', 'ButtonPushedFcn', @chooseOutput);
uilabel(buildGrid, 'Text', 'Ansys 2021 R2');
exeField = uieditfield(buildGrid, 'text', 'Value', detectExecutable());
exeChoose = uibutton(buildGrid, 'Text', 'Chọn Ansys', 'ButtonPushedFcn', @chooseExecutable);
createButton = uibutton(buildGrid, 'Text', 'Tạo anten HFSS', 'ButtonPushedFcn', @createAntenna);
createButton.Layout.Row = 3; createButton.Layout.Column = [1 3];
openButton = uibutton(buildGrid, 'Text', 'Mở file HFSS vừa tạo', 'Enable', 'off', 'ButtonPushedFcn', @openAntenna);
openButton.Layout.Row = 4; openButton.Layout.Column = [1 3];
debugChoice = uicheckbox(buildGrid, 'Text', 'Lưu CAD debug riêng nếu gặp lỗi (chưa hoàn chỉnh)', 'Value', false);
debugChoice.Layout.Row = 5; debugChoice.Layout.Column = [1 3];
createdPath = uilabel(buildGrid, 'Text', 'Chưa tạo anten. Mỗi lần tạo sẽ dùng một file mới.', 'WordWrap', 'on', 'Interpreter', 'none');
createdPath.Layout.Row = 6; createdPath.Layout.Column = [1 3];
buildStatus = uilabel(buildGrid, 'Text', 'Chưa khởi chạy HFSS.', 'WordWrap', 'on');
buildStatus.Layout.Row = 7; buildStatus.Layout.Column = [1 3];

%% 4. Chỉ chạy solver khi người dùng bấm, chỉ vẽ CSV xuất từ HFSS thật
simGrid = uigridlayout(t4, [8 2]);
simGrid.RowHeight = {28, 28, 28, 28, 28, 40, 30, '1x'}; simGrid.ColumnWidth = {240, '1x'};
cfg = Vivaldi_HFSS_Simulation('defaults'); simulationFields = struct();
simNames = {'startGHz', 'stopGHz', 'stepGHz', 'adaptiveGHz'};
simLabels = {'Tần số bắt đầu (GHz)', 'Tần số kết thúc (GHz)', 'Bước tần số (GHz)', 'Tần số adaptive (GHz)'};
for k = 1:numel(simNames)
    uilabel(simGrid, 'Text', simLabels{k});
    simulationFields.(simNames{k}) = uieditfield(simGrid, 'numeric', 'Value', cfg.(simNames{k}), 'Limits', [0 Inf]);
end
uilabel(simGrid, 'Text', 'Nguồn kích thích');
sourceChoice = uidropdown(simGrid, 'Items', {'Cổng 1: 1 W; cổng 2: 0 W', 'Cổng 1: 0 W; cổng 2: 1 W'}, 'ItemsData', [1 2]);
simulateButton = uibutton(simGrid, 'Text', 'Chạy mô phỏng', 'Enable', 'off', 'ButtonPushedFcn', @simulateAntenna);
simulateButton.Layout.Row = 6; simulateButton.Layout.Column = [1 2];
reportChoice = uidropdown(simGrid, 'Items', {'Chưa có kết quả thực'}, 'Enable', 'off', 'ValueChangedFcn', @plotResult);
reportChoice.Layout.Row = 7; reportChoice.Layout.Column = [1 2];
resultAxes = uiaxes(simGrid); resultAxes.Layout.Row = 8; resultAxes.Layout.Column = [1 2];
title(resultAxes, 'Chưa có kết quả mô phỏng HFSS');

%% 5. Nhật ký nguyên văn với checkpoint đo CAD; không suy diễn PASS trên Linux
logGrid = uigridlayout(t5, [1 1]);
logArea = uitextarea(logGrid, 'Editable', 'off', 'Value', {'Sẵn sàng. Chưa tạo project hoặc chạy solver.'});
jobTimer = timer('ExecutionMode', 'fixedSpacing', 'Period', 1, 'BusyMode', 'drop', 'TimerFcn', @pollJob);
parameterChanged();

    function parameterChanged(varargin)
        % Tính từ các ô hiện tại, không tự gửi lệnh sang HFSS.
        for name = fieldnames(fields)', p.(name{1}) = fields.(name{1}).Value; end
        [valid, errors, warnings, g] = Vivaldi_Calculation('validate', p);
        if valid
            derived.Text = sprintf('L_patch = %.10g mm | L_flare = %.10g mm | r_flare = %.10g /mm | x_feed = %.10g mm | z_feed = %.10g mm', ...
                g.L_patch, g.L_flare, g.r_flare, g.x_feed, g.z_feed);
            parameterStatus.Text = strjoin(warnings, newline);
            try
                vivaldiPreview3D(preview, p, g, struct('view', viewChoice.Value));
            catch err
                cla(preview); title(preview, 'Không tạo được xem trước');
                parameterStatus.Text = [parameterStatus.Text newline err.message];
            end
        else
            derived.Text = 'Thông số không hợp lệ.'; parameterStatus.Text = strjoin(errors, newline);
            cla(preview); title(preview, 'Sửa thông số trước khi tạo anten');
        end
    end

    function resetDefaults(varargin)
        defaults = Vivaldi_Calculation('defaults');
        for name = fieldnames(fields)', fields.(name{1}).Value = defaults.(name{1}); end
        parameterChanged();
    end

    function chooseOutput(varargin)
        folder = uigetdir(pwd, 'Chọn thư mục lưu các anten mới');
        if ~isequal(folder, 0), outputField.Value = folder; end
    end

    function chooseExecutable(varargin)
        [name, folder] = uigetfile('*.exe', 'Chọn ansysedt.exe của Ansys 2021 R2');
        if ~isequal(name, 0), exeField.Value = fullfile(folder, name); end
    end

    function c = simulationConfig()
        c = Vivaldi_HFSS_Simulation('defaults');
        for name = simNames, c.(name{1}) = simulationFields.(name{1}).Value; end
        c.fieldGHz = c.adaptiveGHz;
        if sourceChoice.Value == 2, c.powerW = [0 1]; end
        Vivaldi_HFSS_Simulation('validate', c);
    end

    function createAntenna(varargin)
        % Chỉ ở callback này mới tạo script/project; tham số mỗi lần là snapshot riêng.
        if busy, return; end
        try
            assert(ispc && isfile(exeField.Value), 'Vivaldi:HFSS', 'Cần Windows và đường dẫn ansysedt.exe hợp lệ.');
            parameterChanged();
            candidate = Vivaldi_HFSS_Builder('generate', p, outputField.Value, simulationConfig(), 'full', debugChoice.Value);
            job = Vivaldi_HFSS_Builder('launch', candidate, exeField.Value);
            built = []; createdPath.Text = ['Đang dựng, chưa xác nhận file: ' job.projectPath];
            reportChoice.Enable = 'off'; cla(resultAxes);
            title(resultAxes, 'Chưa có kết quả cho anten mới');
            beginJob();
        catch err, showError(err); end
    end

    function openAntenna(varargin)
        try, Vivaldi_HFSS_Builder('open', built, exeField.Value);
        catch err, showError(err); end
    end

    function simulateAntenna(varargin)
        if busy, return; end
        try
            candidate = Vivaldi_HFSS_Builder('simulate', built, simulationConfig());
            job = Vivaldi_HFSS_Builder('launch', candidate, exeField.Value);
            reportChoice.Enable = 'off'; cla(resultAxes);
            title(resultAxes, 'Đang đợi kết quả HFSS thực');
            beginJob();
        catch err, showError(err); end
    end

    function beginJob()
        lastLog = ''; warned = false; busy = true; setControls();
        logArea.Value = {['Đã khởi chạy. Script: ' job.scriptPath], 'Chưa nhận xác nhận hoàn tất từ HFSS.'};
        buildStatus.Text = 'Đang đợi HFSS phản hồi; chưa xác nhận dựng thành công.';
        tabs.SelectedTab = t5; start(jobTimer);
    end

    function pollJob(varargin)
        % Chỉ chấp nhận đúng JOB id, VERIFIED và file thật sau terminal hoàn chỉnh.
        if ~busy || ~isvalid(fig), return; end
        try
            job = Vivaldi_HFSS_Builder('poll', job);
            if ~strcmp(lastLog, job.log) && ~isempty(job.log)
                logArea.Value = regexp(job.log, '\r?\n', 'split'); lastLog = job.log;
            end
            if ismember(job.state, {'SUCCEEDED', 'FAILED'})
                stop(jobTimer); busy = false;
                if strcmp(job.state, 'SUCCEEDED')
                    if strcmp(job.action, 'build')
                        built = job; createdPath.Text = ['File đã tạo: ' built.projectPath];
                        buildStatus.Text = 'HFSS đã hoàn tất kiểm tra CAD và lưu AEDT mới. Xem phạm vi phép đo trong nhật ký.';
                    else
                        buildStatus.Text = 'Mô phỏng đã hoàn tất; chỉ hiển thị các báo cáo có dữ liệu HFSS thực.';
                        reports = dir(fullfile(job.jobFolder, '*.csv'));
                        assert(~isempty(reports), 'Vivaldi:Results', 'HFSS chưa xuất CSV.');
                        reportChoice.Items = {reports.name};
                        reportChoice.ItemsData = cellfun(@(n)fullfile(job.jobFolder, n), {reports.name}, 'UniformOutput', false);
                        reportChoice.Value = reportChoice.ItemsData{1}; reportChoice.Enable = 'on';
                        plotResult();
                    end
                else
                    buildStatus.Text = 'HFSS báo lỗi. Không xác nhận anten hoàn chỉnh; xem checkpoint trong Nhật ký.';
                end
                setControls();
            elseif ~warned && (now - job.started) * 86400 > 600
                warned = true; buildStatus.Text = 'Đã đợi hơn 10 phút. Vẫn chờ HFSS; kiểm tra cửa sổ Ansys và Nhật ký.';
            end
        catch err
            stop(jobTimer); busy = false; job.state = 'FAILED'; setControls(); showError(err);
        end
    end

    function plotResult(varargin)
        try, Vivaldi_HFSS_Simulation('plot', reportChoice.Value, resultAxes);
        catch err, showError(err); end
    end

    function setControls()
        value = 'on'; if busy, value = 'off'; end
        createButton.Enable = value; defaultButton.Enable = value;
        outputChoose.Enable = value; exeChoose.Enable = value;
        outputField.Enable = value; exeField.Enable = value;
        for name = fieldnames(fields)', fields.(name{1}).Enable = value; end
        for name = simNames, simulationFields.(name{1}).Enable = value; end
        sourceChoice.Enable = value; debugChoice.Enable = value;
        canUse = ~busy && ~isempty(built) && strcmp(built.state, 'SUCCEEDED');
        openButton.Enable = 'off'; simulateButton.Enable = 'off';
        if canUse, openButton.Enable = 'on'; simulateButton.Enable = 'on'; end
    end

    function showError(err)
        logArea.Value = [cellstr(logArea.Value); {[err.identifier ': ' err.message]}];
        uialert(fig, err.message, 'Lỗi Vivaldi');
    end

    function closeWindow(varargin)
        % Đóng GUI không kết thúc process HFSS đang dựng/solve.
        if busy
            answer = uiconfirm(fig, 'HFSS vẫn đang chạy và sẽ tiếp tục ghi nhật ký. Đóng giao diện?', ...
                'Đang thực thi HFSS', 'Options', {'Đóng giao diện', 'Tiếp tục theo dõi'}, 'DefaultOption', 2, 'CancelOption', 2);
            if strcmp(answer, 'Tiếp tục theo dõi'), return; end
        end
        if ~isempty(jobTimer) && isvalid(jobTimer), stop(jobTimer); delete(jobTimer); end
        delete(fig);
    end
end

function exe = detectExecutable()
% Mục đích: chỉ tìm executable, không khởi động Ansys lúc mở GUI.
exe = ''; root = getenv('ANSYSEM_ROOT212');
choices = {fullfile(root, 'Win64', 'ansysedt.exe'), ...
    'C:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe', ...
    'C:\Program Files\AnsysEM\v212\Win64\ansysedt.exe', ...
    'D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe'};
for k = 1:numel(choices)
    if isfile(choices{k}), exe = choices{k}; return; end
end
end
