function report = runHFSSAPITests(outputDir, selection)
    % Mục đích: kiểm thử công thức, helper thật và giao thức status trên MATLAB/Octave.
    % Trạng thái giả chỉ kiểm tra parser/state machine; không chứng minh CAD HFSS.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root, fullfile(root, 'core'), fullfile(root, 'automation'), fullfile(root, 'custom_helpers'), fullfile(root, 'results'));
    if nargin < 1
        outputDir = tempname;
    end
    if nargin < 2
        selection = 'all';
    end
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end
    checks = {};
    p = vivaldiDefaultParams();
    backend = VivaldiHFSS(root);
    %% 1. Capture gọi helper thật và giữ đủ độ chính xác/biểu thức
    w = VivaldiScriptWriter();
    text = w.capture(@hfssRectangle, {'Test', 'Y', [0 0 0], 1, 1, 'mm'}, ...
                     {'XStart', '-x_feed'; 'Width', '-L_patch'; 'Height', '-aperture_w'});
    assert(~isempty(strfind(text, 'oEditor.CreateRectangle')) && ~isempty(strfind(text, '"Width:=", "-L_patch"'))); %#ok<STREMP>
    assert(isequal(w.UsedHelpers, {'hfssRectangle'}));
    q = p;
    q.L_flare_1 = 43.287000000000006;
    hfssVivaldiExtensions(w, 'variables', q, false, {'L_flare_1'});
    assert(~isempty(strfind(strjoin(w.Lines, newline), [sprintf('%.17g', q.L_flare_1) 'mm']))); %#ok<STREMP>
    checks{end + 1} = 'Helper thư viện thật và độ chính xác biến tham số';
    %% 2. Các mở rộng giữ BothSides và parent/local origin
    w = VivaldiScriptWriter();
    hfssVivaldiExtensions(w, 'thicken', 'Test');
    s = strjoin(w.Lines, newline);
    assert(~isempty(strfind(s, '"BothSides:=", True')) && ~isempty(strfind(s, '"Thickness:=", "thickness"'))); %#ok<STREMP>
    w = VivaldiScriptWriter();
    hfssVivaldiExtensions(w, 'coordinate', 'RelativeCS1', 'patch_td', {'0mm', '-thickness/2', '0mm'});
    s = strjoin(w.Lines, newline);
    assert(~isempty(strfind(s, '"NAME:Reference CS", "Value:=", "patch_td"')) && ~isempty(strfind(s, '-thickness/2'))); %#ok<STREMP>
    checks{end + 1} = 'BothSides=true và CS lồng nhau có biểu thức';
    %% 3. Dựng script đầy đủ có gọi thư viện và có probe vùng loe thật
    build = backend.generate('build', p, struct('projectPath', fullfile(outputDir, 'Scratch.aedt')));
    s = VivaldiHFSS.readUTF16(build.scriptPath);
    needed = {'hfssNewProject', 'hfssInsertDesign', 'hfssRectangle', 'hfssBox', 'hfssCylinder', 'hfssCircle', ...
              'hfssSubtract', 'hfssUnite', 'hfssRotate', 'hfssMove', 'hfssCreateRelativeCS', 'hfssSetWCS', ...
              'hfssAssignMaterial', 'hfssAssignLumpedPort', 'hfssAssignRadiation', 'hfssInsertSolution', 'hfssSaveProject'};
    assert(all(ismember(needed, build.helpers)));
    assert(~isempty(strfind(s, 'CreateEquationSurface')) && ~isempty(strfind(s, 'CheckPoints "Vivaldi_1"'))); %#ok<STREMP>
    for k = 1:18
        assert(~isempty(strfind(s, sprintf('CHECK_%02d', k))));
    end %#ok<STREMP>
    main = mainBody(s);
    assert(isempty(regexp(main, 'oDesign\.(?:Analyze|Solve)\b', 'once')));
    compat = backend.generate('compatibility', p, struct('projectPath', fullfile(outputDir, 'Compatibility.aedt')));
    assert(~isempty(strfind(VivaldiHFSS.readUTF16(compat.scriptPath), 'ProbeSheet'))); %#ok<STREMP>
    checks{end + 1} = 'Kịch bản dựng dùng helper gốc, 18 checkpoint và không tự solve';
    %% 4. Giữ thứ tự trim/rotate, full-cylinder snapshots và kiểm tra lỗ
    assert(before(main, 'CloneNamed "EquationSurface2", "EquationSurface2_1"', 'oEditor.Rotate'));
    assert(before(main, 'CloneNamed "cable_out", "cable_out_2"', '"Blank Parts:=", "cable_out"'));
    assert(~isempty(strfind(main, 'VolumeMatches("cable_out"')) && ~isempty(strfind(main, 'CircleMatches("port2"'))); %#ok<STREMP>
    checks{end + 1} = 'Thứ tự CAD, snapshot trước hollowing, volume và port readback';
    %% 5. Update chỉ sửa biến thay đổi trong cùng project, có rollback và không save/solve
    working = fullfile(outputDir, 'Working.aedt');
    backend.copyReference(working);
    assert(~VivaldiHFSS.hasLiteralMove(working));
    q = p;
    q.L_flare_1 = 43.287;
    q.aperture_w = 24.635;
    q.cavity_w = 1.725;
    q.thickness = 2.35;
    update = backend.generate('update', q, struct('projectPath', working, 'before', p));
    s = VivaldiHFSS.readUTF16(update.scriptPath);
    main = mainBody(s);
    assert(isempty(regexp(s, 'oDesktop\.NewProject|oProject\.InsertDesign|oProject\.SaveAs|oProject\.Save\b|oDesign\.(?:Analyze|Solve)\b', 'once')));
    assert(numel(strfind(main, 'oDesign.ChangeProperty')) == 4); %#ok<STREMP>
    assert(ismember('hfssVariableChange', update.helpers) && ~ismember('hfssNewProject', update.helpers));
    assert(~isempty(strfind(s, 'Sub RestorePrevious')) && ~isempty(strfind(s, 'STATE|FAILED_ROLLED_BACK'))); %#ok<STREMP>
    checks{end + 1} = 'Update 4 biến, cùng project, rollback, không NewProject/Save/Analyze';
    %% 6. Save không đổi tên project; Save As phải chọn đường dẫn mới
    saveJob = backend.generate('save', p, struct('projectPath', working));
    s = VivaldiHFSS.readUTF16(saveJob.scriptPath);
    assert(~isempty(strfind(s, 'oProject.Save')) && isempty(strfind(s, 'oProject.SaveAs'))); %#ok<STREMP>
    saveAs = backend.generate('saveas', p, struct('projectPath', working, 'destination', fullfile(outputDir, 'NewVersion.aedt')));
    assert(ismember('hfssSaveProject', saveAs.helpers));
    checks{end + 1} = 'Save cùng project và Save As chủ động';
    %% 7. Solver và báo cáo thật dùng helper thư viện, chỉ giải Setup1
    solve = backend.generate('simulate', p, struct('projectPath', working));
    s = VivaldiHFSS.readUTF16(solve.scriptPath);
    assert(~isempty(strfind(s, 'oDesign.Analyze "Setup1"')) && isempty(strfind(s, 'AnalyzeAll'))); %#ok<STREMP>
    assert(ismember('hfssSolveSetup', solve.helpers) && ~isempty(strfind(s, 'HasRealData("Modal Solution Data"'))); %#ok<STREMP>
    reportJob = backend.generate('reports', p, struct('projectPath', working, 'resultsDir', outputDir));
    s = VivaldiHFSS.readUTF16(reportJob.scriptPath);
    assert(all(ismember({'hfssCreateReport', 'hfssExportToFile'}, reportJob.helpers)));
    assert(~isempty(strfind(s, '"Modal Solution Data"')) && ~isempty(strfind(s, 'Array("Nominal")'))); %#ok<STREMP>
    assert(~isempty(strfind(s, '"Freq:=", Array("5GHz")'))); %#ok<STREMP>
    checks{end + 1} = 'Solver riêng Setup1 và báo cáo có gate dữ liệu nominal thật';
    %% 8. Bảo vệ nguồn, file đã có và lịch sử literal chưa chuẩn hóa
    expectError(@()backend.checkPath(backend.ReferencePath, false));
    expectError(@()backend.generate('build', p, struct('projectPath', working)));
    literal = fullfile(outputDir, 'Literal.aedt');
    copyfile(backend.ReferencePath, literal);
    expectError(@()backend.generate('update', q, struct('projectPath', literal, 'before', p)));
    backend.LastValid = p;
    backend.Healthy = true;
    backend.WorkingPath = working;
    backend.Offline = true;
    expectError(@()backend.start('update', q, struct('projectPath', literal)));
    checks{end + 1} = 'Không ghi đè nguồn, không dựng đè đích, chặn Move literal khi đổi thickness';
    %% 9. ACK phải đúng ID và chỉ đọc dòng UTF16 đã hoàn chỉnh
    status = fullfile(outputDir, 'status-fixture.txt');
    VivaldiHFSS.writeUTF16(status, sprintf('JOB|abc-extra\nVERIFIED|1\nSTATE|BUILT\n'));
    data = VivaldiHFSS.readStatus(status, 'abc');
    assert(~data.acknowledged);
    VivaldiHFSS.writeUTF16(status, sprintf('JOB|abc\nCHECK|TEST|FAIL|PENDING|Lỗi thử tiếng Việt\nSTATE|BUILT'));
    data = VivaldiHFSS.readStatus(status, 'abc');
    assert(data.acknowledged && isempty(data.state));
    assert(strcmp(data.records(1).message, 'Lỗi thử tiếng Việt'));
    checks{end + 1} = 'UTF16/Unicode, ACK chính xác và dòng status chưa hoàn tất';
    %% 10. Fixture status chỉ kiểm tra state machine, không phải HFSS runtime
    backend.ActiveJob = build;
    fixtureStatus(build.statusPath, build.id, 'BUILT', p, true);
    backend.poll();
    assert(isempty(backend.ActiveJob) && backend.Healthy && backend.Dirty);
    backend.ActiveJob = update;
    fixtureStatus(update.statusPath, update.id, 'FAILED_ROLLED_BACK', p, false);
    backend.poll();
    assert(backend.Healthy && strcmp(backend.LastState, 'FAILED_ROLLED_BACK') && isequal(backend.LastValid, p));
    backend.ActiveJob = update;
    fixtureStatus(update.statusPath, update.id, 'UPDATED', q, false);
    expectError(@()backend.poll());
    assert(~isempty(backend.ActiveJob));
    backend.ActiveJob = [];
    backend.ActiveJob = saveJob;
    backend.ActiveJob.cfg.destination = fullfile(outputDir, 'SavedBad.aedt');
    fid = fopen(backend.ActiveJob.cfg.destination, 'w');
    fprintf(fid, 'Not an AEDT file - protocol fixture only');
    fclose(fid);
    backend.LastState = 'RUNNING';
    fixtureStatus(saveJob.statusPath, saveJob.id, 'SAVED', p, true);
    expectError(@()backend.poll());
    assert(~strcmp(backend.LastState, 'SAVED'));
    backend.ActiveJob = [];

    checks{end + 1} = 'Protocol giả: hoàn tất, rollback và từ chối terminal thiếu VERIFIED';
    %% 11. Chỉ tạo script không được biến thành đã dựng/đã mô phỏng
    backend = VivaldiHFSS(root);
    backend.Offline = true;
    job = backend.start('build', p, struct('projectPath', fullfile(outputDir, 'Offline.aedt')));
    assert(isfile(job.scriptPath) && isempty(backend.ActiveJob) && ~backend.Healthy && isempty(backend.LastValid) && strcmp(backend.LastState, 'SCRIPT_READY'));
    checks{end + 1} = 'Chế độ chỉ sinh script giữ trạng thái chưa kiểm chứng';
    %% 12. Không lấy launcher exit làm thành công; timeout tiếp tục khóa job
    backend.ActiveJob = build;
    backend.ActiveJob.startedAt = now - 1;
    backend.ActiveJob.timeoutSeconds = 1;
    if isfile(build.statusPath)
        delete(build.statusPath);
    end
    backend.poll();
    assert(strcmp(backend.LastState, 'TIMED_OUT') && ~isempty(backend.ActiveJob) && ~backend.Healthy);
    backend.ActiveJob = [];
    checks{end + 1} = 'Không có ACK/terminal và timeout không được báo thành công';
    if strcmp(selection, 'all')
        %% 13. Công thức, miền kích thước và nguồn AEDT
        g = vivaldiCalculateGeometry(p);
        near(g.L_patch, 49.23630329005893, 1e-10);
        near(g.x_feed, 2.49933086077896, 1e-11);
        near(g.z_feed, .66369670994107, 1e-11);
        near(g.r_flare, .07950171237314518, 1e-13);
        info = vivaldiInspectReference(backend.ReferencePath);
        assert(size(info.variables, 1) == 31 && info.portCount == 2 && info.noArray);
        for lengthValue = [37.628 43.287 61.352 90]
            q = p;
            q.L_flare_1 = lengthValue;
            assert(vivaldiValidateParams(q));
        end
        invalid = {'slot_feed_w', 0; 'r_cabmid', .1; 'cavity_w', 200; 'them', -6.4; 'h_de', NaN};
        for k = 1:size(invalid, 1)
            q = p;
            q.(invalid{k, 1}) = invalid{k, 2};
            assert(~vivaldiValidateParams(q));
        end
        checks{end + 1} = 'Công thức nguồn, kích thước lẻ và miền không hợp lệ';
        %% 14. Chiều dài mục tiêu bất kỳ, không chỉ preset
        for target = [49 50 57.35 91.624]
            [q, r] = vivaldiSolveTargetLength(p, target);
            near(r.residual, 0, 1e-6);
            assert(vivaldiValidateParams(q));
        end
        expectError(@()vivaldiSolveTargetLength(p, 1));
        checks{end + 1} = 'Tìm nghiệm chiều dài mục tiêu và residual';
        %% 15. Phép biến đổi phân cực và tọa độ port
        near(norm(g.ports(2).center - [11 10.54933086077896 -2.83630329005893]), 0, 1e-10);
        near(norm(g.transition.left(1, :) - [-g.x_feed 0 g.z_feed]), 0, 1e-10);
        assert(strcmp(g.cs.RelativeCS1.parent, 'patch_td'));
        graph = vivaldiDependencyGraph(p);
        assert(numel(unique({graph.name})) == numel(graph));
        checks{end + 1} = 'CS, transition, phép biến đổi dual-pol và dependency graph';
        %% 16. Thuật toán HPBW dùng fixture toán, không phải kết quả anten
        angles = (-60:60)';
        r = HFSSResultImporter.hpbw(angles, -3 * (angles / 20).^2);
        near(r.widthDeg, 40, 1e-8);
        r = HFSSResultImporter.hpbw(angles, zeros(size(angles)));
        assert(isnan(r.widthDeg));
        checks{end + 1} = 'HPBW nội suy và thiếu crossing';
    end
    if exist('OCTAVE_VERSION', 'builtin')
        runtime = ['GNU Octave ' OCTAVE_VERSION];
    else
        runtime = ['MATLAB ' version];
    end
    report = struct('runtime', runtime, 'time', datestr(now, 30), 'selection', selection, 'count', numel(checks), 'checks', {checks}, ...
                    'scope', 'Công thức + helper sinh VBS thật + protocol status giả; không chạy CAD/HFSS', ...
                    'MATLAB_GUI', 'PENDING', 'HFSS_CAD', 'PENDING', 'HFSS_solver', 'PENDING', ...
                    'scripts', {{build.scriptPath, compat.scriptPath, update.scriptPath, saveJob.scriptPath, saveAs.scriptPath, solve.scriptPath, reportJob.scriptPath, job.scriptPath}});
    vivaldiWriteJSON(fullfile(outputDir, 'hfss-api-portable-results.json'), report);
    fprintf('ĐẠT: %d nhóm kiểm thử (%s). GUI/HFSS thực tế vẫn PENDING.\n', numel(checks), runtime);
