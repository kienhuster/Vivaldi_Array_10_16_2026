function varargout = Vivaldi_Calculation(action, varargin)
% Mục đích: tập trung tham số, công thức và kiểm tra miền hình học của nguồn.
% Đơn vị mm/độ; không làm tròn hoặc ép kích thước vào các preset.
switch action
    case 'defaults'
        [varargout{1:nargout}] = vivaldiDefaultParams();
    case 'geometry'
        varargout{1} = vivaldiCalculateGeometry(varargin{1});
    case 'validate'
        [varargout{1:nargout}] = vivaldiValidateParams(varargin{1});
    case 'material_defaults'
        varargout{1} = defaultMaterials();
    case 'material_validate'
        varargout{1} = validateMaterial(varargin{1});
    case 'material_body'
        varargout{1} = bodyMaterial(varargin{1});
    case 'material_load'
        [varargout{1:nargout}] = loadMaterials(varargin{1});
    case 'material_save'
        varargout{1} = saveMaterial(varargin{1},varargin{2});
    case 'material_filter'
        database = varargin{1}; term = lower(strtrim(char(varargin{2})));
        varargout{1} = find(cellfun(@(name)~isempty(strfind(lower(name),term)) || isempty(term), {database.name})); %#ok<STREMP>
    otherwise
        error('Vivaldi:Calculation', 'Thao tác tính toán không được hỗ trợ.');
end
end

function [p, meta] = vivaldiDefaultParams()
    % Mục đích: khai báo 19 biến độc lập và metadata của mô hình ngày 17/10.
    % Đơn vị mm/độ; range chỉ là gợi ý, không giới hạn ô nhập numeric.
    p = struct('L_flare_1', 40, 'aperture_w', 20, 'slot_feed_w', 0.5, ...
               'deg_slot_t', 21, 'h3_slot_feed', 1, 'h2', 2.6, 'cavity_w', 1.4, ...
               'cavity_L', 5, 'h_de', 2, 'r_cabin', 0.15, 'positionx', 0.15, ...
               'r_cabmid', 0.35, 'r_cabout', 0.5, 'lamda', 60, 'scan_phi', 0, ...
               'scan_theta', 0, 'thickness', 2, 'them', 0, 'c2', 0);
    labels = {'Chiều dài flare chính', 'Độ mở miệng anten', 'Độ rộng khe feed', ...
              'Góc chuyển tiếp', 'Chiều dài khe feed', 'Đoạn ngang feed', 'Độ rộng cavity', ...
              'Chiều dài cavity', 'Độ dày đế', 'Bán kính lõi coax', 'Độ lệch tâm coax', ...
              'Bán kính trong ống coax', 'Bán kính ngoài coax', 'Lambda lưu trong nguồn', ...
              'Góc scan phi', 'Góc scan theta', 'Độ dày kim loại', 'Bù chiều dài chuyển tiếp', ...
              'c2 lưu trong nguồn'};
    groups = {'Flare & Aperture', 'Flare & Aperture', 'Slot & Transition', ...
              'Slot & Transition', 'Slot & Transition', 'Cavity & Feed', 'Cavity & Feed', ...
              'Cavity & Feed', 'Metal & Base', 'Coaxial Structure', 'Coaxial Structure', ...
              'Coaxial Structure', 'Coaxial Structure', 'Advanced Parameters', ...
              'Advanced Parameters', 'Advanced Parameters', 'Metal & Base', ...
              'Slot & Transition', 'Advanced Parameters'};
    ranges = [1 200; 1 100; .01 5; 0 89; .01 20; .01 30; .01 20; .01 50; ...
              .01 20; .005 2; -10 10; .01 3; .02 5; 1 1000; -180 180; -180 180; ...
              .01 20; -6.39 50; -100 100];
    tips = {'Thay đổi L_patch và các hệ tọa độ liên kết.', ...
            'Phải lớn hơn slot_feed_w; không suy ra đáp ứng RF chỉ từ aperture.', ...
            'Khe feed và chiều cao lõi coax phụ thuộc kích thước này.', ...
            'Góc theo độ, quay quanh slot_t_td; cần kiểm tra Boolean trong HFSS.', ...
            'Chiều dài theo Z trong Rectangle1 có normal Y.', ...
            'Tham gia vị trí ngang coax và cavity.', ...
            'Rectangle3 Height theo X; kiểm tra giao cắt khi thay đổi.', ...
            'Rectangle3 Width theo Z; không tự suy ra cộng hưởng.', ...
            'h_cabin=h_de+slot_feed_w; h_cabout=h_cabmid=h_de.', ...
            'Cần 0 < r_cabin < r_cabmid < r_cabout.', ...
            'Độ lệch trong slot_feed_td; có thể âm.', ...
            'Bán kính cutter giữa, không phải solid điện môi.', ...
            'Bán kính ống copper trước khoét.', ...
            'lamda=60mm trong nguồn; region sử dụng offset riêng 20mm.', ...
            'Biến nguồn; công cụ chỉ dựng một phần tử, không tạo mảng.', ...
            'Biến nguồn; công cụ chỉ dựng một phần tử, không tạo mảng.', ...
            'Thicken BothSides; độ dày tổng, không phải substrate.', ...
            'slot_t_L=6.4mm+them phải dương để dựng surface có diện tích.', ...
            'Giữ tương thích 31 biến nguồn; không gán thêm ý nghĩa vật lý.'};
    names = fieldnames(p);
    meta = struct('name', {}, 'label', {}, 'group', {}, 'unit', {}, 'range', {}, 'tip', {});
    for k = 1:numel(names)
        unit = 'mm';
        if ismember(names{k}, {'deg_slot_t', 'scan_phi', 'scan_theta'})
            unit = 'deg';
        end
        meta(k) = struct('name', names{k}, 'label', labels{k}, 'group', groups{k}, ...
                         'unit', unit, 'range', ranges(k, :), 'tip', tips{k});
    end
