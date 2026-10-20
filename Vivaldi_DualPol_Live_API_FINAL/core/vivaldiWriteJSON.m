function vivaldiWriteJSON(path, value)
    % Mục đích: ghi cấu hình/chẩn đoán JSON, tuyệt đối không ghi JSON lên AEDT.
    assert(~strcmpi(getExtension(path), '.aedt'), 'Vivaldi:JSONPath', 'Không ghi JSON lên AEDT.');
    fid = fopen(path, 'w', 'n', 'UTF-8');
    assert(fid >= 0, 'Vivaldi:Write', 'Không mở được %s.', path);
    cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%s\n', jsonencode(value));
end

function ext = getExtension(path)
    [~, ~, ext] = fileparts(path);
end