end

function text = mainBody(text)
    % Chỉ chọn Main, không nhầm tên method trong hàm runtime/rollback.
    first = strfind(text, ['Sub Main' newline]);
    assert(numel(first) == 1);
    text = text(first:end);
end

function yes = before(text, a, b)
    x = strfind(text, a);
    y = strfind(text, b);
    assert(~isempty(x) && ~isempty(y));
    yes = x(1) < y(1);
end

function near(a, b, tolerance)
    assert(abs(a - b) <= tolerance, 'Sai số số học vượt ngưỡng.');
end

function expectError(f)
    raised = false;
    try
        f();
    catch
        raised = true;
    end
    assert(raised, 'Cần phát sinh lỗi nhưng thao tác lại trả về bình thường.');
end

function fixtureStatus(path, id, state, p, verified)
    % Chỉ phục vụ kiểm tra parser/state machine. Không dùng làm báo cáo HFSS thật.
    [~, meta] = vivaldiDefaultParams();
    lines = {['JOB|' id]};
    for k = 1:numel(meta)
        n = meta(k).name;
        lines{end + 1} = ['PARAM|' n '|' sprintf('%.17g', p.(n)) meta(k).unit];
    end %#ok<AGROW>
    if verified
        lines{end + 1} = 'VERIFIED|1';
    end
    lines{end + 1} = ['STATE|' state];
    VivaldiHFSS.writeUTF16(path, [strjoin(lines, newline) newline]);
end