end


function g = vivaldiCalculateGeometry(p)
    % Mục đích: tính 12 biến dẫn xuất, biểu thức HFSS và biến đổi tọa độ nguồn.
    % Đầu vào p là 19 biến độc lập; đầu ra g có công thức và mẫu preview.
    % Giữ nguyên độ chính xác trung gian; các mẫu không chứng minh Boolean/tiếp xúc CAD.
    defaults = vivaldiDefaultParams();
    names = fieldnames(defaults);
    assert(isstruct(p) && isscalar(p), 'VivaldiBuilder:InvalidParameters', ...
           'Thông số phải là struct scalar.');
    assert(isequal(sort(fieldnames(p)), sort(names)), ...
           'VivaldiBuilder:InvalidParameters', 'Thông số phải có đúng 19 biến độc lập.');
    for k = 1:numel(names)
        v = p.(names{k});
        assert(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v), ...
               'VivaldiBuilder:InvalidParameters', '%s phải là số thực scalar hữu hạn.', names{k});
        p.(names{k}) = double(v);
    end
    assert(p.slot_feed_w > 0 && p.aperture_w > p.slot_feed_w && ...
           p.L_flare_1 > 0 && 6.4 + p.them > 0, 'VivaldiBuilder:InvalidParameters', ...
           'Cần chiều dài loe dương và aperture_w > slot_feed_w > 0.');
    g = struct();
    g.slot_t_L = 6.4 + p.them;
    g.L_flare = p.L_flare_1 + g.slot_t_L;
    g.r_flare = (1 / g.L_flare) * log(p.aperture_w / p.slot_feed_w);
    a = (p.slot_feed_w / 2) * exp(g.slot_t_L * g.r_flare);
    g.z_feed = (a + p.slot_feed_w / 2) * sind(p.deg_slot_t) ...
        + g.slot_t_L * (1 - cosd(p.deg_slot_t));
    g.x_feed = (a + p.slot_feed_w / 2) * cosd(p.deg_slot_t) ...
        + g.slot_t_L * sind(p.deg_slot_t) - a;
    g.L_patch = p.L_flare_1 + g.slot_t_L - g.z_feed + p.h3_slot_feed + p.slot_feed_w + p.h_de;
    g.h_cabin = p.h_de + p.slot_feed_w;
    g.h_cabout = g.h_cabin - p.slot_feed_w;
    g.h_cabmid = g.h_cabin - p.slot_feed_w;
    g.de_L = p.aperture_w + p.thickness;
    g.de_W = p.aperture_w + p.thickness;
    g.h_box = p.lamda / 2 + g.L_patch;
    g.z_base = g.L_flare - g.L_patch;
    g.aperture_w = p.aperture_w;
    g.coax_x = -g.x_feed - p.positionx + p.slot_feed_w + p.h2;
    g.coax_z = g.z_feed - p.h3_slot_feed;
    g.independentNames = names;
    g.independent = p;
    g.sourceDesign = 'dual_pol_vivaldi_patch_Wflare_20';
    g.verificationStatus = 'Chỉ công thức — chờ kiểm tra HFSS';
    % Giữ nguyên biểu thức dẫn xuất cho HFSS, gồm ln; không dùng eval trong MATLAB.
    g.expressions = { ...
                     'L_flare_1', literal(p.L_flare_1, 'mm'); ...
                     'slot_t_L', '6.4mm+them'; ...
                     'L_flare', 'L_flare_1+slot_t_L'; ...
                     'aperture_w', literal(p.aperture_w, 'mm'); ...
                     'slot_feed_w', literal(p.slot_feed_w, 'mm'); ...
                     'r_flare', '(1/L_flare)*ln(aperture_w/slot_feed_w)'; ...
                     'deg_slot_t', literal(p.deg_slot_t, 'deg'); ...
                     'z_feed', '((slot_feed_w/2)*exp((slot_t_L)*r_flare) +slot_feed_w/2)*sin(deg_slot_t)+slot_t_L*(1-cos(deg_slot_t))'; ...
                     'x_feed', '((slot_feed_w/2)*exp((slot_t_L)*r_flare) +slot_feed_w/2)*cos(deg_slot_t)+slot_t_L*(sin(deg_slot_t))-(slot_feed_w/2)*exp((slot_t_L)*r_flare)'; ...
                     'h3_slot_feed', literal(p.h3_slot_feed, 'mm'); ...
                     'h2', literal(p.h2, 'mm'); ...
                     'cavity_w', literal(p.cavity_w, 'mm'); ...
                     'cavity_L', literal(p.cavity_L, 'mm'); ...
                     'h_de', literal(p.h_de, 'mm'); ...
                     'L_patch', 'L_flare_1+slot_t_L-z_feed+h3_slot_feed+slot_feed_w+h_de'; ...
                     'r_cabin', literal(p.r_cabin, 'mm'); ...
                     'h_cabin', 'h_de+slot_feed_w'; ...
                     'positionx', literal(p.positionx, 'mm'); ...
                     'r_cabmid', literal(p.r_cabmid, 'mm'); ...
                     'h_cabout', 'h_cabin-slot_feed_w'; ...
                     'h_cabmid', 'h_cabin-slot_feed_w'; ...
                     'r_cabout', literal(p.r_cabout, 'mm'); ...
                     'de_L', 'aperture_w+thickness'; ...
                     'de_W', 'aperture_w+thickness'; ...
                     'lamda', literal(p.lamda, 'mm'); ...
                     'h_box', 'lamda/2+L_patch'; ...
                     'scan_phi', literal(p.scan_phi, 'deg'); ...
                     'scan_theta', literal(p.scan_theta, 'deg'); ...
                     'thickness', literal(p.thickness, 'mm'); ...
                     'them', literal(p.them, 'mm'); ...
                     'c2', literal(p.c2, 'mm')};
    g.postprocessingExpressions = {'alpha', '0deg'};
    g.cs.Global = coordinateSystem('', [0 0 0], [0 0 0], {'0mm', '0mm', '0mm'});
    g.cs.slot_t_td = coordinateSystem('Global', [a 0 g.slot_t_L], ...
                                      [a 0 g.slot_t_L], {'(slot_feed_w/2)*exp(slot_t_L*r_flare)', '0mm', 'slot_t_L'});
    g.cs.slot_feed_td = coordinateSystem('Global', [-g.x_feed 0 g.z_feed], ...
                                         [-g.x_feed 0 g.z_feed], {'-x_feed', '0mm', 'z_feed'});
    g.cs.patch_td = coordinateSystem('Global', [p.aperture_w / 2 0 g.L_flare], ...
                                     [p.aperture_w / 2 0 g.L_flare], {'aperture_w/2', '0mm', 'L_flare'});
    g.cs.RelativeCS1 = coordinateSystem('patch_td', [0 -p.thickness / 2 0], ...
                                        g.cs.patch_td.origin + [0 -p.thickness / 2 0], {'0mm', '-thickness/2', '0mm'});
    g.cs.RelativeCS1.globalOriginExpressions = {'aperture_w/2', '-thickness/2', 'L_flare'};
    g.transform = struct('axis', 'Z', 'angle', -90, 'pivot', g.cs.RelativeCS1.origin, ...
                         'move', [0 p.thickness 0], 'rotation', [0 1 0; -1 0 0; 0 0 1]);
    g.flare = sampleFlare(p, g, unique(sort([linspace(0, g.L_flare, 401), g.slot_t_L])));
    g.mainFlare = sampleFlare(p, g, linspace(g.slot_t_L, g.L_flare, 401));
    g.transition = sampleFlare(p, g, linspace(0, g.slot_t_L, 161));
    g.transition.unrotatedLeft = g.transition.left;
    g.transition.unrotatedRight = g.transition.right;
    Ry = [cosd(p.deg_slot_t) 0 sind(p.deg_slot_t); 0 1 0; ...
          -sind(p.deg_slot_t) 0 cosd(p.deg_slot_t)];
    g.transition.left = rotatePoints(g.transition.left, g.cs.slot_t_td.origin, Ry, [0 0 0]);
    g.transition.right = rotatePoints(g.transition.right, g.cs.slot_t_td.origin, Ry, [0 0 0]);
    g.u = g.flare.u;
    g.flareHalfWidth = g.flare.halfWidth;
    rects = [0 0 -p.h3_slot_feed p.slot_feed_w; ...
             0 -p.h3_slot_feed -p.slot_feed_w p.slot_feed_w + p.h2 + p.cavity_w; ...
             p.slot_feed_w + p.h2 -p.h3_slot_feed - p.slot_feed_w p.cavity_L p.cavity_w];
    for k = 1:3
        x = rects(k, 1);
        z = rects(k, 2);
        width = rects(k, 3);
        height = rects(k, 4);
        corners = [x 0 z; x + height 0 z; x + height 0 z + width; x 0 z + width];
        g.slotRectangles(k) = struct('name', sprintf('Rectangle%d', k), ...
                                     'cs', 'slot_feed_td', 'localCorners', corners, ...
                                     'corners', bsxfun(@plus, corners, g.cs.slot_feed_td.origin));
    end
    A = p.aperture_w / 2;
    t = p.thickness;
    corners = [A 0 g.L_flare; -A 0 g.L_flare; -A 0 g.z_base; A 0 g.z_base];
    g.plates(1) = struct('name', 'Vivaldi_1', 'corners', corners, 'normal', [0 1 0], 'thickness', t);
    g.plates(2) = struct('name', 'Vivaldi_2', 'corners', dual(corners, g), ...
                         'normal', [1 0 0], 'thickness', t);
    g.connector = struct('position', g.cs.RelativeCS1.origin, 'size', [t t -g.L_patch]);
    g.connector.corners = boxCorners(g.connector.position, g.connector.size);
    g.base = struct('position', [(g.de_L + t) / 2 -(g.de_W - p.aperture_w) / 2 ...
                                 g.z_feed - p.h3_slot_feed - p.slot_feed_w], 'size', [-g.de_L g.de_W -p.h_de]);
    g.base.corners = boxCorners(g.base.position, g.base.size);
    g.bounds.plate1 = [-A A; -t / 2 t / 2; g.z_base g.L_flare];
    g.bounds.plate2 = [A A + t; t / 2 p.aperture_w + t / 2; g.z_base g.L_flare];
    g.bounds.base = [min(g.base.corners, [], 1)' max(g.base.corners, [], 1)'];
    g.bounds.body = [-A A + t; -t / 2 p.aperture_w + t / 2; g.z_base g.L_flare];
    g.bounds.region = g.bounds.body + repmat([-20 20], 3, 1);
    g.bounds.description = 'Bao danh nghĩa trước khi khoét; không phải kích thước đo trong HFSS.';
    c = [g.coax_x 0 g.coax_z];
    g.cables(1) = struct('innerStart', c, 'innerEnd', c - [0 0 g.h_cabin], ...
                         'outerStart', c - [0 0 p.slot_feed_w], ...
                         'outerEnd', c - [0 0 p.slot_feed_w + g.h_cabout], ...
                         'centerXY', c(1:2), 'innerRadius', p.r_cabin, ...
                         'midRadius', p.r_cabmid, 'outerRadius', p.r_cabout);
    g.cables(2) = g.cables(1);
    pointFields = {'innerStart', 'innerEnd', 'outerStart', 'outerEnd'};
    for k = 1:numel(pointFields)
        name = pointFields{k};
        g.cables(2).(name) = dual(g.cables(1).(name), g);
    end
    g.cables(2).centerXY = g.cables(2).innerStart(1:2);
    center = g.cables(1).innerEnd;
    g.ports(1) = struct('name', 'port1', 'boundary', '1', 'center', center, ...
                        'start', center + [-p.r_cabmid 0 0], 'end', center + [-p.r_cabin 0 0], ...
                        'radius', p.r_cabmid, 'impedance', 50, 'normal', [0 0 1]);
    g.ports(2) = g.ports(1);
    g.ports(2).name = 'port2';
    g.ports(2).boundary = '2';
    for name = {'center', 'start', 'end'}
        g.ports(2).(name{1}) = dual(g.ports(1).(name{1}), g);
    end
    g.portLineStatus = 'Đường tích phân ngoài vào trong; góc phương vị tái dựng, chờ so pha HFSS.';
