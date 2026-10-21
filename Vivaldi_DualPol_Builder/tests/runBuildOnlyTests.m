function report = runBuildOnlyTests(folder, selection)
% Mục đích: kiểm tra công thức, script thật và guard; không giả lập CAD thành PASS.
if nargin < 1, folder = tempname; end
if nargin < 2, selection = 'all'; end
assert(ismember(selection, {'all', 'library', 'materials'}), 'Vivaldi:Test', 'Nhóm kiểm tra không hợp lệ.');
if ~isfolder(folder), mkdir(folder); end
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
checks = {}; scripts = {};
if ~strcmp(selection,'materials'), checks=checkLibraryPaths(root,folder); end
if ~strcmp(selection,'library'), checks=[checks checkMaterialData(folder)]; end
if ~strcmp(selection,'all')
    report = struct('status', 'PASS', 'runtime', version, 'count', numel(checks), 'checks', {checks}, ...
        'scope', ['Kiểm tra dữ liệu/fixture nhóm ' selection '; không chạy GUI hoặc HFSS.'], 'MATLAB_GUI', 'PENDING', 'HFSS_CAD', 'PENDING');
    name=[selection '-tests.json']; if strcmp(selection,'library'), name='library-path-tests.json'; end
    fid = fopen(fullfile(folder,name), 'w', 'n', 'UTF-8');
    fprintf(fid, '%s\n', jsonencode(report)); fclose(fid);
    fprintf('PASS: %d nhóm kiểm tra %s.\n', numel(checks),selection); return
end
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
db=Vivaldi_Calculation('material_defaults');
copper=db(strcmp({db.name},'Copper'));
second = Vivaldi_HFSS_Builder('generate', q, folder, Vivaldi_HFSS_Simulation('defaults'),'full',false,copper);
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
custom=copper;custom.name='Custom_Metal_Test';custom.conductivity=41234567.89;custom.permeability=1.01;
unicodeJob = Vivaldi_HFSS_Builder('generate', p, unicodeFolder,Vivaldi_HFSS_Simulation('defaults'),'full',false,custom);
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

% Snapshot từng vật liệu phải được đưa vào CAD, không chỉ đổi nhãn GUI.
assert(strcmp(first.bodyMaterial.name,'Aluminum'));
ct=fileread(second.scriptPath);
for part={'Vivaldi_1','Vivaldi_2','Box1','De'}
    assert(~isempty(strfind(ct,['MaterialMatches("' part{1} '","copper",False)'])));
end
assert(~isempty(strfind(ct,'"MaterialValue:="')));
assert(~isempty(strfind(ct,'MaterialDefinitionMatches(')));
ut=fileread(unicodeJob.scriptPath);
assert(~isempty(strfind(ut,'vBodyMaterial = "custom_metal_test"')));
assert(~isempty(strfind(ut,sprintf('%.17g',custom.conductivity))));
metadata=jsondecode(fileread(fullfile(unicodeJob.jobFolder,'job.json')));
assert(isequal(metadata.bodyMaterial,custom));
pec=db(strcmp({db.name},'PEC'));
ideal=Vivaldi_HFSS_Builder('generate',p,fullfile(folder,'pec'),cfg,'full',false,pec);
scripts{end+1}=ideal.scriptPath; idealText=fileread(ideal.scriptPath);
assert(~isempty(strfind(idealText,'vBodyMaterial = "pec"')) && isempty(strfind(idealText,'EnsureMaterial "pec"')));
expectError(@()Vivaldi_HFSS_Builder('generate',p,folder,cfg,'full',false,db(1)),'Vivaldi:MaterialBody');
checks{end+1}='Aluminum/Copper/PEC/custom: snapshot, thuộc tính và gán mọi phần thân; điện môi bị chặn';

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

function checks = checkLibraryPaths(root, folder)
% Mục đích: kiểm tra thiếu/xung đột bằng bản sao riêng; không đổi thư viện thật.
checks = {}; library = Vivaldi_HFSS_Builder('initialize');
assert(size(library.apiHelpers, 1) == 26);
for k = 1:size(library.resolved, 1)
    name = library.resolved{k, 1};
    assert(strcmp(which(name), library.resolved{k, 2}) && isfile(library.resolved{k, 2}));
end
checks{end + 1} = 'Đủ 26 helper upstream và custom helpers nhận đúng file tuyệt đối';
oldPath = path; oldFolder = pwd; temporary = tempname(folder); mkdir(temporary);
cleanup = onCleanup(@()restoreLibraryTestState(oldPath, oldFolder, temporary)); %#ok<NASGU>
cd(temporary);
repeated = Vivaldi_HFSS_Builder('initialize');
assert(strcmp(repeated.paths.root, root));
assert(strcmp(path, oldPath));
checks{end + 1} = 'Khởi tạo ngoài Current Folder và gọi lại không thay đổi path';

