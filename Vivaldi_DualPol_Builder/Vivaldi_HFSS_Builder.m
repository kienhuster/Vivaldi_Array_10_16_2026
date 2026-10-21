function out = Vivaldi_HFSS_Builder(action, varargin)
% Mục đích: mỗi lần tạo dựng CAD từ project trống và lưu một AEDT mới.
% generate chỉ sinh script; launch/poll cần HFSS thật, không coi exit code là thành công.
root = fileparts(mfilename('fullpath'));
if ismember(action, {'initialize', 'generate', 'simulate', 'launch', 'open'})
    library = initializeLibrary(root);
end
switch action
    case 'initialize'
        out = library;
    case 'generate'
        p = varargin{1}; folder = varargin{2};
        [ok, errors] = Vivaldi_Calculation('validate', p);
        assert(ok, 'Vivaldi:Parameters', '%s', strjoin(errors, newline));
        cfg = Vivaldi_HFSS_Simulation('defaults');
        if numel(varargin) >= 3, cfg = varargin{3}; end
        Vivaldi_HFSS_Simulation('validate', cfg);
        mode = 'full'; if numel(varargin) >= 4, mode = varargin{4}; end
        assert(ismember(mode, {'full', 'rectangle'}), 'Vivaldi:BuildMode', 'Chế độ dựng không hợp lệ.');
        database = Vivaldi_Calculation('material_defaults');
        body = database(strcmp({database.name},'Aluminum'));
        if numel(varargin)>=6, body = varargin{6}; end
        body = Vivaldi_Calculation('material_body',body);
        folder = canonical(folder);
        reference = canonical(fullfile(root, 'reference'));
        assert(~strcmpi(folder, reference) && ~startsWith(lower(folder), [lower(reference) filesep]), ...
            'Vivaldi:Reference', 'Không xuất vào thư mục tham chiếu.');
        if ~isfolder(folder), [yes, message] = mkdir(folder); assert(yes, '%s', message); end
        [path, reservation] = reserveNewPath(folder);
        out = newJob(path, folder, p, cfg, 'build');
        out.reservation = reservation; out.mode = mode; out.bodyMaterial = body;
        saveDebug = false; if numel(varargin) >= 5, saveDebug = varargin{5}; end
        out.debugEnabled = saveDebug;
        out.debugPath = fullfile(out.jobFolder, 'CAD_DEBUG_INCOMPLETE.aedt');
        w = hfssVivaldiScript(out.scriptPath, out.statusPath, out.id, saveDebug);
        cleanup = onCleanup(w.abort); %#ok<NASGU>
        %% 1. Khởi tạo dự án HFSS mới bằng helper thư viện, không mở AEDT cũ
        bootstrap(w);
        w.line(['vBodyMaterial = ' w.q(lower(body.name))]);
        w.lib(@hfssInsertDesign, {out.designName, 'driven modal'});
        w.pass('PROJECT_TRONG', 'PASS', 'Đã tạo project trống và Driven Modal design');
        if strcmp(mode, 'rectangle')
            % Project chẩn đoán riêng, không được gọi là anten hoàn chỉnh.
            w.lib(@hfssRectangle, {'ProbeRectangle', 'Z', [0 0 0], 10, 6, 'mm'});
            w.require('ExactNames(Array("ProbeRectangle"))', 'Rectangle thử chưa được tạo');
            w.require('PointMatches("ProbeRectangle",Array(5,3,0),True)', 'Không đo được Rectangle thử');
            w.require('oDesign.ValidateDesign() = 1', 'Validate Rectangle thử thất bại');
            w.pass('RECTANGLE_THU', 'PASS', 'Đã đo Rectangle thử, không phải anten');
        else
            buildGeometry(w, p, cfg, body);
        end
        %% 14. Chỉ lưu sau khi đã qua kiểm tra, kiểm tra đích lần nữa ngay trước Save
        w.stage('LUU_AEDT');
        w.require(['Not fs.FileExists(' w.q(path) ')'], 'Đích đã xuất hiện; không ghi đè');
        w.lib(@hfssSaveProject, {path, false});
        w.require(['fs.FileExists(' w.q(path) ')'], 'HFSS chưa tạo file AEDT');
        w.require(['fs.GetFile(' w.q(path) ').Size > 0'], 'File AEDT rỗng');
        w.pass('LUU_AEDT', 'PASS', 'Đã lưu file AEDT mới sau kiểm tra');
        terminal(w);
        w.finish(); writeJobMetadata(out);
    case 'simulate'
        built = varargin{1};
        assert(strcmp(built.action, 'build') && strcmp(built.mode, 'full') && ...
            strcmp(built.state, 'SUCCEEDED') && isfile(built.projectPath), ...
            'Vivaldi:NotBuilt', 'Chỉ mô phỏng anten vừa dựng và kiểm tra thành công.');
        cfg = built.simulation; if numel(varargin) >= 2, cfg = varargin{2}; end
        Vivaldi_HFSS_Simulation('validate', cfg);
        out = newJob(built.projectPath, fileparts(built.projectPath), built.params, cfg, 'simulate');
        out.bodyMaterial = built.bodyMaterial;
        w = hfssVivaldiScript(out.scriptPath, out.statusPath, out.id);
        w.line(['vBodyMaterial = ' w.q(lower(built.bodyMaterial.name))]);
        cleanup = onCleanup(w.abort); %#ok<NASGU>
        % Chỉ mô phỏng mới mở file đã tạo; không đưa mô hình cũ vào luồng build.
        attachGenerated(w, built.projectPath, built.designName);
        verifyMaterialSnapshot(w,built.bodyMaterial);
        VivaldiValidation('full', w, built.params, true);
        Vivaldi_HFSS_Simulation('run', w, cfg);
        Vivaldi_HFSS_Simulation('reports', w, cfg, out.jobFolder, out.id);
        w.call('oProject.Save', 'Lưu kết quả mô phỏng của file vừa tạo');
        terminal(w); w.finish(); writeJobMetadata(out);
    case 'launch'
        out = varargin{1}; exe = varargin{2};
        assert(ispc && isfile(exe), 'Vivaldi:HFSS', 'Cần Windows và đường dẫn ansysedt.exe hợp lệ.');
        assert(strcmp(out.state, 'SCRIPT_READY'), 'Vivaldi:Job', 'Job đã được khởi chạy.');
        bytes = readBytes(out.scriptPath);
        assert(~isempty(bytes) && all(bytes < 128) && ~any(bytes == 0), ...
            'Vivaldi:Encoding', 'Script không phải ASCII không BOM.');
        syntaxCheckWindows(out.scriptPath);
        [code, ~] = hfssExecuteScript(exe, out.scriptPath, false, false, false);
        assert(code == 0, 'Vivaldi:Launch', 'Không khởi chạy được HFSS, mã %d.', code);
        out.state = 'RUNNING'; out.started = now;
    case 'poll'
        out = varargin{1};
        out.log = readStatus(out.statusPath);
        if ~hasText(out.log, ['JOB|' out.id sprintf('\r\n')]) && ...
                ~hasText(out.log, ['JOB|' out.id sprintf('\n')])
            return
        end
        lines = regexp(out.log, '\r?\n', 'split');
        if any(strcmp(lines, 'STATE|FAILED'))
            out.state = 'FAILED';
        elseif any(strcmp(lines, 'STATE|SUCCEEDED'))
            assert(any(strcmp(lines, 'VERIFIED|1')) && isfile(out.projectPath), ...
                'Vivaldi:Unverified', 'Thiếu xác nhận kiểm tra hoặc file AEDT.');
            if strcmp(out.action, 'build') && strcmp(out.mode, 'full')
                verifySaved(out.projectPath, out.params);
            end
            out.state = 'SUCCEEDED';
        end
        % Không tự kết luận thành công/thất bại khi launcher thoát hoặc đợi lâu.
    case 'open'
        built = varargin{1}; exe = varargin{2};
        assert(strcmp(built.state, 'SUCCEEDED') && isfile(built.projectPath), ...
            'Vivaldi:NotBuilt', 'Chưa có file HFSS đã tạo thành công.');
        assert(ispc && isfile(exe), 'Vivaldi:HFSS', 'Cần Windows và ansysedt.exe hợp lệ.');
        args = javaObject('java.util.ArrayList');
        args.add(javaObject('java.lang.String', exe));
        args.add(javaObject('java.lang.String', built.projectPath));
        process = javaObject('java.lang.ProcessBuilder', args); process.start();
        out = built;
    otherwise
        error('Vivaldi:Action', 'Thao tác builder không được hỗ trợ.');
