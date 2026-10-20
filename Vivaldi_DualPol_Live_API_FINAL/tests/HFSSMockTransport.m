classdef HFSSMockTransport < handle
    % Protocol-only double. This class does NOT emulate or validate HFSS CAD.
    properties
        Values
        Solids = {}
        Sheets = {}
        Lines = {}
        Copied = ''
        WorkingPath = ''
        FailUpdateValue = NaN
        FailPartialValue = NaN
        FailRollback = false
        Disconnected = false
    end
    methods

        function o = HFSSMockTransport(p, path)
            g = vivaldiCalculateGeometry(p);
            o.Values = containers.Map(g.expressions(:, 1), g.expressions(:, 2));
            o.WorkingPath = path;
        end

        function varargout = dispatch(o, target, method, varargin)
            if o.Disconnected
                error('Mock:Disconnected', 'Injected lost COM handle.');
            end
            value = [];
            switch method
                case 'GetVersion'
                    value = '2021.2.0';
                case 'GetName'
                    if strcmp(target, 'design')
                        value = 'dual_pol_vivaldi_patch_Wflare_20';
                    else
                        [~, value] = fileparts(o.WorkingPath);
                    end
                case 'GetPath'
                    value = fileparts(o.WorkingPath);
                case 'GetModule'
                    value = varargin{1};
                case 'GetModelUnits'
                    value = 'mm';
                case 'GetVariableValue'
                    value = o.Values(varargin{1});
                case 'ChangeProperty'
                    a = varargin{1};
                    tab = a{2};
                    props = tab{3};
                    if strcmp(tab{1}, 'NAME:LocalVariableTab')
                        for k = 2:numel(props)
                            prop = props{k};
                            name = prop{1}(6:end);
                            index = find(strcmp(prop, 'Value:='), 1);
                            o.Values(name) = prop{index + 1};
                        end
                        v = HFSSVariableManager.parseLiteral(o.Values('L_flare_1'), 'mm');
                        if v == o.FailPartialValue
                            o.FailPartialValue = NaN;
                            error('Mock:PartialMutation', 'Injected error AFTER changing variables.');
                        end
                    elseif strcmp(tab{1}, 'NAME:Geometry3DAttributeTab')
                        old = tab{2}{2};
                        new = props{2}{3};
                        o.Solids = strrep(o.Solids, old, new);
                        o.Sheets = strrep(o.Sheets, old, new);
                        o.Lines = strrep(o.Lines, old, new);
                    end
                case 'GetObjectsInGroup'
                    switch varargin{1}
                        case 'Solids'
                            value = o.Solids;
                        case 'Sheets'
                            value = o.Sheets;
                        case 'Lines'
                            value = o.Lines;
                        case 'Unclassified'
                            value = {};
                    end
                case 'GetFaceIDs'
                    value = [101 102];
                case 'CreateEquationSurface'
                    o.Sheets{end + 1} = varargin{2}{3};
                case 'CreateRectangle'
                    o.Lines{end + 1} = varargin{2}{3};
                case 'CoverLines'
                    name = varargin{1}{3};
                    o.Lines = setdiff(o.Lines, {name});
                    o.Sheets{end + 1} = name;
                case 'Copy'
                    o.Copied = varargin{1}{3};
                case 'Paste'
                    o.addCopy(o.Copied);
                case 'DuplicateAroundAxis'
                    o.addCopy(varargin{1}{3});
                case 'Subtract'
                    tools = strsplit(varargin{1}{5}, ',');
                    o.Sheets = setdiff(o.Sheets, tools);
                    o.Solids = setdiff(o.Solids, tools);
                case 'Unite'
                    names = strsplit(varargin{1}{3}, ',');
                    o.Sheets = setdiff(o.Sheets, names(2:end));
                    o.Solids = setdiff(o.Solids, names(2:end));
                case {'SetWCS', 'Rotate', 'Move'}
                    % Dispatch acknowledgement only. No geometry is computed.
                otherwise
                    error('Mock:Unsupported', 'Unexpected call: %s', method);
            end
            if nargout > 0
                varargout{1} = value;
            end
        end

        function addCopy(o, name)
            if ismember(name, o.Sheets)
                o.Sheets{end + 1} = [name '_auto'];
            elseif ismember(name, o.Solids)
                o.Solids{end + 1} = [name '_auto'];
            else
                error('Mock:Copy', 'Unknown mock source.');
            end
        end

        function report = validate(o, ~, p)
            % Explicit injected predicate tests rollback mechanics only.
            fail = p.L_flare_1 == o.FailUpdateValue || o.FailRollback;
            if fail
                status = 'FAIL';
            else
                status = 'PASS';
            end
            report = struct('status', status, 'message', 'TEST DOUBLE — NOT HFSS CAD VALIDATION');
        end

    end
end