rmpath(library.paths.modeler3d); beforePoll = path;
poll = struct('id', 'path-test', 'statusPath', fullfile(temporary, 'no-status.txt'), 'state', 'SCRIPT_READY');
poll = Vivaldi_HFSS_Builder('poll', poll);
assert(strcmp(path, beforePoll) && strcmp(poll.state, 'SCRIPT_READY'));
Vivaldi_HFSS_Builder('initialize');
checks{end + 1} = 'Timer poll không addpath hoặc khởi tạo thư viện lại';

shadow = fullfile(temporary, 'shadow'); mkdir(shadow);
shadowFile = fullfile(shadow, 'hfssRectangle.m');
fid = fopen(shadowFile, 'w');
fprintf(fid, 'function hfssRectangle(varargin)\nerror(''Vivaldi:ShadowExecuted'',''Shadow must never execute'');\nend\n'); fclose(fid);
clear hfssRectangle;
addpath(shadow, '-begin'); beforeFailure = path;
Vivaldi_HFSS_Builder('initialize');
assert(strcmp(which('hfssRectangle'),fullfile(library.paths.modeler3d,'hfssRectangle.m')));
clear hfssRectangle;
cd(shadow); beforeFailure = path;
expectLibraryError(@()Vivaldi_HFSS_Builder('initialize'), 'Vivaldi:LibraryConflict', ...
    {'hfssRectangle', fullfile(library.paths.modeler3d, 'hfssRectangle.m'), shadowFile});
assert(strcmp(path, beforeFailure)); cd(temporary); clear hfssRectangle;
checks{end + 1} = 'Nạp dự án trước which: tự sửa shadow trên path, báo xung đột Current Folder';

fixture = fullfile(temporary, 'fixture'); mkdir(fixture);
% Chỉ sao chép mã cần kiểm tra, không copy output, references hoặc dữ liệu HFSS của người dùng.
mkdir(fullfile(fixture, 'third_party'));
copyfile(library.paths.library, fullfile(fixture, 'third_party', 'hfss-api'));
copyfile(library.paths.customHelpers, fullfile(fixture, 'custom_helpers'));
for name = {'Vivaldi_HFSS_Builder.m', 'Vivaldi_GUI.m', 'Vivaldi_Calculation.m', 'Vivaldi_HFSS_Simulation.m'}
    copyfile(fullfile(root, name{1}), fullfile(fixture, name{1}));
end
source = fileread(fullfile(fixture, 'Vivaldi_HFSS_Builder.m'));
source = strrep(source, 'function out = Vivaldi_HFSS_Builder(action, varargin)', 'function out = FixtureHFSSBuilder(action, varargin)');
fid = fopen(fullfile(fixture, 'FixtureHFSSBuilder.m'), 'w', 'n', 'UTF-8'); fprintf(fid, '%s', source); fclose(fid);
addpath(fixture, '-end');
% Từng thư mục bắt buộc đều bị phát hiện trước bất kỳ sửa đổi path nào.
for name = {'library', 'general', 'modeler3d', 'boundary', 'analysis', 'radiation', 'reporter', 'mesh', 'fieldsCalculator', 'customHelpers'}
    relative = library.paths.(name{1})(numel(root) + 2:end);
    expected = fullfile(fixture, relative); hidden = [expected '_hidden'];
    movefile(expected, hidden); beforeFailure = path;
    expectLibraryError(@()FixtureHFSSBuilder('initialize'), 'Vivaldi:LibraryFolderMissing', {name{1}, expected});
    assert(strcmp(path, beforeFailure)); movefile(hidden, expected);
end
checks{end + 1} = 'Phát hiện từng thư mục bắt buộc bị thiếu; không thay đổi path khi lỗi';

missing = {fullfile('third_party', 'hfss-api', 'general', 'hfssNewProject.m'), ...
    fullfile('third_party', 'hfss-api', '3dmodeler', 'hfssRectangle.m'), ...
    fullfile('custom_helpers', 'hfssVivaldiScript.m'), fullfile('custom_helpers', 'vivaldiPreview3D.m'), ...
    fullfile('custom_helpers', 'hfssVivaldiChecks.vbs')};
for k = 1:numel(missing)
    expected = fullfile(fixture, missing{k}); hidden = [expected '.hidden'];
    movefile(expected, hidden); beforeFailure = path;
    [~, name, extension] = fileparts(expected);
    expectLibraryError(@()FixtureHFSSBuilder('initialize'), 'Vivaldi:LibraryFileMissing', {[name extension], expected});
    assert(strcmp(path, beforeFailure)); movefile(hidden, expected);
end
checks{end + 1} = 'Phát hiện thiếu file API, hai custom helper và runtime VBS bằng đường dẫn đầy đủ';
end

function expectLibraryError(callback, identifier, fragments)
% Mục đích: lỗi phải đúng loại và nêu đủ tên/đường dẫn, không chỉ báo thất bại chung.
try
    callback();
catch err
    assert(strcmp(err.identifier, identifier), '%s: %s', err.identifier, err.message);
    for k = 1:numel(fragments)
        assert(~isempty(strfind(err.message, fragments{k})), '%s', err.message); %#ok<STREMP>
    end
    return
