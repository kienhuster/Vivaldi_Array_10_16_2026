function [handles, info] = vivaldiPreview3D(ax, p, g, options)
    % Mục đích: xem trước hai tấm từ công thức, transition, khe, cavity và coax.
    % Dùng polyshape lấy mẫu và phép trừ 2D; không thay thế CAD HFSS đã kiểm chứng.
    if nargin < 3 || isempty(g)
        g = vivaldiCalculateGeometry(p);
    end
    if nargin < 4
        options = struct();
    end
    options = defaults(options, struct('view', '3D', 'dimensions', false, ...
                                       'coax', true, 'coordinates', false));
    cla(ax);
    hold(ax, 'on');
    handles = gobjects(0);
    info = struct('kind', 'Xem trước theo công thức', 'cadValidated', false, ...
                  'description', ['Xem trước lấy mẫu: đoạn chuyển tiếp xoay, khe và cavity; ' ...
                                  'không phải CAD xuất từ HFSS hoặc kiểm chứng Boolean/tiếp xúc.']);
    corners = g.plates(1).corners;
    metal = polyshape(corners(:, 1), corners(:, 3), 'Simplify', true);
    if isfield(g, 'mainFlare')
        f = g.mainFlare;
    else
        keep = g.flare.u >= g.slot_t_L;
        f = struct('left', g.flare.left(keep, :), 'right', g.flare.right(keep, :));
    end
    cut = surfacePolygon(f);
    cut = union(cut, surfacePolygon(g.transition));
    for k = 1:numel(g.slotRectangles)
        q = g.slotRectangles(k).corners;
        cut = union(cut, polyshape(q(:, 1), q(:, 3), 'Simplify', true));
    end
    metal = subtract(metal, cut);
    for pol = 1:2
        handles = [handles; slab(metal, p.thickness, pol)]; %#ok<AGROW>
    end
    o = g.cs.RelativeCS1.origin;
    boxBounds = [o(:), o(:) + [p.thickness; p.thickness; -g.L_patch]];
    handles(end + 1) = box(min(boxBounds, [], 2), max(boxBounds, [], 2), [.55 .61 .68], .94);
    baseStart = [(g.de_L + p.thickness) / 2; -(g.de_W - p.aperture_w) / 2; ...
                 g.z_feed - p.h3_slot_feed - p.slot_feed_w];
    baseEnd = baseStart + [-g.de_L; g.de_W; -p.h_de];
    handles(end + 1) = box(min(baseStart, baseEnd), max(baseStart, baseEnd), [.43 .49 .57], .94);
    if options.coax
        for k = 1:2
            c = g.cables(k);
            drawCylinder(c.innerStart, c.innerEnd, p.r_cabin, [.9 .49 .19], 1);
            drawCylinder(c.outerStart, c.outerEnd, p.r_cabout, [.77 .38 .13], .78);
            drawCylinder(c.outerStart, c.outerEnd, p.r_cabmid, [.65 .29 .1], .35);
            annulus(c.outerEnd, p.r_cabmid, p.r_cabout);
            annulus(c.outerStart, p.r_cabmid, p.r_cabout);
            port = g.ports(k);
            a = linspace(0, 2 * pi, 81);
            plot3(ax, port.center(1) + port.radius * cos(a), ...
                  port.center(2) + port.radius * sin(a), ...
                  repmat(port.center(3), size(a)), 'm-', 'LineWidth', 1.3);
            plot3(ax, [port.start(1) port.end(1)], [port.start(2) port.end(2)], ...
                  [port.start(3) port.end(3)], 'm-', 'LineWidth', 2);
            text(ax, port.center(1), port.center(2), port.center(3) - .7, ...
                 sprintf('Cổng %d', k), 'Color', [.6 0 .6], 'FontSize', 9);
        end
    end
    if options.coordinates
        names = fieldnames(g.cs);
        colors = [.85 .15 .15; .15 .6 .2; .15 .3 .85];
        len = max(2, p.aperture_w * .12);
        for k = 1:numel(names)
            cs = g.cs.(names{k});
            origin = cs.origin;
            vectors = [cs.xAxis(:), cs.yAxis(:), cs.zAxis(:)];
            for j = 1:3
                v = vectors(:, j) * len;
                quiver3(ax, origin(1), origin(2), origin(3), v(1), v(2), v(3), 0, ...
                        'Color', colors(j, :), 'LineWidth', 1.2, 'MaxHeadSize', .35);
            end
            text(ax, origin(1), origin(2), origin(3), [' ' names{k}], ...
                 'Interpreter', 'none', 'FontSize', 8, 'Color', [.2 .2 .2]);
        end
    end
    if options.dimensions
        b = g.bounds.body;
        x = b(1, 1) - 3;
        y = b(2, 1) - 3;
        plot3(ax, [x x], [y y], b(3, :), 'k-', 'LineWidth', 1);
        text(ax, x, y, mean(b(3, :)), sprintf(' L_{patch}=%.5f mm', g.L_patch), 'FontSize', 10);
        plot3(ax, b(1, :), [y y], [b(3, 2) + 2 b(3, 2) + 2], 'k-');
        text(ax, mean(b(1, :)), y, b(3, 2) + 2, sprintf(' %.3g mm', diff(b(1, :))), 'FontSize', 10);
    end
    axis(ax, 'equal');
    grid(ax, 'on');
    xlabel(ax, 'X (mm)');
    ylabel(ax, 'Y (mm)');
    zlabel(ax, 'Z (mm)');
    switch lower(options.view)
        case {'front', 'front view'}
            view(ax, 0, 0);
        case {'side', 'side view'}
            view(ax, 90, 0);
        case {'top', 'top view'}
            view(ax, 0, 90);
        otherwise
            view(ax, 38, 25);
    end
    title(ax, {'XEM TRƯỚC THEO CÔNG THỨC — CHƯA KIỂM CHỨNG CAD HFSS', ...
               sprintf('Một phần tử hai phân cực | L_{patch}=%.6f mm', g.L_patch)}, 'FontSize', 11);
    hold(ax, 'off');

    function h = slab(shape, thickness, polarization)
        mesh = triangulation(shape);
        points = mesh.Points;
        triangles = mesh.ConnectivityList;
        h = gobjects(0);
        color = [.72 .77 .82];
        if polarization == 2
            color = [.54 .68 .81];
        end
        for yy = [-thickness / 2 thickness / 2]
            vertices = [points(:, 1), repmat(yy, size(points, 1), 1), points(:, 2)];
            vertices = transform(vertices, polarization);
            h(end + 1, 1) = patch(ax, 'Faces', triangles, 'Vertices', vertices, ...
                                  'FaceColor', color, 'EdgeColor', 'none', 'FaceAlpha', .93); %#ok<AGROW>
        end
        [xx, zz] = boundary(shape);
        xx = xx(:);
        zz = zz(:);
        edges = find(isfinite(xx(1:end - 1)) & isfinite(xx(2:end)) & ...
                     isfinite(zz(1:end - 1)) & isfinite(zz(2:end)));
        count = numel(edges);
        vertices = zeros(4 * count, 3);
        vertices(1:4:end, :) = [xx(edges), repmat(-thickness / 2, count, 1), zz(edges)];
        vertices(2:4:end, :) = [xx(edges + 1), repmat(-thickness / 2, count, 1), zz(edges + 1)];
        vertices(3:4:end, :) = [xx(edges + 1), repmat(thickness / 2, count, 1), zz(edges + 1)];
        vertices(4:4:end, :) = [xx(edges), repmat(thickness / 2, count, 1), zz(edges)];
        h(end + 1, 1) = patch(ax, 'Faces', reshape(1:4 * count, 4, count)', ...
                              'Vertices', transform(vertices, polarization), 'FaceColor', color * .83, 'EdgeColor', 'none');
    end

    function q = transform(q, polarization)
        if polarization ~= 2
            return
        end
        c = g.cs.RelativeCS1.origin;
        q = [c(1) + q(:, 2) - c(2), c(2) - q(:, 1) + c(1) + p.thickness, q(:, 3)];
    end

    function h = box(lo, hi, color, alpha)
        v = [lo(1) lo(2) lo(3); hi(1) lo(2) lo(3); hi(1) hi(2) lo(3); lo(1) hi(2) lo(3); ...
             lo(1) lo(2) hi(3); hi(1) lo(2) hi(3); hi(1) hi(2) hi(3); lo(1) hi(2) hi(3)];
        h = patch(ax, 'Faces', [1 2 3 4; 5 6 7 8; 1 2 6 5; 2 3 7 6; 3 4 8 7; 4 1 5 8], ...
                  'Vertices', v, 'FaceColor', color, 'FaceAlpha', alpha, 'EdgeColor', [.3 .35 .4]);
    end

    function drawCylinder(a, b, r, color, alpha)
        [xx, yy, zz] = cylinder(r, 40);
        zz = a(3) + (b(3) - a(3)) * zz;
        surf(ax, xx + a(1), yy + a(2), zz, 'FaceColor', color, 'FaceAlpha', alpha, 'EdgeColor', 'none');
    end

    function annulus(c, ri, ro)
        a = linspace(0, 2 * pi, 81);
        xx = [ri * cos(a); ro * cos(a)] + c(1);
        yy = [ri * sin(a); ro * sin(a)] + c(2);
        surf(ax, xx, yy, repmat(c(3), size(xx)), 'FaceColor', [.8 .43 .16], 'EdgeColor', 'none');
    end

end

function shape = surfacePolygon(surface)
    q = [surface.left; flipud(surface.right)];
    shape = polyshape(q(:, 1), q(:, 3), 'Simplify', true);
end

function options = defaults(options, values)
    names = fieldnames(values);
    for k = 1:numel(names)
        if ~isfield(options, names{k})
            options.(names{k}) = values.(names{k});
        end
    end
end
