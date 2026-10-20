function startup()
    % Optional convenience when opening this folder as MATLAB Current Folder.
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'core'), fullfile(root, 'com'), fullfile(root, 'results'));
end
