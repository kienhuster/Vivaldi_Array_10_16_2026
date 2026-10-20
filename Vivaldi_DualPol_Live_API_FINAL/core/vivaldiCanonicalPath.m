function path = vivaldiCanonicalPath(path)
    % Mục đích: chuẩn hóa symlink, dấu .. và đường dẫn Windows trước khi ghi.
    assert(ischar(path) || (isstring(path) && isscalar(path)), 'Vivaldi:Path', 'Cần đường dẫn scalar.');
    path = char(path);
    assert(~isempty(path), 'Vivaldi:Path', 'Đường dẫn rỗng.');
    if exist('OCTAVE_VERSION', 'builtin')
        [parent, name, ext] = fileparts(make_absolute_filename(path));
        if exist(path, 'file')
            path = canonicalize_file_name(path);
        else
            assert(isfolder(parent), 'Vivaldi:Path', 'Thư mục đích chưa tồn tại.');
            path = fullfile(canonicalize_file_name(parent), [name ext]);
        end
    else
        f = javaObject('java.io.File', path);
        path = char(f.getCanonicalPath());
    end
end
