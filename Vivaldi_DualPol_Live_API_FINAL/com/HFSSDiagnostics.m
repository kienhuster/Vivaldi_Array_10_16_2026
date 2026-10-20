classdef HFSSDiagnostics < handle
    % Append evidence with explicit status; a COM dispatch is never CAD proof.
    properties
        Records = struct('time', {}, 'step', {}, 'status', {}, 'executionStatus', {}, 'geometryStatus', {}, 'objects', {}, 'parameters', {}, 'message', {}, 'projectPath', {})
        ProjectPath = ''
        LogPath = ''
        Parameters = struct()
        PauseCallback = []
        CurrentStep = ''
    end
    methods

        function o = HFSSDiagnostics(logPath)
            if nargin > 0
                o.LogPath = logPath;
            end
        end

        function record(o, step, status, objects, message, geometryStatus)
            assert(ismember(status, {'PASS', 'FAIL', 'PENDING', 'UNSUPPORTED'}), 'Vivaldi:Status', 'Sai trạng thái chẩn đoán.');
            if nargin < 4
                objects = {};
            end
            if nargin < 5
                message = '';
            end
            if nargin < 6
                geometryStatus = 'PENDING';
                if strcmp(step, 'GEOMETRY_VALIDATION')
                    geometryStatus = status;
                end
            end
            assert(ismember(geometryStatus, {'PASS', 'FAIL', 'PENDING', 'UNSUPPORTED'}), 'Vivaldi:Status', 'Sai trạng thái geometry.');
            r = struct('time', datestr(now, 30), 'step', step, 'status', status, ...
                       'executionStatus', status, 'geometryStatus', geometryStatus, ...
                       'objects', {objects}, 'parameters', o.Parameters, 'message', message, 'projectPath', o.ProjectPath);
            o.Records(end + 1) = r;
            if ~isempty(o.LogPath)
                fid = fopen(o.LogPath, 'a', 'n', 'UTF-8');
                assert(fid >= 0, 'Vivaldi:Log', 'Không mở được log: %s.', o.LogPath);
                cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
                fprintf(fid, '%s | %s | execution=%s | geometry=%s | %s\n', r.time, step, status, geometryStatus, message);
            end
        end

        function checkpoint(o, step, objects, message)
            o.CurrentStep = step;
            geometryStatus = 'PENDING';
            if ismember(step, {'CHECK_08', 'CHECK_09', 'CHECK_10', 'CHECK_12', 'CHECK_15'})
                geometryStatus = 'PASS';
            end
            o.record(step, 'PASS', objects, message, geometryStatus);
            if ~isempty(o.PauseCallback)
                o.PauseCallback(step, objects);
            end
        end

        function export(o, path)
            vivaldiWriteJSON(path, struct('records', o.Records, 'scope', 'Evidence from this session only'));
        end

    end
end
