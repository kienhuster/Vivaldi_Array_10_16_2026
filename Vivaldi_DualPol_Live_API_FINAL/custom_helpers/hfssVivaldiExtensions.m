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
            w.lib(@hfssAssignMaterial, {varargin{1}, varargin{2}, false}, {'SolveInside', false});
        case 'variables'
            p = varargin{1};
            create = varargin{2};
            names = varargin{3};
            g = vivaldiCalculateGeometry(p);
            if create
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
            else
                % Update chỉ gọi helper cho các biến thật sự thay đổi; giữ 17 chữ số.
                [~, meta] = vivaldiDefaultParams();
                for k = 1:numel(names)
                    n = names{k};
                    unit = meta(strcmp({meta.name}, n)).unit;
                    w.lib(@hfssVariableChange, {n, p.(n), unit}, {'Value', [sprintf('%.17g', p.(n)) unit]});
                end
            end
        case 'sweep'
            c = varargin{1};
            edit = varargin{2};
            a = {'NAME:Sweep', 'IsEnabled:=', true, 'RangeType:=', 'LinearStep', ...
                 'RangeStart:=', sprintf('%.17gGHz', c.startGHz), 'RangeEnd:=', sprintf('%.17gGHz', c.stopGHz), ...
                 'RangeStep:=', sprintf('%.17gGHz', c.stepGHz), 'Type:=', 'Discrete', 'SaveFields:=', true, 'SaveRadFields:=', true};
            if edit
                method = 'EditFrequencySweep "Setup1", "Sweep", ';
            else
                method = 'InsertFrequencySweep "Setup1", ';
            end
            w.call(['Set oModule = oDesign.GetModule("AnalysisSetup")' newline 'oModule.' method w.literal(a)], 'Tạo/cập nhật sweep tần số Discrete');
        otherwise
            error('Vivaldi:Extension', 'Phép mở rộng chưa hỗ trợ: %s.', action);
    end
end

function out = attributes(w, name, material, inside)
    % Mặt loe dùng vacuum; hướng vật liệu Global theo nguồn, WCS điều khiển phép dựng.
    out = w.literal({'NAME:Attributes', 'Name:=', name, 'Flags:=', '', 'PartCoordinateSystem:=', 'Global', ...
                     'MaterialValue:=', ['"' material '"'], 'SolveInside:=', inside});
end
