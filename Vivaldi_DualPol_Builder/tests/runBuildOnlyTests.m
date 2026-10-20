function report = runBuildOnlyTests(folder)
% Mục đích: kiểm tra công thức, script thật và guard; không giả lập CAD thành PASS.
if nargin < 1, folder = tempname; end
if ~isfolder(folder), mkdir(folder); end
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
checks = {}; scripts = {};
[p, meta] = Vivaldi_Calculation('defaults');
[ok, errors, ~, g] = Vivaldi_Calculation('validate', p);
assert(ok && isempty(errors) && numel(meta) == 19);
assert(abs(g.L_flare - 46.4) < 1e-12);
assert(abs(g.r_flare - .07950171237314518) < 1e-14);
assert(abs(g.L_patch - 49.23630329005893) < 1e-11);
assert(abs(g.x_feed - 2.49933086077896) < 1e-12);
assert(abs(g.z_feed - .66369670994107) < 1e-12);
checks{end + 1} = 'Công thức nguồn mặc định và đủ 19 biến';
q = p; q.L_flare_1 = 43.287123456789; q.thickness = 1.87654321;
[ok, ~, ~, qg] = Vivaldi_Calculation('validate', q);
assert(ok && abs(qg.L_flare - (q.L_flare_1 + 6.4)) < 1e-12);
assert(abs(qg.bounds.plate1(2, 2) - q.thickness / 2) < 1e-14);
assert(abs(qg.ports(2).center(1) - (q.aperture_w + q.thickness) / 2) < 1e-12);
checks{end + 1} = 'Kích thước lẻ và phép biến đổi phân cực hai giữ độ chính xác';
bad = p; bad.r_cabmid = p.r_cabout;
assert(~Vivaldi_Calculation('validate', bad));
bad = p; bad.them = -6.4; assert(~Vivaldi_Calculation('validate', bad));
bad = p; bad.cavity_L = 999; assert(~Vivaldi_Calculation('validate', bad));
checks{end + 1} = 'Từ chối bán kính sai, surface suy biến và cavity vượt tấm';

first = Vivaldi_HFSS_Builder('generate', p, folder);
second = Vivaldi_HFSS_Builder('generate', q, folder);
assert(~strcmp(first.projectPath, second.projectPath));
assert(~isfile(first.projectPath) && ~isfile(second.projectPath));
assert(isfolder(first.reservation) && isfolder(second.reservation));
scripts = {first.scriptPath, second.scriptPath};
text = fileread(first.scriptPath);
% Không đếm bản sao lệnh trong literal chẩn đoán như thể là CAD thực thi lần hai.
lines = regexp(text, '\r?\n', 'split');
lines = lines(~cellfun(@(line)startsWith(strtrim(line), 'vCommand = '), lines));
text = strjoin(lines, newline);
assert(~isempty(strfind(text, 'oDesktop.NewProject')));
assert(isempty(strfind(text, 'oDesktop.OpenProject')));
assert(isempty(strfind(text, 'RestorePrevious')) && isempty(strfind(text, 'Rollback')));
assert(isempty(strfind(text, 'oDesign.Analyze')) && isempty(strfind(text, 'oDesign.Solve')));
checks{end + 1} = 'Hai build cấp hai tên mới, không copy/open nguồn và không tự solve';

mainEnd = strfind(text, 'End Sub');
save = strfind(text(1:mainEnd(1)), 'oProject.SaveAs');
validate = strfind(text, 'oDesign.ValidateDesign() = 1');
assert(numel(save) == 1 && numel(validate) == 1 && save > validate);
assert(~isempty(strfind(text(save:end), 'false')));
assert(~isempty(strfind(text, 'Not fs.FileExists(')));
assert(~isempty(strfind(text, 'VERIFIED|1')));
checks{end + 1} = 'Chỉ SaveAs một lần sau Validate, overwrite=false và có terminal kiểm chứng';

positions = [strfind(text, 'oEditor.CreateEquationSurface'), strfind(text, 'oEditor.ThickenSheet')];
assert(numel(positions) == 3);
assert(numel(strfind(text, 'oEditor.CreateRectangle')) == 4);
assert(~isempty(strfind(text, '"BothSides:=", True')));
assert(~isempty(strfind(text, '"-90deg"')));
assert(~isempty(strfind(text, 'CheckPoints "Vivaldi_1"')));
assert(~isempty(strfind(text, 'CheckPoints "Vivaldi_2"')));
assert(~isempty(strfind(text, 'CheckVariables Array(')));
assert(~isempty(strfind(fileread(second.scriptPath), sprintf('%.17gmm', q.L_flare_1))));
checks{end + 1} = 'Helper CAD thật, hai mặt loe, BothSides và probe cả hai phân cực';

