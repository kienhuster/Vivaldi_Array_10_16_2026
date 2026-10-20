function HFSSPortBuilder(s)
    s.Diagnostics.CurrentStep = 'CHECK_16';
    HFSSCAD.wcs(s, 'Global');
    boundary = s.module('BoundarySetup');
    c = '-x_feed-positionx+slot_feed_w+h2';
    z = 'z_feed-h3_slot_feed-h_cabin';
    c2 = '(aperture_w+thickness)/2';
    y2 = '(aperture_w+thickness)/2+x_feed+positionx-slot_feed_w-h2';
    starts = {{[c '-r_cabmid'], '0mm', z}, {c2, [y2 '+r_cabmid'], z}};
    ends = {{[c '-r_cabin'], '0mm', z}, {c2, [y2 '+r_cabin'], z}};
    for k = 1:2
        name = num2str(k);
        sheet = ['port' name];
        args = {['NAME:' name], 'Objects:=', {sheet}, 'DoDeembed:=', false, 'RenormalizeAllTerminals:=', true, ...
                {'NAME:Modes', {'NAME:Mode1', 'ModeNum:=', 1, 'UseIntLine:=', true, ...
                              {'NAME:IntLine', 'Start:=', starts{k}, 'End:=', ends{k}}, ...
                              'AlignmentGroup:=', 0, 'CharImp:=', 'Zpi', 'RenormImp:=', '50ohm'}}, ...
                'ShowReporterFilter:=', false, 'ReporterFilter:=', {true}, 'Impedance:=', '50ohm'};
        s.call(boundary, 'AssignLumpedPort', args);
    end
    actual = HFSSCOMConnection.list(s.call(boundary, 'GetExcitations'));
    assert(numel(actual) == 4 && all(ismember({'1', '2', 'Lumped Port'}, actual)), ...
           'Vivaldi:Ports', 'Không đọc lại được đúng hai Lumped Ports.');
    s.Diagnostics.checkpoint('CHECK_16', {'port1', 'port2'}, '2 Lumped Ports 50ohm; integration line outer-to-inner.');
    s.Diagnostics.record('PORT_FIELD_PHASE', 'PENDING', {'port1', 'port2'}, ...
                         'Azimuth integration line tái dựng từ geometry; phải so pha field với mô hình gốc trong HFSS.');
end