end
error('Vivaldi:Test', 'Thiếu lỗi thư viện dự kiến %s.', identifier);
end

function restoreLibraryTestState(oldPath, oldFolder, temporary)
% Mục đích: trả nguyên path/Current Folder và xóa chỉ fixture độc lập của kiểm thử.
cd(oldFolder); path(oldPath);
clear hfssRectangle FixtureHFSSBuilder;
if isfolder(temporary), rmdir(temporary, 's'); end
end

function checks = checkMaterialData(folder)
% Mục đích: kiểm tra dữ liệu/lưu MAT thật; không dùng dữ liệu RF giả hoặc HFSS giả.
checks={}; database=Vivaldi_Calculation('material_defaults');
assert(numel(database)==11);
aluminum=database(strcmp({database.name},'Aluminum')); copper=database(strcmp({database.name},'Copper')); pec=database(strcmp({database.name},'PEC'));
assert(aluminum.conductivity==38000000 && aluminum.permeability==1.000021);
assert(copper.conductivity==58000000 && copper.permeability==.999991);
assert(isempty(pec.conductivity)); Vivaldi_Calculation('material_body',pec);
for k=1:numel(database),Vivaldi_Calculation('material_validate',database(k));end
checks{end+1}='11 vật liệu, Aluminum/Copper đúng nguồn và PEC không sigma giả';
assert(numel(Vivaldi_Calculation('material_filter',database,'rOgErS'))==2);
assert(numel(Vivaldi_Calculation('material_filter',database,''))==11);
assert(isempty(Vivaldi_Calculation('material_filter',database,'unknown-material')));
checks{end+1}='Tìm kiếm không phân biệt hoa/thường và không làm mất danh sách';
for field={'conductivity','permeability','permittivity','lossTangent'}
    bad=aluminum;bad.(field{1})=NaN;expectError(@()Vivaldi_Calculation('material_validate',bad),'Vivaldi:Material');
end
bad=aluminum;bad.conductivity=0;expectError(@()Vivaldi_Calculation('material_validate',bad),'Vivaldi:Material');
bad=aluminum;bad.name='';expectError(@()Vivaldi_Calculation('material_validate',bad),'Vivaldi:Material');
bad=database(1);bad.lossTangent=-.1;expectError(@()Vivaldi_Calculation('material_validate',bad),'Vivaldi:Material');
expectError(@()Vivaldi_Calculation('material_body',database(1)),'Vivaldi:MaterialBody');
checks{end+1}='Chặn số không hữu hạn, dữ liệu sai loại và điện môi áp lên thân kim loại';
file=fullfile(folder,'preferences','custom_materials.mat');
metal=copper;metal.name='My_Custom_Metal';metal.conductivity=34567890.123;metal.permeability=1.03;
loaded=Vivaldi_Calculation('material_save',file,metal);
assert(numel(loaded)==12 && isfile(file));
[loaded,message]=Vivaldi_Calculation('material_load',file);assert(isempty(message));
assert(isequal(loaded(end),metal));
dielectric=database(1);dielectric.name='My_Custom_Dielectric';dielectric.permittivity=4.71;dielectric.lossTangent=.00321;
Vivaldi_Calculation('material_save',file,dielectric);
[loaded,message]=Vivaldi_Calculation('material_load',file);assert(isempty(message) && numel(loaded)==13 && isequal(loaded(end),dielectric));
assert(isfile([file '.bak']));
checks{end+1}='Lưu/nạp lại custom kim loại và điện môi, có backup, giữ độ chính xác';
before=fileBytes(file);expectError(@()Vivaldi_Calculation('material_save',file,copper),'Vivaldi:MaterialDuplicate');
metal.name=lower(metal.name);expectError(@()Vivaldi_Calculation('material_save',file,metal),'Vivaldi:MaterialDuplicate');
assert(isequal(before,fileBytes(file)));
checks{end+1}='Không ghi đè tên mặc định/custom trùng nhau kể cả khác hoa/thường';
corrupt=fullfile(folder,'preferences','bad.mat');fid=fopen(corrupt,'wb');fwrite(fid,uint8('CORRUPT_FILE_MUST_STAY'));fclose(fid);
before=fileBytes(corrupt);[loaded,message]=Vivaldi_Calculation('material_load',corrupt);
assert(numel(loaded)==11 && ~isempty(message));
expectError(@()Vivaldi_Calculation('material_save',corrupt,metal),'Vivaldi:MaterialConfig');
assert(isequal(before,fileBytes(corrupt)));
checks{end+1}='Cấu hình lỗi được báo và giữ nguyên byte, không âm thầm xóa hoặc ghi đè';
end

function bytes = fileBytes(file)
% Mục đích: đối chiếu file cấu hình binary không phụ thuộc encoding MATLAB/Windows.
fid=fopen(file,'rb');cleanup=onCleanup(@()fclose(fid)); %#ok<NASGU>
bytes=fread(fid,Inf,'*uint8');
end
