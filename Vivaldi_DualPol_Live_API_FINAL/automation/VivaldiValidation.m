function out = VivaldiValidation(action, varargin)
    % Mục đích: sinh kiểm tra runtime CAD/biến; kết quả chỉ PASS khi HFSS chạy thật.
    % Kiểm tra công thức MATLAB và probe CAD có phạm vi bằng chứng riêng biệt.
    out = [];
    switch action
        case 'variables'
            w = varargin{1};
            p = varargin{2};
            g = vivaldiCalculateGeometry(p);
            [~, meta] = vivaldiDefaultParams();
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
        case 'parameters'
            w = varargin{1};
            names = fieldnames(vivaldiDefaultParams());
            for k = 1:numel(names)
                w.call(['WriteStatus "PARAM|' names{k} '|" & CStr(oDesign.GetVariableValue(' w.q(names{k}) '))'], ['Đọc lại ' names{k}]);
            end
        case 'flare'
            w = varargin{1};
            p = varargin{2};
            name = varargin{3};
            pol = varargin{4};
            solid = varargin{5};
            g = vivaldiCalculateGeometry(p);
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
            g = vivaldiCalculateGeometry(p);
            for pol = 1:(1 + logical(both))
                for k = 1:3
                    probe(w, g, pol, 'Vivaldi_1', mean(g.slotRectangles(k).corners, 1), false, 'Khe/cavity phải rỗng');
                end
            end
        case 'coax'
            w = varargin{1};
            p = varargin{2};
            g = vivaldiCalculateGeometry(p);
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
            w.require('MaterialMatches("Vivaldi_1","aluminum",False)', 'Thân phải là aluminum, SolveInside=false');
        case 'full'
            w = varargin{1};
            p = varargin{2};
            solver = varargin{3};
            g = vivaldiCalculateGeometry(p);
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
