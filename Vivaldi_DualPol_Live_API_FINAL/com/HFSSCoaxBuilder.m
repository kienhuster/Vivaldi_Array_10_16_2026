function HFSSCoaxBuilder(s, p)
    s.Diagnostics.CurrentStep = 'CHECK_13';
    HFSSCAD.wcs(s, 'slot_feed_td');
    HFSSCAD.cylinder(s, 'cable_in', 'r_cabin', '-h3_slot_feed', '-h_cabin', 'copper');
    HFSSCAD.cylinder(s, 'cable_out', 'r_cabout', '-h3_slot_feed-slot_feed_w', '-h_cabout', 'copper');
    HFSSCAD.cylinder(s, 'cable_mid', 'r_cabmid', '-h3_slot_feed-slot_feed_w', '-h_cabout', 'vacuum');
    s.call(s.Editor, 'CreateCircle', {'NAME:CircleParameters', 'IsCovered:=', false, ...
                                      'XCenter:=', '-positionx+slot_feed_w+h2', 'YCenter:=', '0mm', ...
                                      'ZCenter:=', '-h3_slot_feed-h_cabin', 'Radius:=', 'r_cabmid', 'WhichAxis:=', 'Z', 'NumSegments:=', '0'}, ...
           HFSSCAD.attributes('port1', 'vacuum', true));
    s.call(s.Editor, 'CoverLines', HFSSCAD.select('port1'));
    s.Diagnostics.checkpoint('CHECK_13', {'cable_in', 'cable_out', 'cable_mid', 'port1'}, 'Coax thứ nhất và port sheet; hollowing tiếp theo.');
    s.Diagnostics.CurrentStep = 'CHECK_14';
    HFSSCAD.wcs(s, 'RelativeCS1');
    sources = {'cable_in', 'cable_out', 'cable_mid', 'port1'};
    targets = {'cable_in_1', 'cable_out_1', 'cable_mid_1', 'port2'};
    for k = 1:4
        HFSSCAD.clone(s, sources{k}, targets{k}, true);
        HFSSCAD.moveSecond(s, targets{k});
    end
    s.Diagnostics.checkpoint('CHECK_14', targets, 'Duplicate quanh RelativeCS1, Move=thickness cho cả middle cutter.');
    s.Diagnostics.CurrentStep = 'CHECK_15';
    % Capture full solid outer cylinders, NOT the already hollow copper shells.
    sources = {'cable_in', 'cable_in_1', 'cable_mid', 'cable_mid_1', 'cable_out', 'cable_out_1'};
    cutters = {'cable_in_2', 'cable_in_1_1', 'cable_mid_2', 'cable_mid_1_1', 'cable_out_2', 'cable_out_1_1'};
    for k = 1:6
        HFSSCAD.clone(s, sources{k}, cutters{k}, false);
    end
    HFSSCAD.subtract(s, 'cable_out', 'cable_mid');
    HFSSCAD.subtract(s, 'cable_out_1', 'cable_mid_1');
    HFSSCAD.subtract(s, 'Vivaldi_1', strjoin(cutters, ','));
    HFSSCAD.requireNames(s, {'Vivaldi_1', 'cable_in', 'cable_out', 'cable_in_1', 'cable_out_1', 'port1', 'port2'}, true);
    HFSSCAD.wcs(s, 'Global');
    HFSSGeometryValidator.assertCoax(s, p);
    HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 1, true);
    HFSSGeometryValidator.assertFlare(s, p, 'Vivaldi_1', 2, true);
    s.Diagnostics.checkpoint('CHECK_15', HFSSCAD.names(s), ...
                             '6 full cutters consumed; 4 active copper conductors retained; hollow volume/port checks passed.');
end