end

function s = literal(v, unit)
    s = [sprintf('%.17g', v) unit];
end

function c = coordinateSystem(parent, localOrigin, origin, expressions)
    c = struct('parent', parent, 'localOrigin', localOrigin, 'origin', origin, ...
               'xAxis', [1 0 0], 'yAxis', [0 1 0], 'zAxis', [0 0 1], ...
               'originExpressions', {expressions}, 'globalOriginExpressions', {expressions});
end

function s = sampleFlare(p, g, u)
    u = u(:);
    w = (p.slot_feed_w / 2) * exp(u * g.r_flare);
    s = struct('u', u, 'halfWidth', w, 'left', [-w zeros(size(u)) u], ...
               'right', [w zeros(size(u)) u]);
end

function result = rotatePoints(points, pivot, rotation, move)
    result = bsxfun(@plus, bsxfun(@minus, points, pivot) * rotation', pivot + move);
end

function points = dual(points, g)
    points = rotatePoints(points, g.transform.pivot, g.transform.rotation, g.transform.move);
end

function corners = boxCorners(position, sizeVector)
    [x, y, z] = ndgrid([0 sizeVector(1)], [0 sizeVector(2)], [0 sizeVector(3)]);
    corners = bsxfun(@plus, [x(:) y(:) z(:)], position);
end


function [ok, errors, warnings, g] = vivaldiValidateParams(p)
    % Mục đích: kiểm tra miền số và ràng buộc đại số trước khi gửi sang HFSS.
    % Đầu ra ok/errors/warnings/g; kết quả hợp lệ không phải chứng nhận CAD/RF.
    errors = {};
    warnings = {};
    g = struct();
    ok = false;
    defaults = vivaldiDefaultParams();
    names = fieldnames(defaults);
    if ~isstruct(p) || ~isscalar(p)
        errors = {'Cấu hình phải là một struct scalar.'};
        return
    end
    extra = setdiff(fieldnames(p), names);
    if ~isempty(extra)
        errors{end + 1} = ['Biến không hỗ trợ: ' strjoin(extra, ', ') '.'];
    end
    signed = {'them', 'positionx', 'deg_slot_t', 'scan_phi', 'scan_theta', 'c2'};
    for k = 1:numel(names)
        n = names{k};
        if ~isfield(p, n) || ~isnumeric(p.(n)) || ~isscalar(p.(n)) ...
                || ~isreal(p.(n)) || ~isfinite(p.(n))
            errors{end + 1} = [n ': cần số thực hữu hạn scalar.']; %#ok<AGROW>
        elseif ~ismember(n, signed) && p.(n) <= 0
            errors{end + 1} = [n ': phải dương.']; %#ok<AGROW>
        else
            p.(n) = double(p.(n));
        end
    end
    if ~isempty(errors)
        return
    end
    if p.aperture_w <= p.slot_feed_w
        errors{end + 1} = 'aperture_w phải lớn hơn slot_feed_w.';
    end
    if 6.4 + p.them <= 0
        errors{end + 1} = 'slot_t_L=6.4mm+them phải dương; surface dài bằng 0 không được dựng.';
    end
    if ~(p.r_cabin < p.r_cabmid && p.r_cabmid < p.r_cabout)
        errors{end + 1} = 'Cần 0 < r_cabin < r_cabmid < r_cabout.';
    end
    if ~isempty(errors)
        return
    end
    try
        g = vivaldiCalculateGeometry(p);
    catch ex
        errors{end + 1} = ['Không tính được hình học: ' ex.message];
        return
    end
    values = [g.slot_t_L g.L_flare g.r_flare g.z_feed g.x_feed g.L_patch ...
              g.h_cabin g.h_cabout g.h_cabmid g.de_L g.de_W g.h_box ...
              g.flareHalfWidth(:)' g.transition.left(:)' g.transition.right(:)' ...
              g.bounds.body(:)' g.ports(1).start g.ports(1).end ...
              g.ports(2).start g.ports(2).end];
    if ~isreal(values) || any(~isfinite(values)) || ...
            any([g.L_flare g.L_patch g.h_cabin g.h_cabout g.h_box] <= 0)
        errors{end + 1} = 'Hình học dẫn xuất không hữu hạn hoặc kích thước không dương.';
    end
    if g.z_feed >= g.L_flare
        errors{end + 1} = 'z_feed nằm ngoài chiều dài flare; tấm không có đoạn loe hợp lệ.';
    end
    for k = 1:3
        q = g.slotRectangles(k).corners;
        if min(q(:, 1)) < -p.aperture_w / 2 || max(q(:, 1)) > p.aperture_w / 2 ...
                || min(q(:, 3)) < g.z_base || max(q(:, 3)) >= g.L_flare
            errors{end + 1} = [g.slotRectangles(k).name ': khe/cavity vượt biên tấm, làm mở topology ngoài ý muốn.'];
        end
    end
    if 2 * p.r_cabout > p.thickness
        warnings{end + 1} = 'Đường kính coax lớn hơn chiều dày kim loại; cần kiểm tra tiếp xúc trong HFSS.';
    end
    if abs(g.coax_x) + p.r_cabout > p.aperture_w / 2
        warnings{end + 1} = 'Coax thứ nhất vượt bao aperture danh nghĩa; cần kiểm tra vị trí và tiếp xúc.';
    end
    if abs(p.positionx) > p.h2 + p.slot_feed_w
        warnings{end + 1} = 'positionx lớn so với vùng feed; hình học coax có thể tách khỏi feed.';
    end
    if any(cellfun(@(n)p.(n) ~= defaults.(n), names))
        warnings{end + 1} = 'Tham số khác nguồn chuẩn: phải kiểm tra lại Boolean, port, region và mô phỏng.';
    end
    warnings{end + 1} = ['Kiểm tra đại số không chứng minh tiếp xúc CAD, topology hoặc hiệu năng RF. ' ...
                         'Chờ kiểm tra thực tế bằng HFSS.'];
    ok = isempty(errors);
end

function database = defaultMaterials()
% Mục đích: giữ danh sách điện môi của mẫu và thông số kim loại đúng nguồn 17/10.
spec = {'FR4_epoxy',4.4,.0200; 'Rogers RO4350 (tm)',3.48,.0037; ...
    'Rogers RT/duroid 5880 (tm)',2.2,.0009; 'Arlon AD250',2.5,.0018; ...
    'Taconic TLC-30',3,.0030; 'Teflon (PTFE)',2.1,.0002; 'Glass',5.5,0; 'Vacuum',1,0};
database = repmat(materialRecord('', 'dielectric', 1, 0, 0, 1), 0, 1);
for k = 1:size(spec,1)
    database(end+1) = materialRecord(spec{k,1}, 'dielectric', spec{k,2}, spec{k,3}, 0, 1); %#ok<AGROW>
end
database(end+1) = materialRecord('Aluminum', 'metal', 1, 0, 38000000, 1.000021);
database(end+1) = materialRecord('Copper', 'metal', 1, 0, 58000000, .999991);
database(end+1) = materialRecord('PEC', 'pec', [], [], [], []);
end

function material = materialRecord(name, kind, epsilon, loss, conductivity, permeability)
% Mục đích: một schema nhỏ dùng chung giữa GUI, dữ liệu MAT và Builder.
material = struct('name', name, 'kind', kind, 'permittivity', epsilon, ...
    'lossTangent', loss, 'conductivity', conductivity, 'permeability', permeability);
end

function material = validateMaterial(material)
% Mục đích: kiểm tra dữ liệu vật liệu; PEC không giả lập bằng conductivity hữu hạn.
fields = {'name','kind','permittivity','lossTangent','conductivity','permeability'};
assert(isstruct(material) && isscalar(material) && isequal(sort(fieldnames(material)), sort(fields')), ...
    'Vivaldi:Material', 'Vật liệu phải có đúng tên, loại và bốn thông số điện từ.');
assert(ischar(material.name) && isrow(material.name), 'Vivaldi:Material', 'Tên vật liệu phải là chuỗi một dòng.');
material.name = strtrim(material.name);
assert(~isempty(material.name) && isempty(regexp(material.name, '[\x00-\x1F"\\:*?<>|,;]', 'once')), ...
    'Vivaldi:Material', 'Tên vật liệu rỗng hoặc có ký tự không hợp lệ.');
assert(ischar(material.kind) && ismember(material.kind, {'metal','dielectric','pec'}), ...
    'Vivaldi:Material', 'Loại vật liệu không hợp lệ.');
if strcmp(material.kind, 'pec')
    assert(strcmpi(material.name,'PEC'), 'Vivaldi:Material', 'Vật dẫn lý tưởng dùng định nghĩa PEC tích hợp của HFSS.');
    for k = 3:numel(fields)
        assert(isnumeric(material.(fields{k})) && isempty(material.(fields{k})), ...
            'Vivaldi:Material', 'PEC không khai báo thông số vật liệu hữu hạn giả tạo.');
    end
else
    for k = 3:numel(fields)
        value = material.(fields{k});
        assert(isnumeric(value) && isscalar(value) && isreal(value) && isfinite(value), ...
            'Vivaldi:Material', 'Thông số %s phải là số thực hữu hạn.', fields{k});
    end
    assert(material.permittivity>0 && material.permeability>0 && material.lossTangent>=0 && material.conductivity>=0, ...
        'Vivaldi:Material', 'Cần epsilon/mu dương, loss tangent và conductivity không âm.');
    if strcmp(material.kind,'metal')
        assert(material.conductivity>0, 'Vivaldi:Material', 'Kim loại cần conductivity dương.');
    end
end
material = materialRecord(material.name, material.kind, material.permittivity, material.lossTangent, material.conductivity, material.permeability);
end

function body = bodyMaterial(material)
% Mục đích: điện môi trong thư viện không được áp sai lên thân anten kim loại.
body = validateMaterial(material);
assert(ismember(body.kind, {'metal','pec'}), 'Vivaldi:MaterialBody', ...
    'Thân anten này chỉ nhận kim loại hoặc PEC. Thiết kế nguồn không có substrate điện môi để gán %s.', body.name);
end

function [database, message] = loadMaterials(file)
% Mục đích: gộp mặc định và custom; cấu hình lỗi được báo, không bị xóa/ghi đè.
database = defaultMaterials(); message = '';
if ~isfile(file), return; end
try
    data = load(file, 'schemaVersion', 'customMaterials');
    assert(isfield(data,'schemaVersion') && isequal(data.schemaVersion,1) && isfield(data,'customMaterials') && isstruct(data.customMaterials), ...
        'Vivaldi:MaterialConfig', 'Schema file vật liệu không hợp lệ.');
    for k = 1:numel(data.customMaterials)
        candidate = validateMaterial(data.customMaterials(k));
        assert(~any(strcmpi({database.name},candidate.name)), 'Vivaldi:MaterialDuplicate', 'Trùng tên vật liệu %s.', candidate.name);
        database(end+1) = candidate; %#ok<AGROW>
    end
catch err
    database = defaultMaterials();
    message = sprintf('Không đọc được cấu hình vật liệu %s: %s. File được giữ nguyên; chưa cho ghi đè.',file,err.message);
end
end

function database = saveMaterial(file, candidate)
% Mục đích: thêm một vật liệu, lưu MAT riêng có backup; không đụng nguồn/reference.
candidate = validateMaterial(candidate);
[database, message] = loadMaterials(file);
assert(isempty(message), 'Vivaldi:MaterialConfig', '%s', message);
assert(~any(strcmpi({database.name},candidate.name)), 'Vivaldi:MaterialDuplicate', 'Vật liệu %s đã tồn tại, kể cả khác hoa/thường.',candidate.name);
[folder,~,extension] = fileparts(file);
assert(strcmpi(extension,'.mat') && ~isempty(folder), 'Vivaldi:MaterialConfig', 'Cấu hình phải là đường dẫn file MAT riêng.');
if ~isfolder(folder), [ok,msg]=mkdir(folder); assert(ok,'Vivaldi:MaterialConfig','%s',msg); end
count = numel(defaultMaterials()); database(end+1) = candidate;
customMaterials = database(count+1:end); schemaVersion = 1; %#ok<NASGU>
temporary = [tempname(folder) '.mat'];
cleanup = onCleanup(@()removeMaterialTemp(temporary)); %#ok<NASGU>
save(temporary, 'customMaterials', 'schemaVersion', '-v7');
if isfile(file)
    [ok,msg] = copyfile(file,[file '.bak'],'f'); assert(ok,'Vivaldi:MaterialConfig','Không sao lưu được: %s',msg);
end
[ok,msg] = movefile(temporary,file,'f'); assert(ok,'Vivaldi:MaterialConfig','Không lưu được: %s',msg);
end

function removeMaterialTemp(file)
% Mục đích: dọn tệp tạm khi lưu lỗi, giữ nguyên file cấu hình cũ và bản backup.
if isfile(file), delete(file); end
end
