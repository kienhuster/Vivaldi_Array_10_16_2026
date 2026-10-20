function info = vivaldiInspectReference(file, designName)
    % Mục đích: đọc đúng design trong AEDT dạng văn bản, không thay đổi file nguồn.
    if nargin < 2
        designName = 'dual_pol_vivaldi_patch_Wflare_20';
    end
    text = fileread(file);
    lines = regexp(text, '\r?\n', 'split');
    info = struct('path', file, 'designName', designName, 'variables', {cell(0, 2)}, ...
                  'topLevelNames', {{}}, 'materials', {cell(0, 2)}, 'portCount', 0, ...
                  'radiationCount', 0, 'noArray', false, 'solutionType', '', 'sourceText', '');
    stack = {};
    selected = false;
    found = false;
    first = 0;
    partName = '';
    for k = 1:numel(lines)
        line = strtrim(lines{k});
        b = regexp(line, '^\$begin ''([^'']+)''$', 'tokens', 'once');
        if ~isempty(b)
            stack{end + 1} = b{1};
            continue
        end %#ok<AGROW>
        e = regexp(line, '^\$end ''([^'']+)''$', 'tokens', 'once');
        if ~isempty(e)
            assert(~isempty(stack) && strcmp(stack{end}, e{1}), ...
                   'VivaldiBuilder:AEDTFormat', 'Cấu trúc AEDT không cân bằng tại dòng %d.', k);
            if strcmp(e{1}, 'HFSSModel')
                if selected
                    info.sourceText = strjoin(lines(first:k), newline);
                end
                selected = false;
            end
            stack(end) = [];
            continue
        end
        if isempty(stack)
            continue
        end
        name = regexp(line, '^Name=''([^'']*)''', 'tokens', 'once');
        if strcmp(stack{end}, 'HFSSModel') && ~isempty(name)
            selected = strcmp(name{1}, designName);
            if selected
                assert(~found, 'VivaldiBuilder:DuplicateDesign', 'Tên design không duy nhất.');
                found = true;
                first = k;
            end
        end
        if ~selected
            continue
        end
        v = regexp(line, '^VariableProp\(''([^'']+)'',\s*''[^'']*'',\s*''[^'']*'',\s*''([^'']*)''\)', 'tokens', 'once');
        if ~isempty(v) && strcmp(stack{end}, 'Properties') && any(strcmp(stack, 'ModelSetup'))
            info.variables(end + 1, :) = {v{1}, v{2}};
        end
        if numel(stack) >= 2 && strcmp(stack{end}, 'Attributes') && strcmp(stack{end - 1}, 'GeometryPart') && any(strcmp(stack, 'ToplevelParts'))
            if ~isempty(name)
                partName = name{1};
                info.topLevelNames{end + 1} = partName;
            end
            m = regexp(line, '^MaterialValue=''"([^'']*)"''', 'tokens', 'once');
            if ~isempty(m)
                info.materials(end + 1, :) = {partName, m{1}};
            end
        end
        if strcmp(line, 'BoundType=''Lumped Port''')
            info.portCount = info.portCount + 1;
        end
        if strcmp(line, 'BoundType=''Radiation''')
            info.radiationCount = info.radiationCount + 1;
        end
        if strcmp(line, 'UseOption=''NoArray''')
            info.noArray = true;
        end
        s = regexp(line, '^SolutionType=''([^'']+)''', 'tokens', 'once');
        if ~isempty(s)
            info.solutionType = s{1};
        end
    end
    assert(isempty(stack), 'VivaldiBuilder:AEDTFormat', 'Cấu trúc AEDT có khối chưa đóng.');
    assert(found, 'VivaldiBuilder:MissingDesign', 'Không tìm thấy HFSS design đúng tên.');
end
