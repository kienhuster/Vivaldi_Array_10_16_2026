function startup()
    % Mục đích: nạp engine hiện tại, helper mở rộng và thư viện hfss-api đi kèm.
    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'core'), fullfile(root, 'automation'), fullfile(root, 'custom_helpers'), fullfile(root, 'results'));
    apiRoot = fullfile(root, 'third_party', 'hfss-api');
    addpath(apiRoot);
    hfssIncludePaths([apiRoot filesep]);
end
