classdef HFSSSimulationSetup
    methods (Static)

        function cfg = defaults()
            cfg = struct('adaptiveGHz', 5, 'startGHz', 5, 'stopGHz', 20, 'stepGHz', .25, ...
                         'deltaS', .02, 'minimumPasses', 5, 'maximumPasses', 50, ...
                         'powerW', [1 0], 'phaseDeg', [0 0], 'fieldGHz', 5);
        end

        function validate(cfg)
            scalars = {'adaptiveGHz', 'startGHz', 'stopGHz', 'stepGHz', 'deltaS', 'minimumPasses', 'maximumPasses', 'fieldGHz'};
            for k = 1:numel(scalars)
                n = scalars{k};
                v = cfg.(n);
                assert(isnumeric(v) && isreal(v) && isscalar(v) && isfinite(v) && v > 0, 'Vivaldi:SimulationConfig', '%s phải dương hữu hạn.', n);
            end
            assert(cfg.stopGHz > cfg.startGHz && cfg.stepGHz <= cfg.stopGHz - cfg.startGHz, ...
                   'Vivaldi:Sweep', 'Cần stop > start và step <= stop-start.');
            assert(cfg.minimumPasses == fix(cfg.minimumPasses) && cfg.maximumPasses == fix(cfg.maximumPasses) ...
                   && cfg.maximumPasses >= cfg.minimumPasses, 'Vivaldi:Passes', 'Adaptive passes phải là số nguyên hợp lệ.');
            assert(isnumeric(cfg.powerW) && isreal(cfg.powerW) && numel(cfg.powerW) == 2 && ...
                   all(isfinite(cfg.powerW)) && all(cfg.powerW >= 0) && sum(cfg.powerW) > 0, ...
                   'Vivaldi:Excitation', 'Hai công suất không âm; tổng > 0.');
            assert(isnumeric(cfg.phaseDeg) && isreal(cfg.phaseDeg) && numel(cfg.phaseDeg) == 2 && all(isfinite(cfg.phaseDeg)), ...
                   'Vivaldi:Phase', 'Cần hai phase theo độ.');
        end

        function create(s, p, cfg) %#ok<INUSD>
            HFSSSimulationSetup.validate(cfg);
            HFSSPortBuilder(s);
            s.Diagnostics.CurrentStep = 'CHECK_17';
            HFSSCAD.wcs(s, 'Global');
            args = {'NAME:RegionParameters'};
            for direction = {'+X', '-X', '+Y', '-Y', '+Z', '-Z'}
                args = [args, {[direction{1} 'PaddingType:='], 'Absolute Offset', [direction{1} 'Padding:='], '20mm'}]; %#ok<AGROW>
            end
            attrs = HFSSCAD.attributes('RadiatingSurface', 'vacuum', true);
            attrs{5} = 'Wireframe#';
            s.call(s.Editor, 'CreateRegion', args, attrs);
            s.call(s.module('BoundarySetup'), 'AssignRadiation', {'NAME:Open1', 'Objects:=', {'RadiatingSurface'}, ...
                                                                  'IsFssReference:=', false, 'IsForPML:=', false});
            boundary = HFSSCOMConnection.list(s.call(s.module('BoundarySetup'), 'GetBoundaries'));
            assert(all(ismember({'Open1', 'Radiation'}, boundary)), 'Vivaldi:Radiation', 'Không có Open1 Radiation.');
            s.Diagnostics.checkpoint('CHECK_17', {'RadiatingSurface'}, 'Region absolute padding 20mm sáu hướng; Open1 readback.');
            s.Diagnostics.CurrentStep = 'CHECK_18';
            mesh = s.module('MeshSetup');
            s.call(mesh, 'InitialMeshSettings', {'NAME:MeshSettings', ...
                                                 {'NAME:GlobalSurfApproximation', 'CurvedSurfaceApproxChoice:=', 'UseSlider', 'SliderMeshSettings:=', 5}, ...
                                                 {'NAME:GlobalCurvilinear', 'Apply:=', false}, {'NAME:GlobalModelRes', 'UseAutoLength:=', true}, ...
                                                 'MeshMethod:=', 'Auto', 'UseLegacyFaceterForTauVolumeMesh:=', false, ...
                                                 'DynamicSurfaceResolution:=', false, 'UseFlexMeshingForTAUvolumeMesh:=', false, ...
                                                 'UseAlternativeMeshMethodsAsFallBack:=', true, 'AllowPhiForLayeredGeometry:=', true});
            s.call(s.module('AnalysisSetup'), 'InsertSetup', 'HfssDriven', HFSSSimulationSetup.setupArgs(cfg));
            s.call(s.module('AnalysisSetup'), 'InsertFrequencySweep', 'Setup1', HFSSSimulationSetup.sweepArgs(cfg));
            spheres = {'3D', {'0deg', '180deg', '2deg', '-180deg', '180deg', '2deg'}; ...
                       'Elevation', {'-180deg', '180deg', '1deg', '0deg', '90deg', '90deg'}; ...
                       'Azimuth', {'90deg', '90deg', '0deg', '-180deg', '180deg', '1deg'}};
            keys = {'ThetaStart', 'ThetaStop', 'ThetaStep', 'PhiStart', 'PhiStop', 'PhiStep'};
            for k = 1:3
                a = {['NAME:' spheres{k, 1}], 'UseCustomRadiationSurface:=', false, ...
                     'CSDefinition:=', 'Theta-Phi', 'Polarization:=', 'Linear'};
                for j = 1:6
                    a = [a, {[keys{j} ':='], spheres{k, 2}{j}}];
                end %#ok<AGROW>
                a = [a, {'UseLocalCS:=', false}];
                s.call(s.module('RadField'), 'InsertInfiniteSphereSetup', a);
            end
            HFSSSimulationSetup.excite(s, cfg);
            setups = HFSSCOMConnection.list(s.call(s.module('AnalysisSetup'), 'GetSetups'));
            assert(ismember('Setup1', setups), 'Vivaldi:Setup', 'Setup1 chưa được tạo.');
            s.Diagnostics.checkpoint('CHECK_18', {'Setup1', 'Sweep', '3D', 'Elevation', 'Azimuth'}, ...
                                     'Solver commands executed; saved NoArray is checked on explicit Save. No analysis run.');
        end

        function a = setupArgs(c)
            a = {'NAME:Setup1', 'AdaptMultipleFreqs:=', false, 'PortsOnly:=', false, ...
                 'Frequency:=', sprintf('%.17gGHz', c.adaptiveGHz), 'MaxDeltaS:=', c.deltaS, ...
                 'UseMatrixConv:=', false, 'MaximumPasses:=', c.maximumPasses, ...
                 'MinimumPasses:=', c.minimumPasses, 'MinimumConvergedPasses:=', min(3, c.maximumPasses), ...
                 'PercentRefinement:=', 10, 'IsEnabled:=', true, {'NAME:MeshLink', 'ImportMesh:=', false}, ...
                 'BasisOrder:=', 1, 'DoLambdaRefine:=', true, 'DoMaterialLambda:=', true, ...
                 'SetLambdaTarget:=', false, 'Target:=', .3333, 'UseMaxTetIncrease:=', false, ...
                 'PortAccuracy:=', 2, 'UseABCOnPort:=', false, 'SetPortMinMaxTri:=', false, ...
                 'UseDomains:=', false, 'UseIterativeSolver:=', false, 'SaveRadFieldsOnly:=', false, ...
                 'SaveAnyFields:=', true, 'IESolverType:=', 'Auto', 'LambdaTargetForIESolver:=', .15, ...
                 'UseDefaultLambdaTgtForIESolver:=', true, 'IE Solver Accuracy:=', 'Balanced'};
        end

        function a = sweepArgs(c)
            a = {'NAME:Sweep', 'IsEnabled:=', true, 'RangeType:=', 'LinearStep', ...
                 'RangeStart:=', sprintf('%.17gGHz', c.startGHz), 'RangeEnd:=', sprintf('%.17gGHz', c.stopGHz), ...
                 'RangeStep:=', sprintf('%.17gGHz', c.stepGHz), 'Type:=', 'Discrete', 'SaveFields:=', true, 'SaveRadFields:=', true};
        end

        function excite(s, c)
            HFSSSimulationSetup.validate(c);
            a = {{'IncludePortPostProcessing:=', false, 'SpecifySystemPower:=', false}};
            for k = 1:2
                a{end + 1} = {'Name:=', sprintf('%d:1', k), 'Magnitude:=', sprintf('%.17gW', c.powerW(k)), ...
                              'Phase:=', sprintf('%.17gdeg', c.phaseDeg(k))}; %#ok<AGROW>
            end
            s.call(s.module('Solutions'), 'EditSources', a);
        end

        function apply(manager, c)
            HFSSSimulationSetup.validate(c);
            manager.assertIdentity();
            assert(manager.Healthy, 'Vivaldi:UnsafeSolver', 'Geometry cần validate trước.');
            % Mark stale BEFORE the first mutation, including partial failures.
            manager.ResultsState = 'RESULTS OUTDATED — RE-SIMULATION REQUIRED';
            manager.ResultSignature = '';
            manager.Dirty = true;
            s = manager.Session;
            s.call(s.module('AnalysisSetup'), 'EditSetup', 'Setup1', HFSSSimulationSetup.setupArgs(c));
            s.call(s.module('AnalysisSetup'), 'EditFrequencySweep', 'Setup1', 'Sweep', HFSSSimulationSetup.sweepArgs(c));
            HFSSSimulationSetup.excite(s, c);
        end

        function run(manager, c)
            manager.assertIdentity();
            report = manager.validate(manager.LastValid);
            assert(strcmp(report.status, 'PASS'), 'Vivaldi:UnsafeSolve', '%s', report.message);
            HFSSSimulationSetup.apply(manager, c);
            s = manager.Session;
            % Synchronous COM: may block MATLAB while HFSS solves. No AnalyzeAll.
            s.call(s.Design, 'Analyze', 'Setup1');
            % Return from Analyze alone is insufficient: query actual nominal data.
            HFSSResultExporter.requireData(s, 'Modal Solution Data', 'Setup1 : Sweep', {}, ...
                                           {'Freq:=', {'All'}}, {'mag(S(1,1))', 'mag(S(2,2))', 'mag(S(2,1))', 'mag(S(1,2))'});
            HFSSVariableManager.verify(s, manager.LastValid);
            manager.ResultsState = 'SIMULATED — ACTUAL DATA AVAILABLE (check HFSS convergence)';
            manager.ResultSignature = jsonencode(manager.LastValid);
            s.Diagnostics.record('SIMULATION', 'PASS', {}, ...
                                 'Analyze Setup1 returned and real S data read back. Convergence must be reviewed in HFSS.');
        end

    end
end