end
end

function job = newJob(path, folder, p, cfg, action)
% Mục đích: mỗi job có thư mục script/log riêng, không quản lý session hoặc tham số cũ.
[~, id] = fileparts(tempname);
jobFolder = fullfile(folder, 'scripts', id);
[ok, message] = mkdir(jobFolder); assert(ok, '%s', message);
job = struct('id', id, 'action', action, 'state', 'SCRIPT_READY', 'params', p, ...
    'simulation', cfg, 'projectPath', path, 'designName', 'dual_pol_vivaldi_patch_Wflare_20', ...
    'jobFolder', jobFolder, 'scriptPath', fullfile(jobFolder, 'build.vbs'), ...
    'statusPath', fullfile(jobFolder, 'status.txt'), 'log', '', 'started', []);
end

function [path, reservation] = reserveNewPath(folder)
% Mục đích: cấp tên tăng dần, giữ chỗ bằng mkdir độc quyền; không đụng file có sẵn.
for k = 1:1000000
    path = fullfile(folder, sprintf('Vivaldi_DualPol_%03d.aedt', k));
    reservation = [path '.reserve'];
    if isfile(path) || isfile([path '.lock']) || isfolder([path 'results']) || isfolder(reservation), continue; end
    [ok, ~, messageId] = mkdir(reservation);
    if ok && isempty(messageId), return; end
end
error('Vivaldi:Filename', 'Không cấp được tên AEDT mới. Chọn thư mục xuất khác.');
end

function bootstrap(w)
% Mục đích: dùng preamble hfssNewProject thật, thay ProgID HFSS cũ bằng AEDT 2021 R2.
text = w.capture(@hfssNewProject, {});
text = regexprep(text, '(?m)^Dim [^\r\n]*\r?\n', '');
text = strrep(text, 'AnsoftHfss.HfssScriptInterface', 'Ansoft.ElectronicsDesktop.2021.2');
w.call(text, 'Tạo project trống bằng hfssNewProject');
w.require('Left(CStr(oDesktop.GetVersion()),6) = "2021.2"', 'Cần HFSS 2021 R2');
end

function attachGenerated(w, path, design)
% Mục đích: chọn đúng file đầu ra để solve; không có đường gọi này trong Build.
[~, name] = fileparts(path);
text = w.capture(@hfssOpenProject, {path});
text = regexprep(text, '(?m)^Dim [^\r\n]*\r?\n', '');
text = strrep(text, 'AnsoftHfss.HfssScriptInterface', 'Ansoft.ElectronicsDesktop.2021.2');
% Khi file đã mở, tránh OpenProject trùng; vẫn dùng helper cho preamble/chọn project.
lines = regexp(text, '\r?\n', 'split');
for k = 1:numel(lines)
    line = strtrim(lines{k});
    if startsWith(line, 'oDesktop.OpenProject ')
        lines{k} = ['If Not HasName(oDesktop.GetProjectList(),' w.q(name) ') Then' newline line newline 'End If'];
    end
end
w.call(strjoin(lines, newline), 'Mở file anten vừa tạo để mô phỏng');
w.require(['LCase(fs.GetAbsolutePathName(oProject.GetPath() & "\" & oProject.GetName() & ".aedt")) = LCase(' w.q(path) ')'], ...
    'Project cùng tên đang mở từ đường dẫn khác');
w.lib(@hfssSetDesign, {design});
end

function terminal(w)
% Mục đích: chỉ gửi terminal sau toàn bộ phép đo và Save đã hoàn tất.
w.line('WriteStatus "VERIFIED|1"');
w.line('WriteStatus "STATE|SUCCEEDED"');
end

function path = canonical(path)
% Mục đích: chuẩn hóa đường dẫn tuyệt đối mà không shell-escape hoặc mất Unicode.
assert(~isempty(path), 'Vivaldi:Path', 'Đường dẫn không được rỗng.');
path = char(path);
if exist('OCTAVE_VERSION', 'builtin')
    path = make_absolute_filename(path);
    if isfolder(path) || isfile(path), path = canonicalize_file_name(path); end
else
    file = javaObject('java.io.File', path); path = char(file.getCanonicalPath());
end
assert(~any(path < 32) && ~hasText(path, '"'), 'Vivaldi:Path', 'Đường dẫn có ký tự không hợp lệ.');
end

