function out = VivaldiSimulation(action, varargin)
    % Mục đích: dùng helper gốc để cấu hình solver/port/report; không tự chạy khi đổi số.
    % Dữ liệu chỉ được xuất sau truy vấn nghiệm thực tại nominal variation hiện tại.
    out = [];
    switch action
        case 'defaults'
            out = struct('adaptiveGHz', 5, 'startGHz', 5, 'stopGHz', 20, 'stepGHz', .25, ...
                         'deltaS', .02, 'minimumPasses', 5, 'maximumPasses', 50, 'powerW', [1 0], 'phaseDeg', [0 0], 'fieldGHz', 5);
        case 'validate'
            c = varargin{1};
            for n = {'adaptiveGHz', 'startGHz', 'stopGHz', 'stepGHz', 'deltaS', 'minimumPasses', 'maximumPasses', 'fieldGHz'}
                v = c.(n{1});
                assert(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v) && v > 0, 'Vivaldi:Simulation', '%s phải dương hữu hạn.', n{1});
            end
            assert(c.stopGHz > c.startGHz && c.stepGHz <= c.stopGHz - c.startGHz, 'Vivaldi:Sweep', 'Cần kết thúc > bắt đầu và bước không vượt dải tần.');
            assert(c.minimumPasses == fix(c.minimumPasses) && c.maximumPasses == fix(c.maximumPasses) && c.maximumPasses >= c.minimumPasses, 'Vivaldi:Passes', 'Số vòng adaptive phải là số nguyên hợp lệ.');
            assert(isnumeric(c.powerW) && isreal(c.powerW) && numel(c.powerW) == 2 && all(isfinite(c.powerW)) && all(c.powerW >= 0) && sum(c.powerW) > 0, 'Vivaldi:Power', 'Hai công suất phải không âm, tổng lớn hơn 0.');
            assert(isnumeric(c.phaseDeg) && isreal(c.phaseDeg) && numel(c.phaseDeg) == 2 && all(isfinite(c.phaseDeg)), 'Vivaldi:Phase', 'Cần hai pha hữu hạn theo độ.');
        case 'create'
            w = varargin{1};
            p = varargin{2};
            c = varargin{3};
            VivaldiSimulation('validate', c);
            w.stage('CHECK_16');
            ports(w);
            w.pass('CHECK_16', 'PENDING', 'Hai Lumped Ports 50 ohm; pha field cần kiểm chứng riêng');
            w.stage('CHECK_17');
            w.lib(@hfssSetWCS, {'Global'});
            args = {'NAME:RegionParameters'};
            for d = {'+X', '-X', '+Y', '-Y', '+Z', '-Z'}
                args = [args, {[d{1} 'PaddingType:='], 'Absolute Offset', [d{1} 'Padding:='], '20mm'}];
            end %#ok<AGROW>
            attrs = {'NAME:Attributes', 'Name:=', 'RadiatingSurface', 'Flags:=', 'Wireframe#', 'PartCoordinateSystem:=', 'Global', 'MaterialValue:=', '"vacuum"', 'SolveInside:=', true};
            w.call(['oEditor.CreateRegion ' w.literal(args) ', ' w.literal(attrs)], 'Tạo region với offset tuyệt đối 20 mm');
            w.lib(@hfssAssignRadiation, {'Open1', 'RadiatingSurface', false});
            w.call('Set oBoundary = oDesign.GetModule("BoundarySetup")', 'Đọc boundary');
            w.require('PairExists(oBoundary.GetBoundaries(),"Open1","Radiation")', 'Không có Open1 Radiation');
            w.pass('CHECK_17', 'PENDING', 'Đã đọc lại boundary Open1');
            w.stage('CHECK_18');
            % Helper mesh gốc không biểu diễn đầy đủ các flag InitialMeshSettings của nguồn.
            mesh = {'NAME:MeshSettings', ...
                    {'NAME:GlobalSurfApproximation', 'CurvedSurfaceApproxChoice:=', 'UseSlider', 'SliderMeshSettings:=', 5}, ...
                    {'NAME:GlobalCurvilinear', 'Apply:=', false}, {'NAME:GlobalModelRes', 'UseAutoLength:=', true}, ...
                    'MeshMethod:=', 'Auto', 'UseLegacyFaceterForTauVolumeMesh:=', false, 'DynamicSurfaceResolution:=', false, ...
                    'UseFlexMeshingForTAUvolumeMesh:=', false, 'UseAlternativeMeshMethodsAsFallBack:=', true, 'AllowPhiForLayeredGeometry:=', true};
            w.call(['Set oModule = oDesign.GetModule("MeshSetup")' newline 'oModule.InitialMeshSettings ' w.literal(mesh)], 'Giữ mesh slider 5 và các flag nguồn');
            setup(w, c, false);
            hfssVivaldiExtensions(w, 'sweep', c, false);
            spheres = {'3D', [0 180 2], [-180 180 2]; 'Elevation', [-180 180 1], [0 90 90]; 'Azimuth', [90 90 0], [-180 180 1]};
            for k = 1:3
                text = w.capture(@hfssInsertFarFieldSphereSetup, {spheres{k, 1}, spheres{k, 2}, spheres{k, 3}});
                assert(~isempty(strfind(text, 'oModule.InsertFarFieldSphereSetup')), 'Vivaldi:LibraryFormat', 'Mẫu far-field của thư viện đã thay đổi.'); %#ok<STREMP>
                text = strrep(text, 'oModule.InsertFarFieldSphereSetup', 'oModule.InsertInfiniteSphereSetup');
                w.call(text, 'Tạo miền quan sát trường xa bằng method 2021 R2');
            end
            excite(w, c);
            w.pass('CHECK_18', 'PENDING', 'Đã tạo Setup1/Sweep và trường xa; chưa chạy solver');
        case 'apply'
            w = varargin{1};
            c = varargin{2};
            VivaldiSimulation('validate', c);
            setup(w, c, true);
            hfssVivaldiExtensions(w, 'sweep', c, true);
            excite(w, c);
        case 'run'
            w = varargin{1};
            c = varargin{2};
            VivaldiSimulation('apply', w, c);
            text = w.capture(@hfssSolveSetup, {'Setup1'});
            text = regexprep(text, 'oDesign\.Solve\s*_\s*\r?\n\s*Array\("Setup1"\)', 'oDesign.Analyze "Setup1"');
            assert(~isempty(strfind(text, 'oDesign.Analyze "Setup1"')), 'Vivaldi:LibraryFormat', 'Không nhận diện helper giải Setup1.'); %#ok<STREMP>
            w.call(text, 'Chạy riêng Setup1 theo yêu cầu người dùng');
            gate(w, 'Modal Solution Data', {}, nominal({'Freq:=', {'All'}}), {'mag(S(1,1))', 'mag(S(2,2))', 'mag(S(2,1))', 'mag(S(1,2))'}, 0);
        case 'reports'
            w = varargin{1};
            c = varargin{2};
            folder = varargin{3};
            prefix = varargin{4};
            frequency = sprintf('%.17gGHz', c.fieldGHz);
            specs = {'SParameters', 1, 1, {}, {'Freq'}, {'Freq', 'dB(S(1,1))', 'dB(S(2,2))', 'dB(S(2,1))', 'dB(S(1,2))'}; ...
                     'VSWR', 1, 1, {}, {'Freq'}, {'Freq', 'VSWR(1)', 'VSWR(2)'}; ...
                     'Impedance', 1, 1, {}, {'Freq'}, {'Freq', 're(Z(1,1))', 'im(Z(1,1))', 're(Z(2,2))', 'im(Z(2,2))'}; ...
                     'Gain', 5, 1, {'Context:=', 'Elevation'}, {'Theta', 'Phi', 'Freq'}, {'Theta', 'dB(RealizedGainTotal)'}; ...
                     'Pattern', 5, 3, {'Context:=', 'Elevation'}, {'Theta', 'Phi', 'Freq'}, {'Theta', 'dB(RealizedGainTotal)'}; ...
                     'Azimuth', 5, 3, {'Context:=', 'Azimuth'}, {'Theta', 'Phi', 'Freq'}, {'Phi', 'dB(RealizedGainTotal)'}; ...
                     'Pattern3D', 5, 7, {'Context:=', '3D'}, {'Theta', 'Phi', 'Freq'}, {'Phi', 'Theta', 'dB(RealizedGainTotal)'}; ...
                     'Efficiency', 1, 1, {'Context:=', '3D'}, {'Freq'}, {'Freq', 'RadiationEfficiency'}};
            out = struct('label', {}, 'path', {});
            for k = 1:size(specs, 1)
                name = [prefix '_' specs{k, 1}];
                base = fullfile(folder, name);
                context = '';
                if ~isempty(specs{k, 4})
                    context = specs{k, 4}{2};
                end
                families = {};
                for n = specs{k, 5}
                    families = [families, {[n{1} ':='], {'All'}}];
                end %#ok<AGROW>
                if k >= 4
                    families = replaceFamily(families, 'Freq', {frequency});
                    if k == 6
                        families = replaceFamily(families, 'Theta', {'90deg'});
                    elseif k == 4 || k == 5
                        families = replaceFamily(families, 'Phi', {'0deg'});
                    end
                end
                if k < 4
                    category = 'Modal Solution Data';
                    field = 0;
                elseif k == 8
                    category = 'Antenna Parameters';
                    field = c.fieldGHz;
                else
                    category = 'Far Fields';
                    field = c.fieldGHz;
                end
                expression = specs{k, 6}(2:end);
                if k == 7
                    expression = specs{k, 6}(3:end);
                end
                condition = dataCondition(w, category, specs{k, 4}, nominal(families), expression, field);
                w.call(['sbHasData = ' condition], ['Kiểm tra dữ liệu thực: ' specs{k, 1}]);
                if k == 1
                    w.require('sbHasData', 'Chưa có S-parameters thực cho mô hình hiện tại');
                else
                    w.line('If sbHasData Then');
                end
                w.require(['Not fs.FileExists(' w.q([base '.csv']) ')'], 'Không ghi đè kết quả CSV đã tồn tại');
                vars = [fieldnames(vivaldiDefaultParams())', specs{k, 5}];
                text = w.capture(@hfssCreateReport, {name, specs{k, 2}, specs{k, 3}, 'Setup1', 'Sweep', context, '', vars, specs{k, 6}});
                if k == 8
                    text = strrep(text, '"Modal S Parameter"', '"Antenna Parameters"');
                else
                    text = strrep(text, '"Modal S Parameter"', '"Modal Solution Data"');
                end
                for n = fieldnames(vivaldiDefaultParams())'
                    text = strrep(text, ['"' n{1} ':=", Array("All")'], ['"' n{1} ':=", Array("Nominal")']);
                end
                for j = 1:2:numel(families)
                    if ~isequal(families{j + 1}, {'All'})
                        text = strrep(text, ['"' families{j} '", Array("All")'], [w.q(families{j}) ', ' w.literal(families{j + 1})]);
                    end
                end
                w.call(text, ['Tạo báo cáo ' specs{k, 1}]);
                w.lib(@hfssExportToFile, {name, base, 'csv'});
                w.require(['fs.FileExists(' w.q([base '.csv']) ')'], 'HFSS chưa xuất file CSV');
                w.require(['fs.GetFile(' w.q([base '.csv']) ').Size > 10'], 'CSV xuất ra rỗng');
                w.line(['WriteStatus ' w.q(['CSV|' specs{k, 1} '|' base '.csv'])]);
                out(end + 1) = struct('label', specs{k, 1}, 'path', [base '.csv']); %#ok<AGROW>
                if k > 1
                    w.line('Else');
                    w.line(['WriteStatus ' w.q(['UNAVAILABLE|' specs{k, 1} '|Khong co du lieu thuc o tan so yeu cau'])]);
                    w.line('End If');
                end
            end
        otherwise
            error('Vivaldi:Simulation', 'Thao tác mô phỏng không hỗ trợ: %s.', action);
    end
end

function ports(w)
    % Đường tích phân luôn outer-to-inner; không tái sử dụng Edge IDs từ source.
    w.lib(@hfssSetWCS, {'Global'});
    x = '-x_feed-positionx+slot_feed_w+h2';
    z = 'z_feed-h3_slot_feed-h_cabin';
    x2 = '(aperture_w+thickness)/2';
    y2 = '(aperture_w+thickness)/2+x_feed+positionx-slot_feed_w-h2';
    starts = {{[x '-r_cabmid'], '0mm', z}, {x2, [y2 '+r_cabmid'], z}};
    ends = {{[x '-r_cabin'], '0mm', z}, {x2, [y2 '+r_cabin'], z}};
    for k = 1:2
        text = w.capture(@hfssAssignLumpedPort, {num2str(k), ['port' num2str(k)], [0 0 0], [0 0 0], 'mm', 50, 0}, ...
                         {'Start', starts{k}; 'End', ends{k}});
        text = strrep(text, '"Resistance:="', '"Impedance:="');
        text = strrep(text, '"Impedance:=",', '"DoDeembed:=", False, "RenormalizeAllTerminals:=", True, "Impedance:=",');
        text = strrep(text, '"CharImp:=", "Zpi"', '"CharImp:=", "Zpi", "RenormImp:=", "50ohm"');
        text = regexprep(text, '(?m)^.*"Reactance:=".*\r?\n', '');
        w.call(text, ['Gán Lumped Port ' num2str(k)]);
    end
    w.call('Set oBoundary = oDesign.GetModule("BoundarySetup")', 'Đọc module cổng');
    w.require('ExactlyTwoPorts()', 'Không đọc được đúng hai Lumped Ports');
end

function setup(w, c, edit)
    % Dùng hfssInsertSolution thật; điều chỉnh mode edit và bổ sung flag nguồn bị thiếu.
    text = w.capture(@hfssInsertSolution, {'Setup1', c.adaptiveGHz, c.deltaS, c.maximumPasses, c.minimumPasses, min(3, c.maximumPasses), 10}, ...
                     {'Frequency', sprintf('%.17gGHz', c.adaptiveGHz); 'maxDeltaS', c.deltaS});
    text = strrep(text, '"maxDeltaS:="', '"MaxDeltaS:="');
    if edit
        text = strrep(text, 'oModule.InsertSetup "HfssDriven",', 'oModule.EditSetup "Setup1",');
    end
    text = strtrim(text);
    assert(text(end) == ')', 'Vivaldi:LibraryFormat', 'Mẫu setup thư viện không đúng.');
    extra = { 'BasisOrder:=', 1, 'UseABCOnPort:=', false, 'UseDomains:=', false, 'UseIterativeSolver:=', false, ...
             'SaveRadFieldsOnly:=', false, 'SaveAnyFields:=', true, 'IESolverType:=', 'Auto', 'LambdaTargetForIESolver:=', .15, ...
             'UseDefaultLambdaTgtForIESolver:=', true, 'IE Solver Accuracy:=', 'Balanced'};
    parts = cellfun(@VivaldiScriptWriter.literal, extra, 'UniformOutput', false);
    text = [text(1:end - 1), ', ' strjoin(parts, ', '), ')'];
    w.call(text, 'Cấu hình adaptive Setup1 theo mô hình nguồn');
end

function excite(w, c)
    a = {{'IncludePortPostProcessing:=', false, 'SpecifySystemPower:=', false}};
    for k = 1:2
        a{end + 1} = {'Name:=', sprintf('%d:1', k), 'Magnitude:=', sprintf('%.17gW', c.powerW(k)), 'Phase:=', sprintf('%.17gdeg', c.phaseDeg(k))};
    end %#ok<AGROW>
    w.call(['Set oSolutions = oDesign.GetModule("Solutions")' newline 'oSolutions.EditSources ' w.literal(a)], 'Đặt công suất và pha hai nguồn kích thích');
end

function out = nominal(extra)
    out = {};
    for n = fieldnames(vivaldiDefaultParams())'
        out = [out, {[n{1} ':='], {'Nominal'}}];
    end %#ok<AGROW>
    out = [out, extra];
end

function out = replaceFamily(out, name, value)
    k = find(strcmp(out, [name ':=']), 1);
    out{k + 1} = value;
end

function gate(w, category, context, families, expressions, field)
    w.call('Set oReport = oDesign.GetModule("ReportSetup")', 'Đọc module dữ liệu kết quả');
    w.require(dataCondition(w, category, context, families, expressions, field), 'Chưa có dữ liệu nghiệm thực ở nominal variation hiện tại');
end

function out = dataCondition(w, category, context, families, expressions, field)
    w.call('Set oReport = oDesign.GetModule("ReportSetup")', 'Đọc module báo cáo');
    out = ['HasRealData(' w.q(category) ',"Setup1 : Sweep",' w.literal(context) ',' w.literal(families) ',' w.literal(expressions) ',' sprintf('%.17g', field) ')'];
end
