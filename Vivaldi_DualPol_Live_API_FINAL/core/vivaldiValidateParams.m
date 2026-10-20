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