function bytes = readBytes(path)
% Mục đích: đọc binary để kiểm tra BOM và đọc status độc lập với locale của Windows.
fid = fopen(path, 'rb'); assert(fid >= 0, 'Vivaldi:Read', 'Không đọc được file.');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes = fread(fid, Inf, '*uint8')';
end

function text = readStatus(path)
% Mục đích: status UTF-16LE có BOM, chỉ nhận dòng đã ghi xong để tránh terminal dở.
text = ''; if ~isfile(path), return; end
bytes = readBytes(path);
if numel(bytes) >= 2 && isequal(bytes(1:2), uint8([255 254])), bytes = bytes(3:end); end
bytes = bytes(1:2 * floor(numel(bytes) / 2));
text = native2unicode(bytes, 'UTF-16LE');
last = find(text == char(10), 1, 'last');
if isempty(last), text = ''; else, text = text(1:last); end
end

function verifySaved(path, p)
% Mục đích: kiểm tra file lưu có design/biến/cổng thật, không nhận shell rỗng là anten.
text = fileread(path);
assert(hasText(text, 'dual_pol_vivaldi_patch_Wflare_20') && ...
    hasText(text, "Name='Vivaldi_1'") && hasText(text, "Name='port1'") && ...
    hasText(text, "Name='port2'") && hasText(text, "Name='Setup1'"), ...
    'Vivaldi:Save', 'File lưu thiếu design, thân, hai cổng hoặc Setup1.');
