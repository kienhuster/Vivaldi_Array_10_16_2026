function report = runCOMCompatibilityTests(outputDir, progID)
    % Run on Windows MATLAB + HFSS before accepting nested SAFEARRAY compatibility.
    root = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(root, 'core'), fullfile(root, 'com'), fullfile(root, 'results'));
    if nargin < 1
        outputDir = fullfile(root, 'logs');
    end
    if nargin < 2
        progID = '';
    end
    if ~isfolder(outputDir)
        mkdir(outputDir);
    end
    report = struct('status', 'PENDING', 'message', 'PENDING — requires Windows MATLAB + HFSS', ...
                    'time', datestr(now, 30), 'checks', {{}}, 'projectPath', '', 'HFSSVersion', '');
    if ~ispc || exist('actxserver', 'file') == 0
        vivaldiWriteJSON(fullfile(outputDir, 'com-compatibility.json'), report);
        return
    end
    [~, token] = fileparts(tempname);
    projectPath = fullfile(outputDir, ['COM_Compatibility_' token '.aedt']);
    log = HFSSDiagnostics(fullfile(outputDir, ['COM_' token '.txt']));
    s = HFSSCOMConnection(log);
    createdName = '';
    cleanup = onCleanup(@closeTestOnly); %#ok<NASGU>
    try
        s.connect(true, progID);
        report.HFSSVersion = s.Version;
        project = s.call(s.Desktop, 'NewProject');
        createdName = char(s.call(project, 'GetName'));
        s.call(project, 'InsertDesign', 'HFSS', 'COM_Compatibility', 'DrivenModal', '');
        s.bind(project, 'COM_Compatibility');
        s.call(s.Design, 'ChangeProperty', {'NAME:AllTabs', {'NAME:LocalVariableTab', ...
                                                             {'NAME:PropServers', 'LocalVariables'}, {'NAME:NewProps', ...
                                                                                                   {'NAME:probe_length', 'PropType:=', 'VariableProp', 'UserDef:=', true, 'Value:=', '10mm'}}}});
        s.call(s.Editor, 'SetModelUnits', {'NAME:Units Parameter', 'Units:=', 'mm', 'Rescale:=', false});
        HFSSCAD.box(s, 'COM_Probe', {'0mm', '0mm', '0mm'}, {'probe_length', '4mm', '3mm'}, 'vacuum');
        before = HFSSCAD.bounds(s, 'COM_Probe');
        assert(abs(before(1, 2) - 10) < 1e-6);
        s.call(s.Design, 'ChangeProperty', {'NAME:AllTabs', {'NAME:LocalVariableTab', ...
                                                             {'NAME:PropServers', 'LocalVariables'}, {'NAME:ChangedProps', ...
                                                                                                   {'NAME:probe_length', 'Value:=', '12.345mm'}}}});
        after = HFSSCAD.bounds(s, 'COM_Probe');
        assert(abs(after(1, 2) - 12.345) < 1e-6);
        assert(strcmp(char(s.call(s.Design, 'GetVariableValue', 'probe_length')), '12.345mm'));
        assert(HFSSCAD.containsPoint(s, 'COM_Probe', [5 2 1]));
        assert(~HFSSCAD.containsPoint(s, 'COM_Probe', [20 2 1]));
        report.checks = {'registered ProgID/version', 'NewProject/InsertDesign', 'nested cell ChangeProperty', ...
                         'direct CreateBox', 'object name readback', 'variable write/readback', 'geometry dimension changed', 'solid membership positive/negative'};
        % Verify point queries on sheets BEFORE the main builder relies on them.
        HFSSCAD.wcs(s, 'Global');
        HFSSCAD.rectangle(s, 'COM_Sheet', '20mm', '0mm', '10mm', '10mm', 'vacuum');
        HFSSCAD.rectangle(s, 'COM_Cutter', '23mm', '3mm', '4mm', '4mm', 'vacuum');
        HFSSCAD.subtract(s, 'COM_Sheet', 'COM_Cutter');
        assert(~HFSSCAD.containsPoint(s, 'COM_Sheet', [25 0 5]), 'Sheet hole membership failed.');
        assert(HFSSCAD.containsPoint(s, 'COM_Sheet', [21 0 5]), 'Sheet metal membership unsupported/failed.');
        report.checks{end + 1} = 'sheet positive/negative topology queries after Subtract';
        s.call(s.Editor, 'ThickenSheet', HFSSCAD.select('COM_Sheet'), ...
               {'NAME:SheetThickenParameters', 'Thickness:=', '2mm', 'BothSides:=', true});
        assert(HFSSCAD.containsPoint(s, 'COM_Sheet', [21 .9 5]) && ~HFSSCAD.containsPoint(s, 'COM_Sheet', [21 1.1 5]));
        assert(HFSSCAD.containsPoint(s, 'COM_Sheet', [21 -.9 5]) && ~HFSSCAD.containsPoint(s, 'COM_Sheet', [21 -1.1 5]));
        assert(~HFSSCAD.containsPoint(s, 'COM_Sheet', [25 0 5]));
        report.checks{end + 1} = 'BothSides total thickness and preserved void';
        s.call(project, 'SaveAs', projectPath, true);
        createdName = char(s.call(project, 'GetName'));
        assert(isfile(projectPath), 'HFSS did not save compatibility project.');
        report.projectPath = projectPath;
        s.call(s.Desktop, 'CloseProject', createdName);
        createdName = '';
        report.checks{end + 1} = 'SaveAs and close only the test project';
        report.status = 'PASS';
        report.message = 'Direct COM basic/SAFEARRAY compatibility verified on this machine. Main antenna CAD acceptance is separate.';
    catch ex
        report.status = 'FAIL';
        report.message = [ex.identifier ': ' ex.message];
    end
    log.export(fullfile(outputDir, ['COM_' token '_diagnostics.json']));
    vivaldiWriteJSON(fullfile(outputDir, 'com-compatibility.json'), report);

    function closeTestOnly()
        if ~isempty(createdName) && s.Connected
            try
                s.call(s.Desktop, 'CloseProject', createdName);
            catch
            end
        end
        s.disconnect();
    end

end