snapshot = strfind(text, 'CloneNamed "cable_out", "cable_out_2"');
hollow = strfind(text, '"Blank Parts:=", "cable_out"');
assert(numel(snapshot) == 1 && ~isempty(hollow) && snapshot < hollow(1));
assert(numel(strfind(text, 'oModule.AssignLumpedPort')) == 2);
assert(~isempty(strfind(text, '"Type:=", "Discrete"')));
assert(~isempty(strfind(text, 'oModule.AssignRadiation')));
checks{end + 1} = 'Snapshot coax đặc trước hollow, đủ hai cổng 50 ohm và sweep Discrete';

probe = Vivaldi_HFSS_Builder('generate', p, folder, Vivaldi_HFSS_Simulation('defaults'), 'rectangle');
assert(~isempty(strfind(fileread(probe.scriptPath), 'ProbeRectangle')));
scripts{end + 1} = probe.scriptPath;
checks{end + 1} = 'Script project trống và Rectangle thử riêng, chưa coi là anten';

unicodeFolder = fullfile(folder, 'Đồ án Vivaldi');
unicodeJob = Vivaldi_HFSS_Builder('generate', p, unicodeFolder);
scripts{end + 1} = unicodeJob.scriptPath;
for k = 1:numel(scripts)
    fid = fopen(scripts{k}, 'rb'); bytes = fread(fid, Inf, '*uint8'); fclose(fid);
    assert(all(bytes < 128) && ~any(bytes == 0));
    assert(isequal(char(bytes(1:15))', 'Option Explicit'));
end
assert(~isempty(strfind(fileread(unicodeJob.scriptPath), 'ChrW(272)')));
checks{end + 1} = 'Script ASCII không BOM/NUL; Unicode đường dẫn được mã hóa bằng ChrW';

% Protocol fixture chỉ kiểm tra ACK/terminal/encoding, không chạy HFSS thật.
writeStatus(first.statusPath, ['JOB|sai-id' sprintf('\r\n') 'VERIFIED|1' sprintf('\r\n') 'STATE|SUCCEEDED' sprintf('\r\n')]);
polled = Vivaldi_HFSS_Builder('poll', first); assert(strcmp(polled.state, 'SCRIPT_READY'));
writeStatus(first.statusPath, ['JOB|' first.id sprintf('\r\n') 'STATE|SUCCEEDED']);
polled = Vivaldi_HFSS_Builder('poll', first); assert(strcmp(polled.state, 'SCRIPT_READY'));
writeStatus(first.statusPath, ['JOB|' first.id sprintf('\r\n') 'STATE|SUCCEEDED' sprintf('\r\n')]);
expectError(@()Vivaldi_HFSS_Builder('poll', first), 'Vivaldi:Unverified');
writeStatus(first.statusPath, ['JOB|' first.id sprintf('\r\n') 'STATE|FAILED' sprintf('\r\n')]);
polled = Vivaldi_HFSS_Builder('poll', first); assert(strcmp(polled.state, 'FAILED'));
checks{end + 1} = 'Protocol fixture: sai ACK, dòng dở, thiếu VERIFIED/file không được báo thành công';

expectError(@()Vivaldi_HFSS_Builder('simulate', first), 'Vivaldi:NotBuilt');
if ~ispc, expectError(@()Vivaldi_HFSS_Builder('launch', first, ''), 'Vivaldi:HFSS'); end
expectError(@()Vivaldi_HFSS_Builder('generate', p, fullfile(root, 'reference')), 'Vivaldi:Reference');
checks{end + 1} = 'Chặn solve khi chưa build, launch thiếu Windows và xuất vào reference';

% Kiểm tra encoder độc lập với CAD, gồm dấu nháy và ký tự tiếng Việt.
encodingPath = fullfile(folder, 'encoding.vbs');
w = hfssVivaldiScript(encodingPath, fullfile(folder, 'nhật ký.txt'), 'encoding');
w.line(['sbDesc = ' w.q('C:\Đồ án\anten "mới".aedt')]);
w.line('WriteStatus "STATE|FAILED"'); w.finish();
scripts{end + 1} = encodingPath;
checks{end + 1} = 'Escape dấu nháy và Unicode độc lập với locale';

% Mô phỏng được kiểm tra ở mức sinh script, không cần và không giả tạo nghiệm HFSS.
simPath = fullfile(folder, 'simulate.vbs');
w = hfssVivaldiScript(simPath, fullfile(folder, 'simulate-status.txt'), 'simulation');
cfg = Vivaldi_HFSS_Simulation('defaults');
Vivaldi_HFSS_Simulation('run', w, cfg);
Vivaldi_HFSS_Simulation('reports', w, cfg, folder, 'test');
w.finish(); scripts{end + 1} = simPath;
simText = fileread(simPath);
assert(~isempty(strfind(simText, 'oDesign.Analyze "Setup1"')));
assert(~isempty(strfind(simText, 'HasRealData(')));
assert(~isempty(strfind(simText, 'oModule.ExportToFile')));
assert(isempty(strfind(simText, 'oDesktop.NewProject')));
checks{end + 1} = 'Script solve riêng, helper report/export thật và gate dữ liệu nominal';

collisionFolder = fullfile(folder, 'collision'); mkdir(collisionFolder);
existing = fullfile(collisionFolder, 'Vivaldi_DualPol_001.aedt');
fid = fopen(existing, 'wb'); fwrite(fid, uint8('EXISTING_FILE_MUST_NOT_CHANGE')); fclose(fid);
collision = Vivaldi_HFSS_Builder('generate', p, collisionFolder, cfg, 'rectangle');
assert(~strcmp(existing, collision.projectPath));
assert(strcmp(fileread(existing), 'EXISTING_FILE_MUST_NOT_CHANGE'));
scripts{end + 1} = collision.scriptPath;
checks{end + 1} = 'File AEDT có sẵn không bị ghi đè hoặc thay byte';

% Hồi quy lỗi 450: phân biệt lệnh tạo mặt, query lỗi và không tìm thấy tên.
assert(~isempty(strfind(text, 'sbObjects = QueryGroup("Sheets")')));
assert(~isempty(strfind(text, 'HasName(sbObjects,"EquationSurface1")')));
assert(~isempty(strfind(text, 'HasName(sbObjects,"EquationSurface2")')));
assert(isempty(strfind(text, 'HasName(ObjectNames(),"EquationSurface')));
assert(~isempty(strfind(text, 'sbSource = Err.Source')));
assert(~isempty(strfind(text, 'OperationFailed')));
assert(~isempty(strfind(text, 'objects = QueryGroup(CStr(groupName))')));
assert(isempty(strfind(text, 'Scripting.Dictionary')));
assert(~isempty(strfind(text, 'vSaveDebug = False')));
assert(~isempty(strfind(text, 'oProject.SaveAs vDebugPath, False')));
assert(~isempty(strfind(text, 'DEBUG|SAVED_INCOMPLETE|')));
for step = 1:18
    assert(~isempty(strfind(text, sprintf('Stage "CHECK_%02d"', step))));
end
checks{end + 1} = 'Hồi quy 450: query Sheets riêng, không Dictionary, đủ checkpoint và log lệnh/lỗi';

report = struct('status', 'PASS', 'runtime', version, 'count', numel(checks), ...
    'checks', {checks}, 'scripts', {scripts}, ...
    'scope', 'Công thức, helper sinh script, encoder và protocol fixture; không chạy CAD/HFSS.', ...
    'MATLAB_GUI', 'PENDING', 'Windows_VBScript_compiler', 'PENDING', 'HFSS_CAD', 'PENDING', 'HFSS_solver', 'PENDING', 'Windows_query_fixtures', 'PENDING');
fid = fopen(fullfile(folder, 'build-only-tests.json'), 'w', 'n', 'UTF-8');
fprintf(fid, '%s\n', jsonencode(report)); fclose(fid);
fprintf('PASS: %d nhóm kiểm tra; HFSS CAD/solver và GUI vẫn PENDING.\n', numel(checks));
end

function expectError(callback, identifier)
% Mục đích: xác nhận guard từ chối đúng nguyên nhân, không nuốt lỗi ngoài dự kiến.
try, callback(); catch err, assert(strcmp(err.identifier, identifier), '%s: %s', err.identifier, err.message); return; end
error('Vivaldi:Test', 'Thiếu lỗi dự kiến %s.', identifier);
end

function writeStatus(path, text)
% Mục đích: tạo status fixture UTF-16LE rõ nguồn, không phải log HFSS thực.
fid = fopen(path, 'wb'); fwrite(fid, uint8([255 254]), 'uint8');
fwrite(fid, unicode2native(text, 'UTF-16LE'), 'uint8'); fclose(fid);
end
