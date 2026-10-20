function HFSSDualPolBuilder(s, p)
    s.Diagnostics.CurrentStep = 'CHECK_10';
    HFSSCAD.wcs(s, 'RelativeCS1');
    HFSSCAD.clone(s, 'Vivaldi_1', 'Vivaldi_2', true);
    HFSSCAD.moveSecond(s, 'Vivaldi_2');
    HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_2', 2, true);
    s.Diagnostics.checkpoint('CHECK_10', {'Vivaldi_1', 'Vivaldi_2'}, 'Đã probe lỗ và hai mép tấm thứ hai sau Rotate/Move.');
    HFSSCAD.wcs(s, 'RelativeCS1');
    s.Diagnostics.CurrentStep = 'CHECK_11';
    HFSSCAD.box(s, 'Box1', {'0mm', '0mm', '0mm'}, {'thickness', 'thickness', '-L_patch'}, 'aluminum');
    HFSSCAD.wcs(s, 'Global');
    HFSSCAD.box(s, 'De', {'(de_L+thickness)/2', '-(de_W-aperture_w)/2', 'z_feed-h3_slot_feed-slot_feed_w'}, ...
                {'-de_L', 'de_W', '-h_de'}, 'aluminum');
    s.Diagnostics.checkpoint('CHECK_11', {'Box1', 'De'}, 'Connector và base đã tạo trong CS nguồn.');
    s.Diagnostics.CurrentStep = 'CHECK_12';
    HFSSCAD.unite(s, {'Vivaldi_1', 'Vivaldi_2', 'Box1', 'De'});
    HFSSCAD.requireNames(s, {'Vivaldi_1'}, true);
    HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 1, true);
    HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 2, true);
    s.Diagnostics.checkpoint('CHECK_12', {'Vivaldi_1'}, 'Cả hai flare vẫn rỗng và có metal hai bên sau Unite.');
end
