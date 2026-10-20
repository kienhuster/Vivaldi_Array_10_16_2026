function HFSSFlareBuilder(s)
    % Preserve the unrotated short copy before trimming and rotating the original.
    HFSSCAD.wcs(s, 'Global');
    ends = {'L_flare', 'slot_t_L'};
    for k = 1:2
        s.Diagnostics.CurrentStep = sprintf('CHECK_%02d', k + 1);
        name = sprintf('EquationSurface%d', k);
        s.call(s.Editor, 'CreateEquationSurface', {'NAME:EquationBasedSurfaceParameters', ...
                                                   'XuvFunction:=', '_v*((slot_feed_w/2)*exp((_u)*r_flare))', ...
                                                   'YuvFunction:=', '0', 'ZuvFunction:=', '_u', 'uStart:=', '0', 'uEnd:=', ends{k}, ...
                                                   'vStart:=', '-1', 'vEnd:=', '1', 'Version:=', 1}, HFSSCAD.attributes(name, 'vacuum', true));
        HFSSCAD.requireNames(s, {name});
        faces = HFSSCAD.numbers(s.call(s.Editor, 'GetFaceIDs', name));
        assert(~isempty(faces), 'Vivaldi:EquationSurface', 'EquationSurface không có mặt.');
        s.Diagnostics.checkpoint(sprintf('CHECK_%02d', k + 1), {name}, 'Equation surface tồn tại và có faces.');
    end
    s.Diagnostics.CurrentStep = 'CHECK_04';
    HFSSCAD.clone(s, 'EquationSurface2', 'EquationSurface2_1', false);
    HFSSCAD.subtract(s, 'EquationSurface1', 'EquationSurface2_1');
    HFSSCAD.requireNames(s, {'EquationSurface1', 'EquationSurface2'}, true);
    s.Diagnostics.checkpoint('CHECK_04', HFSSCAD.names(s), 'Đã giữ short flare gốc sau clone/subtract.');
    s.Diagnostics.CurrentStep = 'CHECK_05';
    HFSSCAD.wcs(s, 'slot_t_td');
    s.call(s.Editor, 'Rotate', HFSSCAD.select('EquationSurface2'), ...
           {'NAME:RotateParameters', 'RotateAxis:=', 'Y', 'RotateAngle:=', 'deg_slot_t'});
    HFSSCAD.requireNames(s, {'EquationSurface2'});
    s.Diagnostics.checkpoint('CHECK_05', {'EquationSurface2'}, 'Rotate quanh slot_t_td Y; hướng từ source.');
end
