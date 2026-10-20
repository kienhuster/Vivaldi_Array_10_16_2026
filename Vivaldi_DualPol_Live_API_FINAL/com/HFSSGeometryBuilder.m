function report = HFSSGeometryBuilder(s, p)
    % From an empty design using only direct COM commands.
    [ok, errors] = vivaldiValidateParams(p);
    assert(ok, 'Vivaldi:Parameters', '%s', strjoin(errors, newline));
    s.Diagnostics.Parameters = p;
    try
        HFSSCAD.requireNames(s, {}, true);
        HFSSVariableManager.create(s, p);
        HFSSMaterials(s);
        HFSSCoordinateBuilder(s, p);
        HFSSFlareBuilder(s);
        HFSSCavityBuilder(s);
        s.Diagnostics.CurrentStep = 'CHECK_08';
        HFSSCAD.wcs(s, 'patch_td');
        HFSSCAD.rectangle(s, 'Vivaldi_1', '0mm', '0mm', '-L_patch', '-aperture_w', 'aluminum');
        HFSSCAD.subtract(s, 'Vivaldi_1', 'EquationSurface1');
        HFSSCAD.wcs(s, 'Global');
        HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 1, false);
        HFSSGeometryValidator.assertCavity(s, p, false);
        s.Diagnostics.checkpoint('CHECK_08', {'Vivaldi_1'}, 'Đã probe flare + slot + cavity rỗng trên sheet; hai mép còn metal.');
        s.Diagnostics.CurrentStep = 'CHECK_09';
        s.call(s.Editor, 'ThickenSheet', HFSSCAD.select('Vivaldi_1'), ...
               {'NAME:SheetThickenParameters', 'Thickness:=', 'thickness', 'BothSides:=', true});
        HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 1, true);
        s.Diagnostics.checkpoint('CHECK_09', {'Vivaldi_1'}, 'Flare rỗng sau symmetric Thicken; inside/outside thickness probes passed.');
        HFSSDualPolBuilder(s, p);
        HFSSCoaxBuilder(s, p);
        report = HFSSGeometryValidator.run(s, p, false);
        assert(strcmp(report.status, 'PASS'), 'Vivaldi:Geometry', 'Geometry chưa được xác nhận: %s', report.message);
    catch ex
        s.Diagnostics.record('BUILD_STOPPED', 'FAIL', {}, ex.message);
        rethrow(ex);
    end
end
