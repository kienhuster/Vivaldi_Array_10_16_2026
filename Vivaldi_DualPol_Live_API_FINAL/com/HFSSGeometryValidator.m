classdef HFSSGeometryValidator
    % Real topology probes, area/volume/position checks. Unsupported is NOT PASS.
    methods (Static)

        function report = run(s, p, withSolver)
            if nargin < 3
                withSolver = true;
            end
            report = struct('status', 'PENDING', 'message', '', 'checks', {{}}, 'time', datestr(now, 30));
            try
                HFSSCAD.wcs(s, 'Global');
                units = char(s.call(s.Editor, 'GetModelUnits'));
                assert(strcmpi(units, 'mm'), 'Vivaldi:Units', 'Model units phải là mm.');
                HFSSVariableManager.verify(s, p);
                expected = {'Vivaldi_1', 'cable_in', 'cable_out', 'cable_in_1', 'cable_out_1', 'port1', 'port2'};
                if withSolver
                    expected{end + 1} = 'RadiatingSurface';
                end
                HFSSCAD.requireNames(s, expected, true);
                HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 1, true);
                HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 2, true);
                HFSSGeometryValidator.assertCavity(s, p, true);
                HFSSGeometryValidator.assertCoax(s, p);
                g = vivaldiCalculateGeometry(p);
                measured = HFSSCAD.bounds(s, 'Vivaldi_1');
                assert(max(abs(measured(:) - g.bounds.body(:))) < 1e-5, ...
                       'Vivaldi:Bounds', 'Measured body bounds khác công thức nguồn.');
                if withSolver
                    boundary = s.module('BoundarySetup');
                    ex = HFSSCOMConnection.list(s.call(boundary, 'GetExcitations'));
                    assert(numel(ex) == 4 && all(ismember({'1', '2', 'Lumped Port'}, ex)), ...
                           'Vivaldi:Ports', 'Phải có đúng 2 Lumped Ports 1 và 2.');
                    b = HFSSCOMConnection.list(s.call(boundary, 'GetBoundaries'));
                    assert(all(ismember({'Open1', 'Radiation'}, b)), 'Vivaldi:Radiation', 'Thiếu Open1 Radiation.');
                    rc = s.call(s.Design, 'ValidateDesign');
                    assert(isnumeric(rc) && isscalar(rc) && rc == 1, 'Vivaldi:HFSSValidation', 'ValidateDesign không trả success code 1.');
                end
                report.status = 'PASS';
                report.message = 'Measured flare void/metal samples, thickness, cavity, coax, ports and inventory checks passed.';
                report.checks = {'variables', 'inventory', 'flare1', 'flare2', 'thickness', 'cavity', 'coax volume', 'port area/center', 'body bounds'};
                if withSolver
                    report.checks{end + 1} = 'ValidateDesign success code 1';
                end
            catch ex
                report.status = 'FAIL';
                report.message = [ex.identifier ': ' ex.message];
            end
            s.Diagnostics.record('GEOMETRY_VALIDATION', report.status, {}, report.message);
        end

        function assertFlare(s, p, name, pol, solid)
            HFSSCAD.wcs(s, 'Global');
            g = vivaldiCalculateGeometry(p);
            A = p.aperture_w / 2;
            low = max([g.slot_t_L, max(g.slotRectangles(3).corners(:, 3))]) + 1e-4 * max(1, g.L_flare);
            assert(low < g.L_flare, 'Vivaldi:ProbeDomain', 'Không còn miền flare tách khỏi transition/cavity.');
            z = unique([low + (g.L_flare - low) * [.2 .5 .8], [10 25 40]]);
            z = z(z > low & z < g.L_flare - 1e-4);
            assert(numel(z) >= 3, 'Vivaldi:ProbeDomain', 'Cần ít nhất 3 mặt cắt flare hợp lệ.');
            for height = z
                half = (p.slot_feed_w / 2) * exp(height * g.r_flare);
                assert(half < A, 'Vivaldi:ProbeDomain', 'Không còn mép metal để đo.');
                points = [0 0 height; -(A + half) / 2 0 height; (A + half) / 2 0 height];
                % Test central void and BOTH metallic edges, not bounding box alone.
                expected = [false true true];
                for k = 1:3
                    point = HFSSGeometryValidator.dual(points(k, :), g, pol);
                    got = HFSSCAD.containsPoint(s, name, point);
                    assert(got == expected(k), 'Vivaldi:FlareVoid', ...
                           '%s pol%d z=%.8g probe%d: expected metal=%d, actual=%d. Không tiếp tục.', name, pol, height, k, expected(k), got);
                end
                if solid
                    x = (A + half) / 2;
                    for side = [-1 1]
                        for ratio = [.45 .55]
                            point = HFSSGeometryValidator.dual([x side * ratio * p.thickness height], g, pol);
                            got = HFSSCAD.containsPoint(s, name, point);
                            assert(got == (ratio < .5), 'Vivaldi:Thickness', 'BothSides/thickness probe không đúng.');
                        end
                    end
                end
            end
        end

        function assertCavity(s, p, both)
            g = vivaldiCalculateGeometry(p);
            for pol = 1:(1 + logical(both))
                for k = 1:3
                    point = mean(g.slotRectangles(k).corners, 1);
                    point = HFSSGeometryValidator.dual(point, g, pol);
                    assert(~HFSSCAD.containsPoint(s, 'Vivaldi_1', point), 'Vivaldi:Cavity', 'Slot/cavity không rỗng: Rectangle%d pol%d.', k, pol);
                end
            end
        end

        function assertCoax(s, p)
            g = vivaldiCalculateGeometry(p);
            for k = 1:2
                if k == 1
                    suffix = '';
                else
                    suffix = '_1';
                end
                inner = ['cable_in' suffix];
                outer = ['cable_out' suffix];
                for item = {inner, outer}
                    material = char(s.call(s.Editor, 'GetPropertyValue', 'Geometry3DAttributeTab', item{1}, 'Material'));
                    assert(strcmpi(strrep(material, '"', ''), 'copper'), 'Vivaldi:Material', 'Coax không phải copper.');
                    HFSSGeometryValidator.assertSolveInside(s, item{1}, false);
                end
                vi = HFSSCAD.numbers(s.call(s.Editor, 'GetObjectVolume', inner));
                vo = HFSSCAD.numbers(s.call(s.Editor, 'GetObjectVolume', outer));
                expectedI = pi * p.r_cabin^2 * g.h_cabin;
                expectedO = pi * (p.r_cabout^2 - p.r_cabmid^2) * g.h_cabout;
                assert(abs(vi - expectedI) < max(1e-7, expectedI * 1e-5) && abs(vo - expectedO) < max(1e-7, expectedO * 1e-5), ...
                       'Vivaldi:CoaxVolume', 'Coax volume không đúng; outer có thể chưa rỗng.');
                center = g.ports(k).center;
                faces = HFSSCAD.numbers(s.call(s.Editor, 'GetFaceIDs', g.ports(k).name));
                assert(numel(faces) == 1, 'Vivaldi:PortFace', 'Port phải là một circular sheet face.');
                area = HFSSCAD.numbers(s.call(s.Editor, 'GetFaceArea', faces(1)));
                actual = HFSSCAD.numbers(s.call(s.Editor, 'GetFaceCenter', faces(1)));
                assert(abs(area - pi * p.r_cabmid^2) < 1e-6 && norm(actual - center) < 1e-5, ...
                       'Vivaldi:PortPosition', 'Port area/center sai.');
                portMaterial = char(s.call(s.Editor, 'GetPropertyValue', 'Geometry3DAttributeTab', g.ports(k).name, 'Material'));
                assert(strcmpi(strrep(portMaterial, '"', ''), 'vacuum'), 'Vivaldi:PortMaterial', 'Port sheet phải là vacuum.');
                % At an interior plane: bore center holds inner but no outer/body;
                % annular copper exists while aluminum is absent there.
                point = (g.cables(k).outerStart + g.cables(k).outerEnd) / 2;
                assert(HFSSCAD.containsPoint(s, inner, point) && ~HFSSCAD.containsPoint(s, outer, point), ...
                       'Vivaldi:CoaxHollow', 'Inner/bore topology sai.');
                point(1) = point(1) + (p.r_cabmid + p.r_cabout) / 2;
                assert(HFSSCAD.containsPoint(s, outer, point) && ~HFSSCAD.containsPoint(s, 'Vivaldi_1', point), ...
                       'Vivaldi:CoaxSubtract', 'Outer conductor hoặc final metal subtraction sai.');
            end
            material = char(s.call(s.Editor, 'GetPropertyValue', 'Geometry3DAttributeTab', 'Vivaldi_1', 'Material'));
            assert(strcmpi(strrep(material, '"', ''), 'aluminum'), 'Vivaldi:Material', 'Body không phải aluminum.');
            HFSSGeometryValidator.assertSolveInside(s, 'Vivaldi_1', false);
        end

        function assertSolveInside(s, name, expected)
            value = s.call(s.Editor, 'GetPropertyValue', 'Geometry3DAttributeTab', name, 'Solve Inside');
            if isnumeric(value) || islogical(value)
                actual = logical(value);
            else
                value = lower(strtrim(char(value)));
                assert(ismember(value, {'true', 'false'}), 'Vivaldi:SolveInside', 'Không đọc được Solve Inside của %s.', name);
                actual = strcmp(value, 'true');
            end
            assert(isscalar(actual) && actual == expected, 'Vivaldi:SolveInside', 'SolveInside sai: %s.', name);
        end

        function point = dual(point, g, pol)
            if pol == 2
                point = (point - g.transform.pivot) * g.transform.rotation' + g.transform.pivot + g.transform.move;
            end
        end

    end
end
