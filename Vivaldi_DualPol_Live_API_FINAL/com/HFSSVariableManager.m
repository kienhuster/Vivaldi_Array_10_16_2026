classdef HFSSVariableManager
    methods (Static)

        function create(s, p)
            g = vivaldiCalculateGeometry(p);
            names = fieldnames(p);
            % Independent first: dependent expressions can reference any of them.
            ordered = [find(ismember(g.expressions(:, 1), names)); find(~ismember(g.expressions(:, 1), names))];
            props = {'NAME:NewProps'};
            for index = ordered(:)'
                props{end + 1} = {['NAME:' g.expressions{index, 1}], ...
                                  'PropType:=', 'VariableProp', 'UserDef:=', true, 'Value:=', g.expressions{index, 2}}; %#ok<AGROW>
            end
            s.call(s.Design, 'ChangeProperty', {'NAME:AllTabs', ...
                                                {'NAME:LocalVariableTab', {'NAME:PropServers', 'LocalVariables'}, props}});
            s.call(s.Design, 'ChangeProperty', {'NAME:AllTabs', ...
                                                {'NAME:LocalVariableTab', {'NAME:PropServers', 'LocalVariables'}, ...
                                                 {'NAME:NewProps', {'NAME:alpha', 'PropType:=', 'PostProcessingVariableProp', ...
                                   'UserDef:=', true, 'Value:=', '0deg'}}}});
        end

        function write(s, p)
            [ok, errors] = vivaldiValidateParams(p);
            assert(ok, 'Vivaldi:Parameters', '%s', strjoin(errors, newline));
            g = vivaldiCalculateGeometry(p);
            props = {'NAME:ChangedProps'};
            names = fieldnames(p);
            for k = 1:numel(names)
                idx = find(strcmp(g.expressions(:, 1), names{k}));
                props{end + 1} = {['NAME:' names{k}], 'Value:=', g.expressions{idx, 2}}; %#ok<AGROW>
            end
            s.call(s.Design, 'ChangeProperty', {'NAME:AllTabs', ...
                                                {'NAME:LocalVariableTab', {'NAME:PropServers', 'LocalVariables'}, props}});
        end

        function p = read(s)
            [p, meta] = vivaldiDefaultParams();
            for k = 1:numel(meta)
                raw = char(s.call(s.Design, 'GetVariableValue', meta(k).name));
                p.(meta(k).name) = HFSSVariableManager.parseLiteral(raw, meta(k).unit);
            end
            [ok, errors] = vivaldiValidateParams(p);
            assert(ok, 'Vivaldi:Readback', 'Biến project không hợp lệ: %s', strjoin(errors, newline));
        end

        function verify(s, p)
            actual = HFSSVariableManager.read(s);
            names = fieldnames(p);
            for k = 1:numel(names)
                n = names{k};
                assert(abs(actual.(n) - p.(n)) <= max(1, abs(p.(n))) * 1e-10, ...
                       'Vivaldi:Readback', 'HFSS không nhận đúng biến %s.', n);
            end
            g = vivaldiCalculateGeometry(p);
            for k = 1:size(g.expressions, 1)
                if ismember(g.expressions{k, 1}, names)
                    continue
                end
                raw = char(s.call(s.Design, 'GetVariableValue', g.expressions{k, 1}));
                assert(strcmp(regexprep(raw, '\s', ''), regexprep(g.expressions{k, 2}, '\s', '')), ...
                       'Vivaldi:Dependency', 'Biểu thức dẫn xuất %s không khớp nguồn.', g.expressions{k, 1});
            end
        end

        function value = parseLiteral(raw, unit)
            tok = regexp(strtrim(raw), '^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*([A-Za-z]*)$', 'tokens', 'once');
            assert(~isempty(tok), 'Vivaldi:VariableExpression', 'Biến độc lập phải là literal có đơn vị, nhận %s.', raw);
            value = str2double(tok{1});
            u = tok{2};
            if strcmp(unit, 'mm')
                units = {'mm', 'cm', 'm', 'um', 'in'};
                factors = [1 10 1000 .001 25.4];
            else
                units = {'deg', 'rad'};
                factors = [1 180 / pi];
            end
            idx = find(strcmp(u, units), 1);
            assert(~isempty(idx), 'Vivaldi:VariableUnit', 'Đơn vị %s không hỗ trợ cho %s.', u, unit);
            value = value * factors(idx);
            assert(isfinite(value), 'Vivaldi:VariableValue', 'Giá trị không hữu hạn.');
        end

    end
end
