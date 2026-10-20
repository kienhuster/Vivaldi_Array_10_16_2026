function tests = testVivaldiGUI()
    % Mục đích: kiểm tra GUI desktop, callback và số nút chính; không khởi chạy HFSS.
    tests = functiontests(localfunctions);
end

function testVietnameseGUI(testCase)
    assumeTrue(testCase, usejava('desktop'), 'Cần MATLAB desktop để chạy kiểm thử GUI.');
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    f = Vivaldi_DualPol_Live_API('Visible', 'off');
    cleanup = onCleanup(@()closeTest(f)); %#ok<NASGU>
    tabs = findall(f, 'Type', 'uitab');
    verifyEqual(testCase, numel(tabs), 5);
    expected = {'Thông số anten', 'Xem trước 3D', 'Kết nối HFSS', 'Mô phỏng', 'Nhật ký & kiểm tra'};
    verifyEqual(testCase, sort({tabs.Title}), sort(expected));
    counts = [3 0 5 2 1];
    for k = 1:5
        t = tabs(strcmp({tabs.Title}, expected{k}));
        verifyEqual(testCase, numel(findall(t, 'Type', 'uibutton')), counts(k));
    end
    field = findall(f, 'Tag', 'Parameter_L_flare_1');
    field.Value = 61.352;
    callback = field.ValueChangedFcn;
    callback(field, []);
    verifyEqual(testCase, f.UserData.parameters.L_flare_1, 61.352);
    verifyEmpty(testCase, f.UserData.backend.ActiveJob);
    verifyFalse(testCase, f.UserData.backend.Healthy);
end

function closeTest(f)
    if isvalid(f)
        t = f.UserData.timer;
        stop(t);
        delete(t);
        delete(f);
    end
end
