classdef VivaldiScriptWriter < handle
    % Mục đích: ghép đầu ra thật của hfss-api và chèn kiểm tra lỗi từng thao tác.
    % Các trường số cũ dùng %f được thay bằng biểu thức/%.17g có kiểm tra mẫu.
    properties
        Lines = {}
        UsedHelpers = {}
        ErrorMode = 'fail'
    end
    methods

        function line(w, text)
            w.Lines{end + 1} = char(text);
        end

        function call(w, text, label)
            text = VivaldiScriptWriter.normalize(text);
            w.line('Err.Clear');
            w.line('On Error Resume Next');
            w.line(text);
            w.line('sbErr = Err.Number: sbDesc = Err.Description');
            w.line('On Error GoTo 0');
            if strcmp(w.ErrorMode, 'raise')
                w.line(['If sbErr <> 0 Then Err.Raise sbErr, ' w.q(label) ', sbDesc']);
            else
                w.line(['If sbErr <> 0 Then Fail ' w.q(label) ' & ": " & CStr(sbErr) & " " & sbDesc: Exit Sub']);
            end
        end

        function require(w, condition, message)
            w.call(['sbCondition = (' condition ')'], message);
            if strcmp(w.ErrorMode, 'raise')
                w.line(['If Not sbCondition Then Err.Raise 513, "Vivaldi", ' w.q(message)]);
            else
                w.line(['If Not sbCondition Then Fail ' w.q(message) ': Exit Sub']);
            end
        end

        function stage(w, name)
            w.line(['Stage ' w.q(name)]);
        end

        function pass(w, name, geometry, message)
            w.line(['WriteStatus ' w.q(['CHECK|' name '|PASS|' geometry '|' message])]);
            w.call(['DebugPause ' w.q(name)], ['Dừng kiểm tra ' name]);
        end

        function text = capture(w, helper, args, properties)
            % Gọi trực tiếp helper gốc; không tự tái tạo primitive/Boolean có sẵn.
            if nargin < 4
                properties = cell(0, 2);
            end
            path = tempname;
            fid = fopen(path, 'wt');
            assert(fid >= 0, 'Vivaldi:Script', 'Không tạo được tệp trung gian.');
            cleanup = onCleanup(@()closeCapture(fid, path)); %#ok<NASGU>
            helper(fid, args{:});
            fclose(fid);
            fid = -1;
            text = fileread(path);
            for k = 1:size(properties, 1)
                key = properties{k, 1};
                value = properties{k, 2};
                pattern = ['("' regexptranslate('escape', [key ':=']) '"\s*,\s*)(?:Array\([^)]*\)|"[^"]*"|True|False|true|false|[-+0-9.eE]+)'];
                [first, last, tokens] = regexp(text, pattern, 'start', 'end', 'tokens');
                assert(numel(first) == 1, 'Vivaldi:LibraryFormat', ...
                       'Không xác định duy nhất trường %s của %s.', key, func2str(helper));
                text = [text(1:first - 1), tokens{1}{1}, w.literal(value), text(last + 1:end)];
            end
            w.UsedHelpers{end + 1} = func2str(helper);
        end

        function lib(w, helper, args, properties)
            if nargin < 4
                properties = cell(0, 2);
            end
            text = w.capture(helper, args, properties);
            w.call(text, ['Thư viện: ' func2str(helper)]);
        end

    end
    methods (Static)

        function out = normalize(text)
            % Ghép continuation gốc; tách lại ở dấu phẩy ngoài chuỗi nếu dòng dài.
            text = regexprep(text, '[ \t]+_\r?\n[ \t]*', ' ');
            lines = regexp(text, '\r?\n', 'split');
            result = {};
            for k = 1:numel(lines)
                line = lines{k};
                count = 0;
                while numel(line) > 900
                    quoted = false;
                    cuts = [];
                    j = 1;
                    while j <= min(880, numel(line))
                        if line(j) == '"'
                            if quoted && j < numel(line) && line(j + 1) == '"'
                                j = j + 1;
                            else
                                quoted = ~quoted;
                            end
                        elseif line(j) == ',' && ~quoted
                            cuts(end + 1) = j;
                        end %#ok<AGROW>
                        j = j + 1;
                    end
                    assert(~isempty(cuts), 'Vivaldi:ScriptLine', 'Dòng VBScript quá dài, không thể tách an toàn.');
                    cut = cuts(end);
                    result{end + 1} = [line(1:cut) ' _'];
                    line = strtrim(line(cut + 1:end));
                    count = count + 1; %#ok<AGROW>
                    assert(count < 24, 'Vivaldi:ScriptLine', 'Quá nhiều continuation trong VBScript.');
                end
                result{end + 1} = line; %#ok<AGROW>
            end
            out = strjoin(result, newline);
        end

        function out = q(value)
            value = char(value);
            assert(isrow(value) || isempty(value), 'Vivaldi:Literal', 'Cần chuỗi một dòng.');
            assert(~any(ismember(value, [char(0), char(10), char(13)])), 'Vivaldi:Literal', 'Không cho phép ký tự điều khiển trong chuỗi script.');
            out = ['"' strrep(value, '"', '""') '"'];
        end

        function out = literal(value)
            if iscell(value)
                out = ['Array(' strjoin(cellfun(@VivaldiScriptWriter.literal, value, 'UniformOutput', false), ', ') ')'];
            elseif islogical(value)
                assert(isscalar(value), 'Vivaldi:Literal', 'Cần logical scalar.');
                if value
                    out = 'True';
                else
                    out = 'False';
                end
            elseif isnumeric(value)
                assert(isscalar(value) && isreal(value) && isfinite(value), 'Vivaldi:Literal', 'Cần số hữu hạn.');
                out = sprintf('%.17g', value);
            else
                out = VivaldiScriptWriter.q(value);
            end
        end

    end
end

function closeCapture(fid, path)
    % Đóng/xóa tệp trung gian kể cả khi helper gốc phát sinh lỗi.
    try
        if any(fopen('all') == fid)
            fclose(fid);
        end
    catch
    end
    if isfile(path)
        delete(path);
    end
end