g = Vivaldi_Calculation('geometry', p);
for k = 1:size(g.expressions, 1)
    name = g.expressions{k, 1};
    row = regexp(text, ['VariableProp\(''' regexptranslate('escape', name) ''',\s*[^\r\n]*?''([^'']*)''\)'], 'tokens');
    assert(numel(row) == 1, 'Vivaldi:Save', 'Không đọc được duy nhất biến %s trong AEDT.', name);
    if isfield(p, name)
        [~, meta] = Vivaldi_Calculation('defaults');
        expectedUnit = meta(strcmp({meta.name}, name)).unit;
        token = regexp(row{1}{1}, '^([+\-0-9.eE]+)\s*(mm|deg)$', 'tokens', 'once');
        assert(~isempty(token) && strcmp(token{2}, expectedUnit) && ...
            abs(str2double(token{1}) - p.(name)) < 1e-10 * (1 + abs(p.(name))), ...
            'Vivaldi:Save', 'Giá trị biến %s trong AEDT không khớp.', name);
    else
        assert(strcmp(regexprep(row{1}{1}, '\s', ''), regexprep(g.expressions{k, 2}, '\s', '')), ...
            'Vivaldi:Save', 'Biểu thức %s trong AEDT không khớp.', name);
    end
end
end

function buildGeometry(w, p, cfg, body)
    % Mục đích: dựng đúng một phần tử Vivaldi dual-pol từ design trống bằng hfss-api.
    % Giữ biểu thức, CS lồng nhau, cutter trước hollowing và checkpoint đo CAD thật.
    [ok, errors] = Vivaldi_Calculation('validate', p);
    assert(ok, 'Vivaldi:Parameters', '%s', strjoin(errors, newline));
    g = Vivaldi_Calculation('geometry', p);
    %% 1. Khai báo biến và tính chất điện từ đúng mô hình nguồn
    hfssVivaldiExtensions(w, 'variables', p);
    materials(w, body);
    w.call('oEditor.SetModelUnits Array("NAME:Units Parameter","Units:=","mm","Rescale:=",False)', 'Đặt đơn vị mô hình mm');
    %% 2. Tạo các hệ tọa độ và giữ gốc local theo parent
    w.stage('CHECK_01');
    for item = {'slot_t_td', 'slot_feed_td', 'patch_td', 'RelativeCS1'}
        n = item{1};
        cs = g.cs.(n);
        hfssVivaldiExtensions(w, 'coordinate', n, cs.parent, cs.originExpressions);
    end
    w.pass('CHECK_01', 'PENDING', 'Đã đọc lại parent CS; cần kiểm tra toàn bộ orientation trong HFSS');
    %% 3. Dựng hai mặt loe mũ, không thay bằng polygon ít điểm
    w.lib(@hfssSetWCS, {'Global'});
    w.stage('CHECK_02');
    hfssVivaldiExtensions(w, 'equation', 'EquationSurface1', 'L_flare');
    w.call('sbObjects = QueryGroup("Sheets")', 'Đọc trực tiếp nhóm Sheets sau CreateEquationSurface1', 'QUERY');
    w.require('HasName(sbObjects,"EquationSurface1")', 'Truy vấn Sheets thành công nhưng không có tên EquationSurface1');
    w.pass('CHECK_02', 'PENDING', 'Đã tạo mặt loe dài');
    w.stage('CHECK_03');
    hfssVivaldiExtensions(w, 'equation', 'EquationSurface2', 'slot_t_L');
    w.call('sbObjects = QueryGroup("Sheets")', 'Đọc trực tiếp nhóm Sheets sau CreateEquationSurface2', 'QUERY');
    w.require('HasName(sbObjects,"EquationSurface2")', 'Truy vấn Sheets thành công nhưng không có tên EquationSurface2');
    w.pass('CHECK_03', 'PENDING', 'Đã tạo mặt loe ngắn');
    %% 4. Clone trước khi trim; xoay transition quanh slot_t_td thay vì Global
    w.stage('CHECK_04');
    hfssVivaldiExtensions(w, 'clone', 'EquationSurface2', 'EquationSurface2_1', false);
    w.lib(@hfssSubtract, {{'EquationSurface1'}, {'EquationSurface2_1'}, 'false'});
    w.require('ExactNames(Array("EquationSurface1","EquationSurface2"))', 'Trim flare mất đối tượng hoặc còn cutter dư');
    w.pass('CHECK_04', 'PENDING', 'Đã giữ mặt ngắn gốc');
    w.stage('CHECK_05');
    w.lib(@hfssSetWCS, {'slot_t_td'});
    w.lib(@hfssRotate, {{'EquationSurface2'}, 'Y', p.deg_slot_t}, {'RotateAngle', 'deg_slot_t'});
    w.pass('CHECK_05', 'PENDING', 'Xoay transition theo deg_slot_t trong slot_t_td');
    %% 5. Tạo khe và cavity; normal Y có Width theo Z, Height theo X
    w.stage('CHECK_06');
    w.lib(@hfssSetWCS, {'slot_feed_td'});
    hfssVivaldiExtensions(w, 'rectangle', 'Rectangle1', {'0mm', '0mm'}, {'-h3_slot_feed', 'slot_feed_w'});
    hfssVivaldiExtensions(w, 'rectangle', 'Rectangle2', {'0mm', '-h3_slot_feed'}, {'-slot_feed_w', 'slot_feed_w+h2+cavity_w'});
    hfssVivaldiExtensions(w, 'rectangle', 'Rectangle3', {'slot_feed_w+h2', '-h3_slot_feed-slot_feed_w'}, {'cavity_L', 'cavity_w'});
    w.pass('CHECK_06', 'PENDING', 'Ba mặt khe/cavity trong slot_feed_td');
    w.stage('CHECK_07');
    w.lib(@hfssUnite, {{'EquationSurface1', 'EquationSurface2', 'Rectangle1', 'Rectangle2', 'Rectangle3'}});
    w.require('ExactNames(Array("EquationSurface1"))', 'Unite vùng khoét chưa thành công');
    w.pass('CHECK_07', 'PENDING', 'Đã Unite vùng khoét');
    %% 6. Khoét thật vùng loe khỏi tấm kim loại, đo tâm rỗng và hai mép còn metal
    w.stage('CHECK_08');
    w.lib(@hfssSetWCS, {'patch_td'});
    hfssVivaldiExtensions(w, 'rectangle', 'Vivaldi_1', {'0mm', '0mm'}, {'-L_patch', '-aperture_w'});
    w.lib(@hfssSubtract, {{'Vivaldi_1'}, {'EquationSurface1'}, 'false'});
    hfssVivaldiExtensions(w, 'material', 'Vivaldi_1', lower(body.name));
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 1, false);
    VivaldiValidation('cavity', w, p, false);
    w.pass('CHECK_08', 'PASS', 'Đã đo flare rỗng, hai mép kim loại và khe/cavity trên sheet');
    %% 7. Tăng độ dày đối xứng; kiểm tra flare không biến thành tấm đặc
    w.stage('CHECK_09');
    hfssVivaldiExtensions(w, 'thicken', 'Vivaldi_1');
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 1, true);
    w.pass('CHECK_09', 'PASS', 'Đã đo BothSides và vùng loe sau tăng độ dày');
    %% 8. Tạo phân cực thứ hai theo phép xoay/dịch tham số nguồn
    w.stage('CHECK_10');
    w.lib(@hfssSetWCS, {'RelativeCS1'});
    hfssVivaldiExtensions(w, 'clone', 'Vivaldi_1', 'Vivaldi_2', true);
    hfssVivaldiExtensions(w, 'moveSecond', 'Vivaldi_2');
    w.require(['MaterialMatches("Vivaldi_2",' w.q(lower(body.name)) ',False)'], 'Vật liệu phân cực hai không đúng snapshot');
    VivaldiValidation('flare', w, p, 'Vivaldi_2', 2, true);
    w.pass('CHECK_10', 'PASS', 'Phân cực hai còn vùng loe và chiều dày đúng');
    %% 9. Khối nối và đế, sau đó Unite thân aluminum
    w.stage('CHECK_11');
    w.lib(@hfssSetWCS, {'RelativeCS1'});
    hfssVivaldiExtensions(w, 'box', 'Box1', {'0mm', '0mm', '0mm'}, {'thickness', 'thickness', '-L_patch'}, lower(body.name));
    hfssVivaldiExtensions(w, 'material', 'Box1', lower(body.name));
    w.lib(@hfssSetWCS, {'Global'});
    hfssVivaldiExtensions(w, 'box', 'De', {'(de_L+thickness)/2', '-(de_W-aperture_w)/2', 'z_feed-h3_slot_feed-slot_feed_w'}, {'-de_L', 'de_W', '-h_de'}, lower(body.name));
    hfssVivaldiExtensions(w, 'material', 'De', lower(body.name));
    w.pass('CHECK_11', 'PENDING', 'Khối nối và đế đã dựng');
    w.stage('CHECK_12');
    w.lib(@hfssUnite, {{'Vivaldi_1', 'Vivaldi_2', 'Box1', 'De'}});
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 1, true);
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 2, true);
    w.pass('CHECK_12', 'PASS', 'Cả hai vùng loe còn rỗng sau Unite thân');
    %% 10. Tạo hai cáp đồng trục và sáu cutter chụp khi cylinder còn đặc
    w.stage('CHECK_13');
    w.lib(@hfssSetWCS, {'slot_feed_td'});
    hfssVivaldiExtensions(w, 'cylinder', 'cable_in', 'r_cabin', '-h3_slot_feed', '-h_cabin');
    hfssVivaldiExtensions(w, 'cylinder', 'cable_out', 'r_cabout', '-h3_slot_feed-slot_feed_w', '-h_cabout');
    hfssVivaldiExtensions(w, 'cylinder', 'cable_mid', 'r_cabmid', '-h3_slot_feed-slot_feed_w', '-h_cabout');
    w.lib(@hfssCircle, {'port1', 'Z', [0 0 0], 1, 'mm', true}, ...
          {'XCenter', '-positionx+slot_feed_w+h2'; 'YCenter', '0mm'; 'ZCenter', '-h3_slot_feed-h_cabin'; 'Radius', 'r_cabmid'});
    w.pass('CHECK_13', 'PENDING', 'Đã tạo coax thứ nhất và mặt cổng');
    w.stage('CHECK_14');
    w.lib(@hfssSetWCS, {'RelativeCS1'});
    sources = {'cable_in', 'cable_out', 'cable_mid', 'port1'};
    targets = {'cable_in_1', 'cable_out_1', 'cable_mid_1', 'port2'};
    for k = 1:4
        hfssVivaldiExtensions(w, 'clone', sources{k}, targets{k}, true);
        hfssVivaldiExtensions(w, 'moveSecond', targets{k});
    end
    w.pass('CHECK_14', 'PENDING', 'Đã sao chép coax/cổng theo phân cực thứ hai');
    w.stage('CHECK_15');
    sources = {'cable_in', 'cable_in_1', 'cable_mid', 'cable_mid_1', 'cable_out', 'cable_out_1'};
    cutters = {'cable_in_2', 'cable_in_1_1', 'cable_mid_2', 'cable_mid_1_1', 'cable_out_2', 'cable_out_1_1'};
    for k = 1:6
        hfssVivaldiExtensions(w, 'clone', sources{k}, cutters{k}, false);
    end
    w.lib(@hfssSubtract, {{'cable_out'}, {'cable_mid'}, 'false'});
    w.lib(@hfssSubtract, {{'cable_out_1'}, {'cable_mid_1'}, 'false'});
    w.lib(@hfssSubtract, {{'Vivaldi_1'}, cutters, 'false'});
    for n = {'cable_in', 'cable_out', 'cable_in_1', 'cable_out_1'}
        hfssVivaldiExtensions(w, 'material', n{1}, 'copper');
    end
    w.lib(@hfssSetWCS, {'Global'});
    VivaldiValidation('full', w, p, false);
    w.pass('CHECK_15', 'PASS', 'Đã đo thể tích coax, cổng và khoét sáu cutter khỏi thân');
    verifyMaterialSnapshot(w,body);
    %% 11–12. Gán hai Lumped Ports, radiation, setup và sweep Discrete
    Vivaldi_HFSS_Simulation('create', w, p, cfg);
    %% 13. Kiểm tra đầy đủ trước khi lưu; không tự chạy solver
    VivaldiValidation('full', w, p, true);
end

function materials(w, body)
% Mục đích: dùng định nghĩa đã xác minh, tạo custom khi cần; không sửa thư viện toàn cục.
w.call('Set oMaterials = oProject.GetDefinitionManager()', 'Đọc DefinitionManager');
all = Vivaldi_Calculation('material_defaults');
required = [body, all(strcmp({all.name},'Copper')), all(strcmp({all.name},'Vacuum'))];
seen = {};
for k = 1:numel(required)
    item = required(k); name = lower(item.name);
    if any(strcmpi(seen,name)), continue; end
    seen{end+1} = name; %#ok<AGROW>
    if strcmp(item.kind,'pec')
        w.line('WriteStatus "MATERIAL|PEC_BUILTIN|pec|Khong khai bao conductivity huu han"');
    else
        w.call(['EnsureMaterial ' w.q(name) ', ' w.literal(item.permittivity) ', ' w.literal(item.permeability) ', ' ...
            w.literal(item.conductivity) ', ' w.literal(item.lossTangent)], ['Khai báo/đối chiếu vật liệu ' name]);
    end
end
end

function verifyMaterialSnapshot(w, body)
% Mục đích: xác minh định nghĩa điện từ trước lưu/solve, không chỉ kiểm tra tên.
w.call('Set oMaterials = oProject.GetDefinitionManager()', 'Đọc vật liệu để kiểm tra snapshot');
all=Vivaldi_Calculation('material_defaults'); required=[body,all(strcmp({all.name},'Copper')),all(strcmp({all.name},'Vacuum'))];
for k=1:numel(required)
    item=required(k);
    if strcmp(item.kind,'pec'), continue; end
    w.require(['MaterialDefinitionMatches(' w.q(lower(item.name)) ',' w.literal(item.permittivity) ',' ...
        w.literal(item.permeability) ',' w.literal(item.conductivity) ',' w.literal(item.lossTangent) ')'], ...
        ['Thuộc tính điện từ không đúng snapshot: ' item.name]);
end
end

function writeJobMetadata(job)
% Mục đích: lưu snapshot hình học/vật liệu/solver cạnh script, không chứng nhận CAD.
fid = fopen(fullfile(job.jobFolder,'job.json'),'w','n','UTF-8');
assert(fid>=0,'Vivaldi:Write','Không lưu được snapshot job.');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',jsonencode(job));
end

function hfssVivaldiExtensions(w, action, varargin)
    % Mục đích: bổ sung những thao tác hoặc biểu thức mà helper gốc chưa hỗ trợ.
    % Không sửa primitive gốc: capture gọi thư viện trước rồi thay trường có kiểm chứng.
    switch action
        case 'coordinate'
            name = varargin{1};
            parent = varargin{2};
            xyz = varargin{3};
            w.lib(@hfssSetWCS, {parent});
            w.lib(@hfssCreateRelativeCS, {name, [0 0 0], 'mm'}, ...
                  {'OriginX', xyz{1}; 'OriginY', xyz{2}; 'OriginZ', xyz{3}});
            a = {'NAME:AllTabs', {'NAME:Geometry3DCSTab', {'NAME:PropServers', name}, ...
                                  {'NAME:ChangedProps', {'NAME:Reference CS', 'Value:=', parent}}}};
            w.call(['oEditor.ChangeProperty ' w.literal(a)], ['Đặt parent CS ' name]);
            a = {'NAME:AllTabs', {'NAME:Geometry3DCSTab', {'NAME:PropServers', name}, ...
                                  {'NAME:ChangedProps', {'NAME:Origin', 'X:=', xyz{1}, 'Y:=', xyz{2}, 'Z:=', xyz{3}}}}};
            w.call(['oEditor.ChangeProperty ' w.literal(a)], ['Giữ gốc local tham số ' name]);
            w.require(['oEditor.GetPropertyValue("Geometry3DCSTab",' w.q(name) ',"Reference CS") = ' w.q(parent)], ...
                      ['Parent CS sai: ' name]);
        case 'equation'
            name = varargin{1};
            stop = varargin{2};
            a = {'NAME:EquationBasedSurfaceParameters', ...
                 'XuvFunction:=', '_v*((slot_feed_w/2)*exp((_u)*r_flare))', 'YuvFunction:=', '0', 'ZuvFunction:=', '_u', ...
                 'uStart:=', '0', 'uEnd:=', stop, 'vStart:=', '-1', 'vEnd:=', '1', 'Version:=', 1};
            w.call(['oEditor.CreateEquationSurface ' w.literal(a) ', ' attributes(w, name, 'vacuum', true)], ['Tạo mặt loe ' name]);
        case 'clone'
            % Clone runtime so sánh object trước/sau, không đoán hậu tố HFSS.
            name = varargin{1};
            target = varargin{2};
            rotate = varargin{3};
            if rotate
                operation = 'rotate';
            else
                operation = 'copy';
            end
            w.call(['CloneNamed ' w.q(name) ', ' w.q(target) ', ' w.q(operation)], ['Sao chép ' name]);
        case 'thicken'
            w.lib(@hfssThickenSheet, {{varargin{1}}, 1, 'mm'}, ...
                  {'Thickness', 'thickness'; 'BothSides', true});
        case 'rectangle'
            % WCS đã được chọn trước; PartCoordinateSystem=Global chỉ là hướng vật liệu.
            name = varargin{1};
            xy = varargin{2};
            dims = varargin{3};
            w.lib(@hfssRectangle, {name, 'Y', [0 0 0], 1, 1, 'mm'}, ...
                  {'XStart', xy{1}; 'YStart', '0mm'; 'ZStart', xy{2}; 'Width', dims{1}; 'Height', dims{2}; 'Transparency', 0});
        case 'box'
            name = varargin{1};
            xyz = varargin{2};
            dims = varargin{3};
            material = varargin{4};
            w.lib(@hfssBox, {name, [0 0 0], [1 1 1], 'mm', material, false}, ...
                  {'XPosition', xyz{1}; 'YPosition', xyz{2}; 'ZPosition', xyz{3}; ...
                   'XSize', dims{1}; 'YSize', dims{2}; 'ZSize', dims{3}; 'Transparency', 0});
        case 'cylinder'
            name = varargin{1};
            radius = varargin{2};
            z = varargin{3};
            height = varargin{4};
            w.lib(@hfssCylinder, {name, 'Z', [0 0 0], 1, 1, 'mm'}, ...
                  {'XCenter', '-positionx+slot_feed_w+h2'; 'YCenter', '0mm'; ...
                   'ZCenter', z; 'Radius', radius; 'Height', height});
        case 'moveSecond'
            w.lib(@hfssMove, {{varargin{1}}, [0 1 0], 'mm'}, ...
                  {'TranslateVectorX', '0mm'; 'TranslateVectorY', 'thickness'; 'TranslateVectorZ', '0mm'});
        case 'material'
            % AssignMaterial 2021 R2 nhận MaterialValue có tên vật liệu được quote.
            text = w.capture(@hfssAssignMaterial, {varargin{1}, varargin{2}, false}, ...
                {'MaterialName', ['"' varargin{2} '"']; 'SolveInside', false});
            text = strrep(text,'"MaterialName:="','"MaterialValue:="');
            w.call(text, ['Gán vật liệu ' varargin{2} ' cho ' varargin{1}]);
            w.require(['MaterialMatches(' w.q(varargin{1}) ',' w.q(varargin{2}) ',False)'], 'Vật liệu hoặc SolveInside không đúng sau AssignMaterial');
        case 'variables'
            p = varargin{1};
            g = Vivaldi_Calculation('geometry', p);
            independent = fieldnames(p);
            order = [find(ismember(g.expressions(:, 1), independent)); find(~ismember(g.expressions(:, 1), independent))];
            % Helper NewProps của upstream được dùng cho cả literal và biểu thức.
            for k = order(:)'
                name = g.expressions{k, 1};
                expression = g.expressions{k, 2};
                w.lib(@hfssSetVariable, {name, expression, ''}, {'Value', expression});
            end
            w.lib(@hfssSetVariable, {'alpha', '0deg', ''}, ...
                  {'Value', '0deg'; 'PropType', 'PostProcessingVariableProp'});
        otherwise
            error('Vivaldi:Extension', 'Phép mở rộng chưa hỗ trợ: %s.', action);
    end
end

function out = attributes(w, name, material, inside)
    % Mặt loe dùng vacuum; hướng vật liệu Global theo nguồn, WCS điều khiển phép dựng.
    out = w.literal({'NAME:Attributes', 'Name:=', name, 'Flags:=', '', 'PartCoordinateSystem:=', 'Global', ...
                     'MaterialValue:=', ['"' material '"'], 'SolveInside:=', inside});
end

function out = VivaldiValidation(action, varargin)
    % Mục đích: sinh kiểm tra runtime CAD/biến; kết quả chỉ PASS khi HFSS chạy thật.
    % Kiểm tra công thức MATLAB và probe CAD có phạm vi bằng chứng riêng biệt.
    out = [];
    switch action
        case 'variables'
            w = varargin{1};
            p = varargin{2};
            g = Vivaldi_Calculation('geometry', p);
            [~, meta] = Vivaldi_Calculation('defaults');
            independent = {};
            derived = {};
            for k = 1:numel(meta)
                n = meta(k).name;
                independent{end + 1} = {n, p.(n), meta(k).unit}; %#ok<AGROW>
            end
            for k = 1:size(g.expressions, 1)
                n = g.expressions{k, 1};
                if ~isfield(p, n)
                    derived{end + 1} = {n, g.expressions{k, 2}};
                end %#ok<AGROW>
            end
            w.call(['CheckVariables ' w.literal(independent) ', ' w.literal(derived)], ...
                   'Đọc lại toàn bộ biến độc lập và biểu thức dẫn xuất');
        case 'flare'
            w = varargin{1};
            p = varargin{2};
            name = varargin{3};
            pol = varargin{4};
            solid = varargin{5};
            g = Vivaldi_Calculation('geometry', p);
            A = p.aperture_w / 2;
            low = max([g.slot_t_L, max(g.slotRectangles(3).corners(:, 3))]) + 1e-4 * max(1, g.L_flare);
            assert(low < g.L_flare, 'Vivaldi:Probe', 'Không còn miền kiểm tra flare tách khỏi cavity.');
            zs = unique([low + (g.L_flare - low) * [.2 .5 .8], 10, 25, 40]);
            zs = zs(zs > low & zs < g.L_flare - 1e-4);
            assert(numel(zs) >= 3, 'Vivaldi:Probe', 'Cần ít nhất ba mặt cắt kiểm tra flare hợp lệ.');
            w.lib(@hfssSetWCS, {'Global'});
            points = {};
            for z = zs
                half = (p.slot_feed_w / 2) * exp(z * g.r_flare);
                x = (A + half) / 2;
                points = addPoint(points, g, pol, [0 0 z], false, 'Tâm flare phải rỗng');
                points = addPoint(points, g, pol, [-x 0 z], true, 'Mép trái phải còn kim loại');
                points = addPoint(points, g, pol, [x 0 z], true, 'Mép phải phải còn kim loại');
                if solid
                    for side = [-1 1]
                        for ratio = [.45 .55]
                            points = addPoint(points, g, pol, [x side * ratio * p.thickness z], ratio < .5, 'Kiểm tra chiều dày BothSides');
                        end
                    end
                end
            end
            w.call(['CheckPoints ' w.q(name) ', ' w.literal(points)], 'Đo tâm loe, hai mép và chiều dày theo plan');
        case 'cavity'
            w = varargin{1};
            p = varargin{2};
            both = varargin{3};
            g = Vivaldi_Calculation('geometry', p);
            for pol = 1:(1 + logical(both))
                for k = 1:3
                    probe(w, g, pol, 'Vivaldi_1', mean(g.slotRectangles(k).corners, 1), false, 'Khe/cavity phải rỗng');
                end
            end
        case 'coax'
            w = varargin{1};
            p = varargin{2};
            g = Vivaldi_Calculation('geometry', p);
            for k = 1:2
                if k == 1
                    suffix = '';
                else
                    suffix = '_1';
                end
                inner = ['cable_in' suffix];
                outer = ['cable_out' suffix];
                w.require(sprintf('VolumeMatches(%s,%.17g)', w.q(inner), pi * p.r_cabin^2 * g.h_cabin), 'Thể tích lõi coax sai');
                w.require(sprintf('VolumeMatches(%s,%.17g)', w.q(outer), pi * (p.r_cabout^2 - p.r_cabmid^2) * g.h_cabout), 'Ống coax ngoài chưa rỗng hoặc sai thể tích');
                for n = {inner, outer}
                    w.require(['MaterialMatches(' w.q(n{1}) ',"copper",False)'], 'Coax phải là copper, SolveInside=false');
                end
                w.require(sprintf('CircleMatches(%s,%s,%.17g)', w.q(g.ports(k).name), pointArray(w, g.ports(k).center), p.r_cabmid), 'Tâm hoặc diện tích cổng coax sai');
                w.require(['MaterialMatches(' w.q(g.ports(k).name) ',"vacuum",True)'], 'Mặt cổng phải là vacuum');
                center = (g.cables(k).outerStart + g.cables(k).outerEnd) / 2;
                probe(w, g, 1, inner, center, true, 'Lõi coax bị mất');
                probe(w, g, 1, outer, center, false, 'Ống coax chưa rỗng');
                center(1) = center(1) + (p.r_cabmid + p.r_cabout) / 2;
                probe(w, g, 1, outer, center, true, 'Thiếu vỏ coax');
                probe(w, g, 1, 'Vivaldi_1', center, false, 'Khoét coax khỏi thân nhôm chưa thành công');
            end
            w.require('MaterialMatches("Vivaldi_1",vBodyMaterial,False)', 'Vật liệu thân không đúng snapshot hoặc SolveInside chưa tắt');
        case 'full'
            w = varargin{1};
            p = varargin{2};
            solver = varargin{3};
            g = Vivaldi_Calculation('geometry', p);
            VivaldiValidation('variables', w, p);
            names = {'Vivaldi_1', 'cable_in', 'cable_out', 'cable_in_1', 'cable_out_1', 'port1', 'port2'};
            if solver
                names{end + 1} = 'RadiatingSurface';
            end
            w.require(['ExactNames(' w.literal(names) ')'], 'Danh sách đối tượng hoặc cutter dư không đúng');
            w.require('oEditor.GetModelUnits() = "mm"', 'Đơn vị mô hình phải là mm');
            VivaldiValidation('flare', w, p, 'Vivaldi_1', 1, true);
            VivaldiValidation('flare', w, p, 'Vivaldi_1', 2, true);
            VivaldiValidation('cavity', w, p, true);
            VivaldiValidation('coax', w, p);
            w.require(['BodyBoundsMatch("Vivaldi_1",' pointArray(w, reshape(g.bounds.body', 1, [])) ')'], 'Bao kích thước thân không đúng nguồn');
            if solver
                w.call('Set oBoundary = oDesign.GetModule("BoundarySetup")', 'Đọc module boundary');
                w.require('ExactlyTwoPorts()', 'Phải có đúng hai Lumped Ports 1 và 2');
                w.require('PairExists(oBoundary.GetBoundaries(),"Open1","Radiation")', 'Thiếu Open1 Radiation');
                w.require('oDesign.ValidateDesign() = 1', 'ValidateDesign không trả về success code 1');
            end
        otherwise
            error('Vivaldi:Validation', 'Thao tác kiểm tra chưa hỗ trợ: %s.', action);
    end
end

function probe(w, g, pol, name, point, expected, label)
    % Dùng phép biến đổi nguồn cho cả điểm rỗng và điểm có kim loại ở phân cực hai.
    if pol == 2
        point = (point - g.transform.pivot) * g.transform.rotation' + g.transform.pivot + g.transform.move;
    end
    w.require(['PointMatches(' w.q(name) ',' pointArray(w, point) ',' w.literal(expected) ')'], label);
end

function out = pointArray(w, point)
    out = w.literal(num2cell(point));
end

function points = addPoint(points, g, pol, point, expected, label)
    % Gom điểm vào plan để runtime kiểm tra bằng một guard; không bỏ phép đo nào.
    if pol == 2
        point = (point - g.transform.pivot) * g.transform.rotation' + g.transform.pivot + g.transform.move;
    end
    points{end + 1} = {point(1), point(2), point(3), logical(expected), label};
end

function yes = hasText(text, token)
% Mục đích: kiểm tra chuỗi tương thích cả MATLAB và Octave.
yes = ~isempty(strfind(text, token)); %#ok<STREMP>
end

function syntaxCheckWindows(path)
% Mục đích: compiler VBScript của Windows phân tích đúng script trước khi HFSS chạy.
% Bản kiểm tra thoát ngay sau Option Explicit, không tạo project hoặc status.
bytes = readBytes(path);
text = char(bytes);
assert(startsWith(text, ['Option Explicit' sprintf('\r\n')]), 'Vivaldi:ScriptSyntax', 'Thiếu Option Explicit.');
syntaxPath = [path '.syntax.vbs'];
text = strrep(text, ['Option Explicit' sprintf('\r\n')], ...
    ['Option Explicit' sprintf('\r\n') 'WScript.Quit 0' sprintf('\r\n')]);
fid = fopen(syntaxPath, 'wb'); assert(fid >= 0, 'Vivaldi:Script', 'Không tạo được script kiểm tra.');
fwrite(fid, uint8(text), 'uint8'); fclose(fid);
compiler = fullfile(getenv('SystemRoot'), 'System32', 'cscript.exe');
assert(isfile(compiler), 'Vivaldi:ScriptSyntax', 'Không tìm thấy cscript.exe để kiểm tra cú pháp VBS.');
args = javaObject('java.util.ArrayList');
for value = {compiler, '//nologo', syntaxPath}
    args.add(javaObject('java.lang.String', value{1}));
end
launcher = javaObject('java.lang.ProcessBuilder', args);
launcher.redirectErrorStream(true);
logPath = [path '.syntax.log'];
launcher.redirectOutput(javaObject('java.io.File', logPath));
process = launcher.start(); code = process.waitFor();
assert(code == 0, 'Vivaldi:ScriptSyntax', 'Compiler VBScript từ chối script; xem %s.', logPath);
end

function library = initializeLibrary(root)
% Mục đích: khai báo tường minh thư mục/file và chặn helper ngoài bản đi kèm dự án.
% Kiểm tra đủ file trước khi sửa path; không genpath, không nạp examples/tests/reference.
paths = struct('root', root, 'library', fullfile(root, 'third_party', 'hfss-api'), ...
    'general', fullfile(root, 'third_party', 'hfss-api', 'general'), ...
    'modeler3d', fullfile(root, 'third_party', 'hfss-api', '3dmodeler'), ...
    'boundary', fullfile(root, 'third_party', 'hfss-api', 'boundary'), ...
    'analysis', fullfile(root, 'third_party', 'hfss-api', 'analysis'), ...
    'radiation', fullfile(root, 'third_party', 'hfss-api', 'radiation'), ...
    'reporter', fullfile(root, 'third_party', 'hfss-api', 'reporter'), ...
    'mesh', fullfile(root, 'third_party', 'hfss-api', 'mesh'), ...
    'fieldsCalculator', fullfile(root, 'third_party', 'hfss-api', 'fieldsCalculator'), ...
    'customHelpers', fullfile(root, 'custom_helpers'));
apiHelpers = { ...
    'hfssNewProject', paths.general; ...
    'hfssInsertDesign', paths.general; ...
    'hfssOpenProject', paths.general; ...
    'hfssSetDesign', paths.general; ...
    'hfssSetVariable', paths.general; ...
    'hfssSaveProject', paths.general; ...
    'hfssExecuteScript', paths.general; ...
    'hfssRectangle', paths.modeler3d; ...
    'hfssBox', paths.modeler3d; ...
    'hfssCylinder', paths.modeler3d; ...
    'hfssCircle', paths.modeler3d; ...
    'hfssSubtract', paths.modeler3d; ...
    'hfssUnite', paths.modeler3d; ...
    'hfssRotate', paths.modeler3d; ...
    'hfssMove', paths.modeler3d; ...
    'hfssCreateRelativeCS', paths.modeler3d; ...
    'hfssSetWCS', paths.modeler3d; ...
    'hfssThickenSheet', paths.modeler3d; ...
    'hfssAssignMaterial', paths.modeler3d; ...
    'hfssAssignLumpedPort', paths.boundary; ...
    'hfssAssignRadiation', paths.boundary; ...
    'hfssInsertSolution', paths.analysis; ...
    'hfssSolveSetup', paths.analysis; ...
    'hfssInsertFarFieldSphereSetup', paths.radiation; ...
    'hfssCreateReport', paths.reporter; ...
    'hfssExportToFile', paths.reporter};
projectHelpers = {'hfssVivaldiScript', paths.customHelpers; ...
    'vivaldiPreview3D', paths.customHelpers; ...
    'Vivaldi_GUI', root; 'Vivaldi_Calculation', root; 'Vivaldi_HFSS_Simulation', root};
helpers = [apiHelpers; projectHelpers];
for name = fieldnames(paths)'
    expected = paths.(name{1});
    if ~isfolder(expected)
        error('Vivaldi:LibraryFolderMissing', ...
            'Thiếu thư mục %s. Mong đợi: %s. MATLAB đang nhận: <không áp dụng cho thư mục>.', name{1}, expected);
    end
end
for k = 1:size(helpers, 1)
    name = helpers{k, 1}; expected = fullfile(helpers{k, 2}, [name '.m']);
    if ~isfile(expected)
        error('Vivaldi:LibraryFileMissing', 'Thiếu helper %s. Mong đợi: %s. MATLAB đang nhận: %s.', ...
            name, expected, resolvedName(name));
    end
end
runtime = fullfile(paths.customHelpers, 'hfssVivaldiChecks.vbs');
if ~isfile(runtime)
    error('Vivaldi:LibraryFileMissing', ...
        'Thiếu hfssVivaldiChecks.vbs. Mong đợi: %s. MATLAB đang nhận: <đọc trực tiếp file, không tra bằng which>.', runtime);
end
originalPath = path;
try
    %% Nạp bản thư viện của dự án trước, không bắt người dùng reset path
    addpath(root, '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', 'boundary'), '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', '3dmodeler'), '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', 'analysis'), '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', 'general'), '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', 'radiation'), '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', 'reporter'), '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', 'fieldsCalculator'), '-begin');
    addpath(fullfile(root, 'third_party', 'hfss-api', 'mesh'), '-begin');
    addpath(fullfile(root, 'custom_helpers'), '-begin');
    resolved = cell(size(helpers, 1), 2);
    for k = 1:size(helpers, 1)
        name = helpers{k, 1}; expected = fullfile(helpers{k, 2}, [name '.m']); actual = which(name);
        requireHelperPath(name, expected, actual);
        resolved(k, :) = {name, actual};
    end
catch err
    path(originalPath); rethrow(err);
end
library = struct('paths', paths, 'apiHelpers', {apiHelpers}, 'projectHelpers', {projectHelpers}, ...
    'resolved', {resolved}, 'runtimeFile', runtime);
end

function requireHelperPath(name, expected, actual)
% Mục đích: so sánh đường dẫn file thực, kể cả helper trùng tên ở Current Folder.
if isempty(actual)
    same = false;
else
    same = isfile(actual);
    if same
        if ispc, same = strcmpi(canonical(expected), canonical(actual));
        else, same = strcmp(canonical(expected), canonical(actual)); end
    end
end
if ~same
    if isempty(actual), actual = '<không tìm thấy>'; end
    error('Vivaldi:LibraryConflict', 'Helper %s không đúng phiên bản. Mong đợi: %s. MATLAB đang nhận: %s.', name, expected, actual);
end
end

function actual = resolvedName(name)
% Mục đích: hiển thị rõ kết quả which ngay cả khi file không có trong bản dự án.
actual = which(name);
if isempty(actual), actual = '<không tìm thấy>'; end
end
