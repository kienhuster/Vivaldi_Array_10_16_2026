function w = hfssVivaldiScript(path, statusPath, id, saveDebug)
% Mục đích: ghi script bằng helper thật, giữ biểu thức và bảo vệ mã hóa đường dẫn.
% Đây là struct callback nhỏ; không có lớp, session COM hoặc cơ chế rollback.
% Chỉ script cuối được đổi thành ASCII không BOM; status do VBS ghi UTF-16LE.
if nargin < 4, saveDebug = false; end
assert(islogical(saveDebug) && isscalar(saveDebug), 'Vivaldi:Debug', 'Tùy chọn debug phải là logical scalar.');
fid = fopen(path, 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Vivaldi:Script', 'Không ghi được script.');
w = struct('line', @line, 'call', @call, 'require', @require, 'stage', @stage, ...
    'pass', @pass, 'capture', @capture, 'lib', @lib, 'q', @quote, ...
    'literal', @literal, 'finish', @finish, 'abort', @abort);
line('Option Explicit');
line('Dim oHfssApp, oDesktop, oProject, oDesign, oEditor, oModule, oMaterials, oBoundary, oSolutions, oReport');
line('Dim vBodyMaterial, fs, vStatusPath, vStage, vStageName, vCommand, vSaveDebug, vDebugPath, sbErr, sbSource, sbDesc, sbCondition, sbObjects, sbHasData, vOpened, vStream');
line('Set fs = CreateObject("Scripting.FileSystemObject")');
line(['vStatusPath = ' quote(statusPath)]);
line('vBodyMaterial = "aluminum"');
line('vStage = "BAT_DAU": vStageName = "Khởi tạo": vCommand = ""');
line(['vSaveDebug = ' literal(saveDebug)]);
line(['vDebugPath = ' quote(fullfile(fileparts(statusPath), 'CAD_DEBUG_INCOMPLETE.aedt'))]);
line('Set vStream = fs.CreateTextFile(vStatusPath, True, True)');
line('vStream.Close');
line(['WriteStatus ' quote(['JOB|' id])]);
line('Main');
line('Sub Main()');

    function line(text)
        assert(fid >= 0, 'Vivaldi:Script', 'Script đã đóng.');
        fprintf(fid, '%s\n', text);
    end

    function call(text, label, phase)
        % Ghi lệnh thực tế; guard từng statement để lỗi SetModule không bị che bởi lệnh sau.
        if nargin < 3, phase = 'COMMAND'; end
        logicalText = regexprep(text, '[ \t]+_\r?\n[ \t]*', ' ');
        statements = regexp(logicalText, '\r?\n', 'split');
        statements = statements(~cellfun(@(value)isempty(strtrim(value)), statements));
        if ~isempty(regexp(logicalText, '(?m)^\s*(If |Else|End If)', 'once'))
            % Block chọn project khi solve giữ nguyên control flow, không Execute động.
            statements = {logicalText};
        end
        for n = 1:numel(statements)
            command = strrep(strrep(statements{n}, char(13), ' '), char(10), ' / ');
            line('vCommand = ""');
            % Chia literal log thành statement ngắn; không vượt giới hạn continuation.
            bytes = unicode2native(command, 'UTF-16LE'); first = 1;
            while first <= numel(bytes)
                last = min(first + 159, numel(bytes));
                unit = double(bytes(last - 1)) + 256 * double(bytes(last));
                if last < numel(bytes) && unit >= 55296 && unit <= 56319, last = last - 2; end
                chunk = native2unicode(bytes(first:last), 'UTF-16LE');
                line(['vCommand = vCommand & ' quote(chunk)]);
                first = last + 1;
            end
            line('TraceCommand vCommand');
            line('Err.Clear');
            line('On Error Resume Next');
            line(statements{n});
            line('sbErr = Err.Number: sbSource = Err.Source: sbDesc = Err.Description');
            line('On Error GoTo 0');
            line(['If sbErr <> 0 Then OperationFailed ' quote(label) ', ' quote(phase) ', sbErr, sbSource, sbDesc: Exit Sub']);
            line(['WriteStatus "OPERATION|" & vStage & "|' phase '|METHOD_OK|" & CleanLine(vCommand)']);
        end
    end

    function require(condition, message)
        % Lỗi API khi tính predicate khác với predicate trả False; không báo thiếu mặt khi query lỗi.
        call(['sbCondition = (' condition ')'], 'Không thực hiện được truy vấn kiểm chứng', 'QUERY');
        line(['If Not sbCondition Then OperationFailed ' quote(message) ', "ASSERTION", 513, "Vivaldi.Validation", "Dieu kien tra ve False": Exit Sub']);
    end

    function stage(name)
        line(['Stage ' quote(name)]);
    end

    function pass(name, geometry, message)
        line(['WriteStatus ' quote(['CHECK|' name '|PASS|' geometry '|' message])]);
    end

    function text = capture(helper, args, properties)
        % Gọi helper(fid, ...) gốc; chỉ thay trường helper cũ chưa hỗ trợ expression.
        if nargin < 3
            properties = cell(0, 2);
        end
        temporary = tempname;
        stream = fopen(temporary, 'w', 'n', 'UTF-8');
        assert(stream >= 0, 'Vivaldi:Script', 'Không tạo được tệp helper trung gian.');
        cleanup = onCleanup(@()closeTemporary(stream, temporary)); %#ok<NASGU>
        helper(stream, args{:});
        fclose(stream);
        text = fileread(temporary);
        for k = 1:size(properties, 1)
            key = properties{k, 1};
            pattern = ['("' regexptranslate('escape', [key ':=']) '"\s*,\s*)(?:Array\([^)]*\)|"[^"]*"|True|False|true|false|[-+0-9.eE]+)'];
            [first, last, tokens] = regexp(text, pattern, 'start', 'end', 'tokens');
            assert(numel(first) == 1, 'Vivaldi:LibraryFormat', ...
                'Không xác định duy nhất trường %s của %s.', key, func2str(helper));
            text = [text(1:first - 1), tokens{1}{1}, literal(properties{k, 2}), text(last + 1:end)];
        end
    end

    function lib(helper, args, properties)
        if nargin < 3
            properties = cell(0, 2);
        end
        call(capture(helper, args, properties), ['Thư viện: ' func2str(helper)]);
    end

    function finish()
        % Kết thúc Main trước khi ghép các phép đo HFSS; không thực thi trên MATLAB.
        line('End Sub');
        runtime = fullfile(fileparts(mfilename('fullpath')), 'hfssVivaldiChecks.vbs');
        line(fileread(runtime));
        fclose(fid);
        fid = -1;
        text = fileread(path);
        text = asciiScript(text);
        text = normalize(text);
        verifyScript(text);
        stream = fopen(path, 'wb');
        assert(stream >= 0, 'Vivaldi:Script', 'Không ghi được script ASCII.');
        cleanup = onCleanup(@()fclose(stream)); %#ok<NASGU>
        fwrite(stream, uint8(text), 'uint8');
    end

    function abort()
        % Đóng stream nếu helper ném lỗi; giữ script dở để chẩn đoán, không launch.
        if fid >= 0
            fclose(fid);
            fid = -1;
        end
    end
end

function out = quote(value)
% Mục đích: escape chuỗi VBS, chặn xuống dòng và ký tự điều khiển trong đường dẫn.
value = char(value);
assert(isrow(value) || isempty(value), 'Vivaldi:Literal', 'Cần chuỗi một dòng.');
assert(~any(value < 32), 'Vivaldi:Literal', 'Không cho phép ký tự điều khiển trong chuỗi script.');
out = ['"' strrep(value, '"', '""') '"'];
end

function out = literal(value)
% Mục đích: giữ số 17 chữ số, Boolean và mảng VBS đúng kiểu dữ liệu.
if iscell(value)
    out = ['Array(' strjoin(cellfun(@literal, value, 'UniformOutput', false), ', ') ')'];
elseif islogical(value)
    assert(isscalar(value), 'Vivaldi:Literal', 'Cần logical scalar.');
    if value, out = 'True'; else, out = 'False'; end
elseif isnumeric(value)
    assert(isscalar(value) && isreal(value) && isfinite(value), 'Vivaldi:Literal', 'Cần số hữu hạn.');
    out = sprintf('%.17g', value);
else
    out = quote(value);
end
end

function text = asciiScript(text)
% Mục đích: đổi Unicode bên trong literal thành ChrW, giữ nguyên đường dẫn Windows.
% VBScript chỉ chứa byte ASCII, không UTF-8/UTF-16 BOM; không bỏ dấu tên thư mục.
lines = regexp(text, '\r?\n', 'split');
for k = 1:numel(lines)
    source = lines{k}; result = ''; j = 1;
    while j <= numel(source)
        if source(j) == ''''
            % Chú thích không ảnh hưởng dữ liệu hoặc đường dẫn trong script.
            result = [result ''' HFSS API / CAD checks']; %#ok<AGROW>
            break
        elseif source(j) == '"'
            j = j + 1; value = ''; closed = false;
            while j <= numel(source)
                if source(j) == '"'
                    if j < numel(source) && source(j + 1) == '"'
                        value(end + 1) = '"'; j = j + 2; %#ok<AGROW>
                        continue
                    end
                    closed = true; j = j + 1; break
                end
                value(end + 1) = source(j); j = j + 1; %#ok<AGROW>
            end
            assert(closed, 'Vivaldi:ScriptSyntax', 'Chuỗi VBS chưa đóng ở dòng %d.', k);
            if all(double(value) < 128)
                result = [result quote(value)]; %#ok<AGROW>
            else
                bytes = unicode2native(value, 'UTF-16LE');
                units = double(bytes(1:2:end)) + 256 * double(bytes(2:2:end));
                parts = cell(1, numel(units));
                for n = 1:numel(units)
                    u = units(n); if u > 32767, u = u - 65536; end
                    parts{n} = sprintf('ChrW(%d)', u);
                end
                result = [result '(' strjoin(parts, ' & ') ')']; %#ok<AGROW>
            end
        else
            assert(double(source(j)) < 128, 'Vivaldi:Encoding', 'Unicode ngoài chuỗi ở dòng %d.', k);
            result(end + 1) = source(j); j = j + 1; %#ok<AGROW>
        end
    end
    lines{k} = result;
end
text = strjoin(lines, newline);
end

function text = normalize(text)
% Mục đích: gộp continuation cũ và tách dòng ở dấu phẩy hoặc & ngoài literal.
text = regexprep(text, '[ \t]+_\r?\n[ \t]*', ' ');
source = regexp(text, '\r?\n', 'split'); result = {};
for k = 1:numel(source)
    line = source{k}; count = 0;
    while numel(line) > 900
        quoted = false; cuts = []; j = 1;
        while j <= min(880, numel(line))
            if line(j) == '"'
                if quoted && j < numel(line) && line(j + 1) == '"', j = j + 1;
                else, quoted = ~quoted; end
            elseif ~quoted && ismember(line(j), ',&')
                cuts(end + 1) = j; %#ok<AGROW>
            end
            j = j + 1;
        end
        assert(~isempty(cuts), 'Vivaldi:ScriptLine', 'Không thể tách dòng VBS an toàn.');
        cut = cuts(end); result{end + 1} = [line(1:cut) ' _']; %#ok<AGROW>
        line = strtrim(line(cut + 1:end)); count = count + 1;
        assert(count < 24, 'Vivaldi:ScriptLine', 'Quá nhiều continuation trong VBS.');
    end
    result{end + 1} = line; %#ok<AGROW>
end
text = strjoin(result, sprintf('\r\n'));
end

function verifyScript(text)
% Mục đích: kiểm tra lexical trước launch; chưa thay thế compiler VBScript Windows.
assert(all(double(text) < 128) && ~any(text == char(0)), 'Vivaldi:Encoding', 'Script phải là ASCII không BOM/NUL.');
lines = regexp(text, '\r?\n', 'split'); depth = 0; quoted = false;
for k = 1:numel(lines)
    line = lines{k}; assert(numel(line) < 1023, 'Vivaldi:ScriptLine', 'Dòng script quá dài.');
    j = 1;
    while j <= numel(line)
        c = line(j);
        if c == '"'
            if quoted && j < numel(line) && line(j + 1) == '"', j = j + 1;
            else, quoted = ~quoted; end
        elseif ~quoted
            if c == '''', break; end
            if c == '(', depth = depth + 1; end
            if c == ')', depth = depth - 1; end
            assert(depth >= 0, 'Vivaldi:ScriptSyntax', 'Ngoặc VBS sai tại dòng %d.', k);
        end
        j = j + 1;
    end
    assert(~quoted, 'Vivaldi:ScriptSyntax', 'Chuỗi VBS chưa đóng.');
end
assert(depth == 0, 'Vivaldi:ScriptSyntax', 'Ngoặc VBS chưa đóng.');
end

function closeTemporary(fid, path)
% Mục đích: thu hồi stream/tệp helper kể cả khi có lỗi.
if any(fopen('all') == fid), fclose(fid); end
if isfile(path), delete(path); end
end
