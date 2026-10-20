function tests = testLiveAPI()
    tests = functiontests(localfunctions);
end

function testPortableRegression(testCase)
    folder = tempname;
    mkdir(folder);
    cleanup = onCleanup(@()rmdir(folder, 's')); %#ok<NASGU>
    r = runPortableTests(folder);
    verifyEqual(testCase, r.count, 20);
end

function testGUIInitialization(testCase)
    assumeTrue(testCase, usejava('desktop'), 'MATLAB desktop required.');
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(root);
    f = Vivaldi_DualPol_Live_API('Visible', 'off');
    cleanup = onCleanup(@()deleteGUI(f)); %#ok<NASGU>
    verifyEqual(testCase, numel(findall(f, 'Type', 'uitab')), 5);
    for name = {'L_flare_1', 'aperture_w', 'cavity_w', 'thickness'}
        h = findall(f, 'Tag', ['Parameter_' name{1}]);
        verifyEqual(testCase, numel(h), 1);
    end
    h = findall(f, 'Tag', 'Parameter_L_flare_1');
    h.Value = 61.352;
    callback = h.ValueChangedFcn;
    callback(h, []);
    verifyEqual(testCase, f.UserData.parameters.L_flare_1, 61.352);
    verifyFalse(testCase, f.UserData.session.Connected);
    verifyEqual(testCase, f.UserData.manager.ResultsState, 'NOT SIMULATED');
end

function deleteGUI(f)
    if isvalid(f)
        delete(f.UserData.monitor);
        f.UserData.session.disconnect();
        delete(f);
    end
end
