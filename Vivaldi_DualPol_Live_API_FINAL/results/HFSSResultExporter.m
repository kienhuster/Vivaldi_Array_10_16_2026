classdef HFSSResultExporter
    methods (Static)

        function families = nominalFamilies(extra)
            names = fieldnames(vivaldiDefaultParams());
            families = {};
            for k = 1:numel(names)
                families = [families, {[names{k} ':='], {'Nominal'}}];
            end %#ok<AGROW>
            families = [families, extra];
        end

        function requireData(s, category, solution, context, extra, expressions)
            values = s.call(s.module('ReportSetup'), 'GetSolutionDataPerVariation', category, solution, ...
                            context, HFSSResultExporter.nominalFamilies(extra), expressions);
            if ~iscell(values)
                values = {values};
            end
            assert(~isempty(values), 'Vivaldi:NoSolution', 'Không có dữ liệu nghiệm thực.');
            for e = 1:numel(expressions)
                found = false;
                for k = 1:numel(values)
                    if isempty(values{k})
                        continue
                    end
                    data = s.call(values{k}, 'GetRealDataValues', expressions{e}, false);
                    numbers = HFSSCAD.numbers(data);
                    if ~isempty(numbers)
                        found = true;
                    end
                end
                assert(found, 'Vivaldi:NoSolution', 'Chưa có dữ liệu thực cho %s / %s.', expressions{e}, solution);
            end
        end

        function output = export(manager, c, folder)
            manager.assertIdentity();
            HFSSVariableManager.verify(manager.Session, manager.LastValid);
            assert(strcmp(manager.ResultSignature, jsonencode(manager.LastValid)) && ...
                   startsWith(manager.ResultsState, 'SIMULATED'), 'Vivaldi:StaleResults', ...
                   'Chạy mô phỏng hiện tại trước khi export tự động. Có thể import CSV riêng với provenance chưa xác định.');
            assert(isfolder(folder), 'Vivaldi:ResultsFolder', 'Thư mục kết quả chưa tồn tại.');
            s = manager.Session;
            solution = 'Setup1 : Sweep';
            frequency = sprintf('%.17gGHz', c.fieldGHz);
            [~, token] = fileparts(tempname);
            prefix = ['Live_' token];
            output = struct('files', {{}}, 'unavailable', {{}}, 'metadata', '');
            modal = {'Freq:=', {'All'}};
            elevation = {'Freq:=', {frequency}, 'Theta:=', {'All'}, 'Phi:=', {'0deg'}};
            azimuth = {'Freq:=', {frequency}, 'Theta:=', {'90deg'}, 'Phi:=', {'All'}};
            full = {'Freq:=', {frequency}, 'Theta:=', {'All'}, 'Phi:=', {'All'}};
            specs = { ...
                     'SParameters', 'Modal Solution Data', 'Rectangular Plot', {}, modal, 'Freq', {'dB(S(1,1))', 'dB(S(2,2))', 'dB(S(2,1))', 'dB(S(1,2))'}; ...
                     'VSWR', 'Modal Solution Data', 'Rectangular Plot', {}, modal, 'Freq', {'VSWR(1)', 'VSWR(2)'}; ...
                     'Impedance', 'Modal Solution Data', 'Rectangular Plot', {}, modal, 'Freq', {'re(Z(1,1))', 'im(Z(1,1))', 're(Z(2,2))', 'im(Z(2,2))'}; ...
                     'RealizedGain', 'Far Fields', 'Rectangular Plot', {'Context:=', 'Elevation'}, elevation, 'Theta', {'dB(RealizedGainTotal)'}; ...
                     'Elevation', 'Far Fields', 'Radiation Pattern', {'Context:=', 'Elevation'}, elevation, 'Theta', {'dB(RealizedGainTotal)'}; ...
                     'Azimuth', 'Far Fields', 'Radiation Pattern', {'Context:=', 'Azimuth'}, azimuth, 'Phi', {'dB(RealizedGainTotal)'}; ...
                     'Pattern3D', 'Far Fields', '3D Polar Plot', {'Context:=', '3D'}, full, 'Phi', {'dB(RealizedGainTotal)'}; ...
                     'Efficiency', 'Antenna Parameters', 'Rectangular Plot', {'Context:=', '3D'}, {'Freq:=', {frequency}}, 'Freq', {'RadiationEfficiency'}};
            for k = 1:size(specs, 1)
                label = specs{k, 1};
                name = [prefix '_' label];
                path = fullfile(folder, [name '.csv']);
                try
                    HFSSResultExporter.requireData(s, specs{k, 2}, solution, specs{k, 4}, specs{k, 5}, specs{k, 7});
                    if strcmp(specs{k, 3}, '3D Polar Plot')
                        components = {'Phi Component:=', 'Phi', 'Theta Component:=', 'Theta', 'Mag Component:=', specs{k, 7}};
                    elseif strcmp(specs{k, 3}, 'Radiation Pattern')
                        components = {'Ang Component:=', specs{k, 6}, 'Mag Component:=', specs{k, 7}};
                    else
                        components = {'X Component:=', specs{k, 6}, 'Y Component:=', specs{k, 7}};
                    end
                    s.call(s.module('ReportSetup'), 'CreateReport', name, specs{k, 2}, specs{k, 3}, solution, ...
                           specs{k, 4}, HFSSResultExporter.nominalFamilies(specs{k, 5}), components);
                    s.call(s.module('ReportSetup'), 'ExportToFile', name, path);
                    d = dir(path);
                    assert(~isempty(d) && d.bytes > 10, 'Vivaldi:EmptyCSV', 'CSV không tồn tại hoặc rỗng.');
                    output.files{end + 1} = path;
                    s.Diagnostics.record(['EXPORT_' label], 'PASS', {}, path);
                catch ex
                    output.unavailable{end + 1} = [label ': ' ex.message];
                    s.Diagnostics.record(['EXPORT_' label], 'UNSUPPORTED', {}, ex.message);
                    if k == 1
                        rethrow(ex);
                    end
                end
            end
            output.metadata = fullfile(folder, [prefix '_metadata.json']);
            vivaldiWriteJSON(output.metadata, struct('project', manager.WorkingPath, 'design', manager.DesignName, ...
                                                     'parameters', manager.LastValid, 'simulation', c, 'time', datestr(now, 30), ...
                                                     'HFSSVersion', s.Version, 'convergence', 'Review HFSS convergence report', ...
                                                     'files', {output.files}, 'unavailable', {output.unavailable}));
        end

    end
end
