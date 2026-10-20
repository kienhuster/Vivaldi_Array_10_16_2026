function HFSSMaterials(s)
    % Source electromagnetic properties only; no additional substrate/dielectric.
    manager = s.call(s.Project, 'GetDefinitionManager');
    existing = HFSSCOMConnection.list(s.call(manager, 'GetProjectMaterialNames'));
    materials = {'aluminum', '1.000021', '38000000'; 'copper', '0.999991', '58000000'; 'vacuum', '1', '0'};
    for k = 1:size(materials, 1)
        name = materials{k, 1};
        args = {['NAME:' name], 'CoordinateSystemType:=', 'Cartesian', 'BulkOrSurfaceType:=', 1, ...
                {'NAME:PhysicsTypes', 'set:=', {'Electromagnetic'}}, 'permittivity:=', '1', ...
                'permeability:=', materials{k, 2}, 'conductivity:=', materials{k, 3}};
        if ismember(name, existing)
            s.call(manager, 'EditMaterial', name, args);
        else
            s.call(manager, 'AddMaterial', args);
        end
    end
end
