function report = runPortableTests(outputDir)
    % Runs actual math and protocol regression tests in MATLAB or GNU Octave.
    % No assertion in this runner establishes HFSS COM/CAD compatibility.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'core'), fullfile(root, 'com'), fullfile(root, 'results'), fullfile(root, 'tests'));
    if nargin < 1
        outputDir = tempname;
    end
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end
    checks = {};
    p = vivaldiDefaultParams();
    g = vivaldiCalculateGeometry(p);
    assert(numel(fieldnames(p)) == 19 && size(g.expressions, 1) == 31);
    near(g.L_flare, 46.4, 1e-12);
    near(g.r_flare, .07950171237314518, 1e-13);
    near(g.x_feed, 2.4993308607789606, 1e-11);
    near(g.z_feed, .66369670994107, 1e-11);
    near(g.L_patch, 49.23630329005893, 1e-10);
    near(g.de_L, 22, 1e-12);
    near(g.h_cabin, 2.5, 1e-12);
    checks{end + 1} = '01 default formulas and 19/31 variable schema';
    for lengthValue = [37.628 43.287 58.375 61.352 90]
        q = p;
        q.L_flare_1 = lengthValue;
        [ok, e] = vivaldiValidateParams(q);
        assert(ok, strjoin(e, ' | '));
        v = vivaldiCalculateGeometry(q);
        assert(v.L_patch ~= g.L_patch);
    end
    q = p;
    q.L_flare_1 = 61.352;
    q.aperture_w = 24.635;
    q.cavity_w = 1.725;
    q.thickness = 2.35;
    [ok, e] = vivaldiValidateParams(q);
    assert(ok, strjoin(e, ' | '));
    checks{end + 1} = '02 arbitrary real dimensions (no preset restriction)';
    invalid = { 'aperture_w', .25; 'slot_feed_w', 0; 'r_cabin', .4; 'r_cabmid', .6; ...
               'L_flare_1', -1; 'them', -6.4; 'cavity_w', 200; 'h_de', NaN; 'cavity_L', 200};
    for k = 1:size(invalid, 1)
        q = p;
        q.(invalid{k, 1}) = invalid{k, 2};
        assert(~vivaldiValidateParams(q));
    end
    checks{end + 1} = '03 invalid dimensions, radius ordering, cavity and nonfinite inputs';
    for target = [49 50 57.35 91.624]
        [q, r] = vivaldiSolveTargetLength(p, target);
        v = vivaldiCalculateGeometry(q);
        near(v.L_patch, target, 1e-6);
        assert(abs(r.residual) < 1e-6);
        names = setdiff(fieldnames(p), {'L_flare_1'});
        for k = 1:numel(names)
            assert(q.(names{k}) == p.(names{k}));
        end
    end
    expectError(@()vivaldiSolveTargetLength(p, -1));
    expectError(@()vivaldiSolveTargetLength(p, 1));
    checks{end + 1} = '04 arbitrary target-length roots, residuals and impossible target';
    assert(strcmp(g.cs.RelativeCS1.parent, 'patch_td'));
    near(norm(g.cs.RelativeCS1.origin - [10 -1 46.4]), 0, 1e-10);
    near(norm(g.transition.left(1, :) - [-g.x_feed 0 g.z_feed]), 0, 1e-10);
    near(norm(g.ports(2).center - [11 10.54933086077896 -2.83630329005893]), 0, 1e-10);
    near(dot(g.plates(1).normal, g.plates(2).normal), 0, 1e-12);
    checks{end + 1} = '05 parent CS, transition pivot, dual transform and port coordinates';
    info = vivaldiInspectReference(fullfile(root, 'reference', '17_10_2026_vivaldi.aedt'));
    assert(strcmp(info.solutionType, 'DrivenModal') && info.portCount == 2 && info.radiationCount == 1 && info.noArray);
    assert(numel(info.topLevelNames) == 8 && size(info.variables, 1) == 31);
    for k = 1:31
        idx = find(strcmp(info.variables(:, 1), g.expressions{k, 1}));
        assert(isscalar(idx));
        if isfield(p, g.expressions{k, 1})
            [~, meta] = vivaldiDefaultParams();
            m = find(strcmp({meta.name}, g.expressions{k, 1}));
            near(HFSSVariableManager.parseLiteral(info.variables{idx, 2}, meta(m).unit), p.(g.expressions{k, 1}), 1e-12);
        else
            assert(strcmp(regexprep(info.variables{idx, 2}, '\s', ''), regexprep(g.expressions{k, 2}, '\s', '')));
        end
    end
    checks{end + 1} = '06 parsed named source design, 31 expressions and source inventory';
    graph = vivaldiDependencyGraph(p);
    names = {graph.name};
    assert(numel(unique(names)) == numel(names));
    for k = 1:numel(graph)
        assert(all(ismember(graph(k).dependsOn, names)));
    end
    assert(any(strcmp({graph.kind}, 'CAD')));
    checks{end + 1} = '07 dependency graph references resolve';
    near(HFSSVariableManager.parseLiteral('0.04m', 'mm'), 40, 1e-12);
    near(HFSSVariableManager.parseLiteral('2.1e1deg', 'deg'), 21, 1e-12);
    expectError(@()HFSSVariableManager.parseLiteral('40+1mm', 'mm'));
    expectError(@()HFSSVariableManager.parseLiteral('2GHz', 'mm'));
    checks{end + 1} = '08 COM variable literal parser, units and expression rejection';
    path = fullfile(outputDir, 'ProtocolWorking.aedt');
    fid = fopen(path, 'w');
    fprintf(fid, 'PROTOCOL TEST FILE, NOT HFSS');
    fclose(fid);
    mock = HFSSMockTransport(p, path);
    log = HFSSDiagnostics();
    session = HFSSCOMConnection(log, @mock.dispatch);
    session.Connected = true;
    session.Desktop = 'desktop';
    session.Project = 'project';
    session.Design = 'design';
    session.Editor = 'editor';
    HFSSVariableManager.verify(session, p);
    q = p;
    q.L_flare_1 = 43.287;
    HFSSVariableManager.write(session, q);
    HFSSVariableManager.verify(session, q);
    mutation = find(strcmp({session.Calls.method}, 'ChangeProperty'), 1);
    args = session.Calls(mutation).arguments;
    assert(strcmp(args{1}{2}{1}, 'NAME:LocalVariableTab') && iscell(args{1}{2}{3}{2}));
    HFSSVariableManager.write(session, p);
    checks{end + 1} = '09 nested cell variable dispatch and exact readback (protocol double)';
    manager = HFSSProjectManager(session, fullfile(root, 'reference', '17_10_2026_vivaldi.aedt'));
    manager.WorkingPath = path;
    [~, manager.ProjectName] = fileparts(path);
    manager.LastValid = p;
    manager.Healthy = true;
    manager.ParameterizedMiddleMove = true;
    manager.Validator = @mock.validate;
    manager.update(q);
    assert(manager.LastValid.L_flare_1 == q.L_flare_1 && manager.Dirty);
    methods = {session.Calls.method};
    assert(~any(ismember(methods, {'NewProject', 'InsertDesign', 'SaveAs', 'Save', 'Analyze', 'AnalyzeAll'})));
    checks{end + 1} = '10 repeated update uses one project/design; no save/new/solve (protocol double)';
    mock.Values('L_flare_1') = '44.125mm';
    expectError(@()manager.update(q));
    assert(~manager.Healthy && startsWith(manager.ResultsState, 'RESULTS OUTDATED'));
    % Reset only the test double after checking that external edits are not overwritten.
    assert(strcmp(mock.Values('L_flare_1'), '44.125mm'));
    mock.Values('L_flare_1') = '43.287mm';
    manager.Healthy = true;
    mock.FailUpdateValue = 46;
    bad = q;
    bad.L_flare_1 = 46;
    expectError(@()manager.update(bad));
    HFSSVariableManager.verify(session, q);
    assert(manager.Healthy && manager.LastValid.L_flare_1 == q.L_flare_1);
    assert(startsWith(manager.ResultsState, 'RESULTS OUTDATED'));
    checks{end + 1} = '11 failed geometry predicate triggers validated rollback and stale results';
    mock.FailPartialValue = 60;
    bad = q;
    bad.L_flare_1 = 60;
    expectError(@()manager.update(bad));
    HFSSVariableManager.verify(session, q);
    assert(manager.Healthy);
    checks{end + 1} = '12 partial COM mutation is rolled back without saving';
    mock.FailRollback = true;
    bad = q;
    bad.L_flare_1 = 46;
    expectError(@()manager.update(bad));
    assert(~manager.Healthy && manager.Dirty);
    expectError(@()manager.save());
    checks{end + 1} = '13 failed rollback blocks Save and requires recovery';
    mock.FailRollback = false;
    manager.Healthy = true;
    manager.ParameterizedMiddleMove = false;
    bad = q;
    bad.thickness = 2.45;
    expectError(@()manager.update(bad));
    assert(HFSSProjectManager.hasLiteralMiddleMove(info.sourceText));
    expectError(@()manager.checkDestination(manager.ReferencePath, false));
    checks{end + 1} = '14 reference guard and historical literal Move thickness guard';
    mock.Disconnected = true;
    assert(~session.ping() && ~session.Connected);
    mock.Disconnected = false;
    checks{end + 1} = '15 lost session is detected (protocol double)';
    session.Connected = true;
    session.Calls = struct('target', {}, 'method', {}, 'arguments', {});
    mock.Solids = {};
    mock.Sheets = {};
    mock.Lines = {};
    HFSSFlareBuilder(session);
    HFSSCavityBuilder(session);
    methods = {session.Calls.method};
    assert(sum(strcmp(methods, 'CreateEquationSurface')) == 2);
    assert(sum(strcmp(methods, 'CreateRectangle')) == 3 && any(strcmp(methods, 'Copy')) && any(strcmp(methods, 'Rotate')));
    idx = find(strcmp(methods, 'Rotate'));
    params = session.Calls(idx).arguments{2};
    assert(strcmp(params{5}, 'deg_slot_t'));
    assert(isequal(mock.Sheets, {'EquationSurface1'}));
    checks{end + 1} = '16 flare clone/trim/rotate and cavity command protocol (no physics emulation)';
    cfg = HFSSSimulationSetup.defaults();
    HFSSSimulationSetup.validate(cfg);
    a = HFSSSimulationSetup.setupArgs(cfg);
    b = HFSSSimulationSetup.sweepArgs(cfg);
    has = @(items, value) any(cellfun(@(item)ischar(item) && strcmp(item, value), items));
    assert(has(a, '5GHz') && has(b, '20GHz') && has(b, '0.25GHz'));
    cfg.powerW = [0 0];
    expectError(@()HFSSSimulationSetup.validate(cfg));
    checks{end + 1} = '17 source solver settings and excitation validation';
    angles = (-60:1:60)';
    gain = -(angles / 20).^2 * 3;
    r = HFSSResultImporter.hpbw(angles, gain);
    near(r.widthDeg, 40, 1e-8);
    r = HFSSResultImporter.hpbw(angles, zeros(size(angles)));
    assert(isnan(r.widthDeg));
    checks{end + 1} = '18 HPBW interpolation and missing-crossing handling (synthetic unit fixture, never GUI results)';
    jsonPath = fullfile(outputDir, 'protocol-diagnostics.json');
    log.export(jsonPath);
    parsed = jsondecode(fileread(jsonPath));
    assert(~isempty(parsed.records));
    checks{end + 1} = '19 diagnostics JSON export retains explicit evidence status';
    if ~ispc
        expectError(@()session.connect());
    end
    checks{end + 1} = '20 explicit non-Windows Direct COM failure; no fallback';
    if exist('OCTAVE_VERSION', 'builtin')
        runtime = ['GNU Octave ' OCTAVE_VERSION];
    else
        runtime = ['MATLAB ' version];
    end
    report = struct('time', datestr(now, 30), 'runtime', runtime, 'count', numel(checks), 'checks', {checks}, ...
                    'scope', 'Math + protocol regression only; no HFSS and no desktop GUI', ...
                    'integrationStatus', 'PENDING — requires Windows MATLAB + HFSS');
    vivaldiWriteJSON(fullfile(outputDir, 'portable-test-results.json'), report);
    fprintf('PASS: %d portable math/protocol test groups (%s). HFSS remains PENDING.\n', numel(checks), runtime);
end

function near(actual, expected, tolerance)
    assert(abs(actual - expected) <= tolerance, 'Numeric residual exceeds tolerance.');
end

function expectError(f)
    raised = false;
    try
        f();
    catch
        raised = true;
    end
    assert(raised, 'Expected an error but operation returned.');
end
