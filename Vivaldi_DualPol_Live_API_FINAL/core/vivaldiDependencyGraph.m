function graph = vivaldiDependencyGraph(p)
    % Mục đích: mô tả quan hệ phụ thuộc biểu thức và CAD, không chạy eval.
    if nargin < 1
        p = vivaldiDefaultParams();
    end
    g = vivaldiCalculateGeometry(p);
    names = fieldnames(p);
    graph = struct('name', {}, 'kind', {}, 'dependsOn', {}, 'expression', {});
    for k = 1:size(g.expressions, 1)
        n = g.expressions{k, 1};
        expression = g.expressions{k, 2};
        deps = {};
        if ismember(n, names)
            kind = 'independent';
        else
            kind = 'derived';
        end
        tokens = regexp(expression, '[A-Za-z][A-Za-z0-9_]*', 'match');
        for j = 1:numel(tokens)
            if ismember(tokens{j}, g.expressions(:, 1))
                deps{end + 1} = tokens{j};
            end %#ok<AGROW>
        end
        graph(end + 1) = struct('name', n, 'kind', kind, 'dependsOn', {unique(deps)}, 'expression', expression); %#ok<AGROW>
    end
    cad = { 'slot_t_td', {'slot_feed_w', 'slot_t_L', 'r_flare'}; ...
           'slot_feed_td', {'x_feed', 'z_feed'}; 'patch_td', {'aperture_w', 'L_flare'}; ...
           'RelativeCS1', {'patch_td', 'thickness'}; ...
           'EquationSurface1', {'slot_feed_w', 'r_flare', 'L_flare'}; ...
           'EquationSurface2', {'slot_feed_w', 'r_flare', 'slot_t_L', 'slot_t_td', 'deg_slot_t'}; ...
           'SlotCavity', {'slot_feed_td', 'h3_slot_feed', 'slot_feed_w', 'h2', 'cavity_w', 'cavity_L'}; ...
           'Vivaldi_1', {'patch_td', 'L_patch', 'aperture_w', 'EquationSurface1', 'EquationSurface2', 'SlotCavity', 'thickness'}; ...
           'Vivaldi_2', {'Vivaldi_1', 'RelativeCS1', 'thickness'}; ...
           'BaseBridge', {'de_L', 'de_W', 'h_de', 'z_feed', 'RelativeCS1', 'thickness', 'L_patch'}; ...
           'Coax1', {'slot_feed_td', 'positionx', 'slot_feed_w', 'h2', 'h3_slot_feed', 'r_cabin', 'r_cabmid', 'r_cabout', 'h_cabin', 'h_cabout'}; ...
           'Coax2', {'Coax1', 'RelativeCS1', 'thickness'}; 'Ports', {'Coax1', 'Coax2', 'r_cabmid'}; ...
           'Region', {'Vivaldi_1', 'Vivaldi_2', 'BaseBridge', 'Coax1', 'Coax2'}; ...
           'SolverResults', {'Ports', 'Region', 'Vivaldi_1', 'Vivaldi_2', 'BaseBridge'}};
    for k = 1:size(cad, 1)
        graph(end + 1) = struct('name', cad{k, 1}, 'kind', 'CAD', 'dependsOn', {cad{k, 2}}, 'expression', 'HFSS parametric history'); %#ok<AGROW>
    end
end
