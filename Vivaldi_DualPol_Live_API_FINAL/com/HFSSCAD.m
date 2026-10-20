classdef HFSSCAD
    % Named MATLAB cell arrays are marshalled directly to Automation VARIANTs.
    methods (Static)

        function a = attributes(name, material, inside)
            a = {'NAME:Attributes', 'Name:=', name, 'Flags:=', '', 'Color:=', '(143 175 143)', ...
                 'Transparency:=', 0, 'PartCoordinateSystem:=', 'Global', ...
                 'MaterialValue:=', ['"' material '"'], 'SurfaceMaterialValue:=', '""', 'SolveInside:=', logical(inside)};
        end

        function a = select(names)
            a = {'NAME:Selections', 'Selections:=', names, 'NewPartsModelFlag:=', 'Model'};
        end

        function wcs(s, name)
            s.call(s.Editor, 'SetWCS', {'NAME:SetWCS Parameter', ...
                                        'Working Coordinate System:=', name, 'RegionDepCSOk:=', false});
        end

        function names = names(s)
            names = {};
            for group = {'Solids', 'Sheets', 'Lines', 'Unclassified'}
                values = s.call(s.Editor, 'GetObjectsInGroup', group{1});
                names = [names HFSSCOMConnection.list(values)]; %#ok<AGROW>
            end
            names = unique(names);
        end

        function requireNames(s, expected, exact)
            if nargin < 3
                exact = false;
            end
            actual = HFSSCAD.names(s);
            assert(all(ismember(expected, actual)), 'Vivaldi:Objects', 'Thiếu đối tượng: %s', strjoin(setdiff(expected, actual), ', '));
            if exact
                assert(isequal(sort(expected), sort(actual)), 'Vivaldi:Objects', 'Đối tượng dư: %s', strjoin(setdiff(actual, expected), ', '));
            end
            bad = HFSSCOMConnection.list(s.call(s.Editor, 'GetObjectsInGroup', 'Unclassified'));
            assert(isempty(bad), 'Vivaldi:Unclassified', 'HFSS có Unclassified geometry: %s', strjoin(bad, ', '));
        end

        function clone(s, source, target, rotate)
            before = HFSSCAD.names(s);
            assert(~ismember(target, before), 'Vivaldi:Clone', 'Tên clone đã tồn tại: %s.', target);
            if rotate
                s.call(s.Editor, 'DuplicateAroundAxis', HFSSCAD.select(source), ...
                       {'NAME:DuplicateAroundAxisParameters', 'CreateNewObjects:=', true, ...
                        'WhichAxis:=', 'Z', 'AngleStr:=', '-90deg', 'NumClones:=', 2}, ...
                       {'NAME:Options', 'DuplicateAssignments:=', false});
            else
                s.call(s.Editor, 'Copy', HFSSCAD.select(source));
                s.call(s.Editor, 'Paste');
            end
            after = HFSSCAD.names(s);
            added = setdiff(after, before);
            assert(numel(added) == 1, 'Vivaldi:Clone', 'Clone %s phải tạo đúng một object; nhận %d.', source, numel(added));
            if ~strcmp(added{1}, target)
                s.call(s.Editor, 'ChangeProperty', {'NAME:AllTabs', ...
                                                    {'NAME:Geometry3DAttributeTab', {'NAME:PropServers', added{1}}, ...
                                                     {'NAME:ChangedProps', {'NAME:Name', 'Value:=', target}}}});
            end
            HFSSCAD.requireNames(s, {source, target});
        end

        function subtract(s, blank, tools)
            s.call(s.Editor, 'Subtract', {'NAME:Selections', 'Blank Parts:=', blank, 'Tool Parts:=', tools}, ...
                   {'NAME:SubtractParameters', 'KeepOriginals:=', false});
            HFSSCAD.requireNames(s, {blank});
        end

        function unite(s, names)
            s.call(s.Editor, 'Unite', HFSSCAD.select(strjoin(names, ',')), ...
                   {'NAME:UniteParameters', 'KeepOriginals:=', false});
            HFSSCAD.requireNames(s, names(1));
        end

        function moveSecond(s, name)
            s.call(s.Editor, 'Move', HFSSCAD.select(name), {'NAME:TranslateParameters', ...
                                                            'TranslateVectorX:=', '0mm', 'TranslateVectorY:=', 'thickness', 'TranslateVectorZ:=', '0mm'});
        end

        function rectangle(s, name, x, z, width, height, material)
            s.call(s.Editor, 'CreateRectangle', {'NAME:RectangleParameters', 'IsCovered:=', false, ...
                                                 'XStart:=', x, 'YStart:=', '0mm', 'ZStart:=', z, 'Width:=', width, 'Height:=', height, 'WhichAxis:=', 'Y'}, ...
                   HFSSCAD.attributes(name, material, strcmp(material, 'vacuum')));
            s.call(s.Editor, 'CoverLines', HFSSCAD.select(name));
            HFSSCAD.requireNames(s, {name});
        end

        function box(s, name, xyz, sizes, material)
            s.call(s.Editor, 'CreateBox', {'NAME:BoxParameters', 'XPosition:=', xyz{1}, ...
                                           'YPosition:=', xyz{2}, 'ZPosition:=', xyz{3}, 'XSize:=', sizes{1}, ...
                                           'YSize:=', sizes{2}, 'ZSize:=', sizes{3}}, HFSSCAD.attributes(name, material, false));
            HFSSCAD.requireNames(s, {name});
        end

        function cylinder(s, name, r, z, h, material)
            s.call(s.Editor, 'CreateCylinder', {'NAME:CylinderParameters', ...
                                                'XCenter:=', '-positionx+slot_feed_w+h2', 'YCenter:=', '0mm', ...
                                                'ZCenter:=', z, 'Radius:=', r, 'Height:=', h, 'WhichAxis:=', 'Z', 'NumSides:=', '0'}, ...
                   HFSSCAD.attributes(name, material, strcmp(material, 'vacuum')));
            HFSSCAD.requireNames(s, {name});
        end

        function vec = numbers(value)
            if isnumeric(value)
                vec = double(value(:)');
            else
                cells = HFSSCOMConnection.list(value);
                vec = cellfun(@str2double, cells);
            end
            assert(all(isfinite(vec)), 'Vivaldi:CADReadback', 'API trả số không hữu hạn.');
        end

        function bounds = bounds(s, name)
            ids = HFSSCAD.numbers(s.call(s.Editor, 'GetVertexIDsFromObject', name));
            assert(~isempty(ids), 'Vivaldi:Vertices', 'Không có vertex: %s.', name);
            xyz = zeros(numel(ids), 3);
            for k = 1:numel(ids)
                q = HFSSCAD.numbers(s.call(s.Editor, 'GetVertexPosition', ids(k)));
                assert(numel(q) == 3, 'Vivaldi:Vertices', 'Tọa độ vertex cần 3 thành phần.');
                xyz(k, :) = q;
            end
            bounds = [min(xyz, [], 1)' max(xyz, [], 1)'];
        end

        function present = containsPoint(s, name, point)
            args = {'NAME:Parameters', 'XPosition:=', sprintf('%.17gmm', point(1)), ...
                    'YPosition:=', sprintf('%.17gmm', point(2)), 'ZPosition:=', sprintf('%.17gmm', point(3))};
            values = s.call(s.Editor, 'GetBodyNamesByPosition', args);
            present = ismember(name, HFSSCOMConnection.list(values));
        end

    end
end
