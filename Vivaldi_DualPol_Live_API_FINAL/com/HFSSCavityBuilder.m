function HFSSCavityBuilder(s)
    s.Diagnostics.CurrentStep = 'CHECK_06';
    HFSSCAD.wcs(s, 'slot_feed_td');
    HFSSCAD.rectangle(s, 'Rectangle1', '0mm', '0mm', '-h3_slot_feed', 'slot_feed_w', 'vacuum');
    HFSSCAD.rectangle(s, 'Rectangle2', '0mm', '-h3_slot_feed', '-slot_feed_w', 'slot_feed_w+h2+cavity_w', 'vacuum');
    HFSSCAD.rectangle(s, 'Rectangle3', 'slot_feed_w+h2', '-(h3_slot_feed+slot_feed_w)', 'cavity_L', 'cavity_w', 'vacuum');
    s.Diagnostics.checkpoint('CHECK_06', {'Rectangle1', 'Rectangle2', 'Rectangle3'}, 'Width theo Z, Height theo X; CoverLines đã chạy.');
    s.Diagnostics.CurrentStep = 'CHECK_07';
    HFSSCAD.unite(s, {'EquationSurface1', 'EquationSurface2', 'Rectangle1', 'Rectangle2', 'Rectangle3'});
    HFSSCAD.requireNames(s, {'EquationSurface1'}, true);
    s.Diagnostics.checkpoint('CHECK_07', {'EquationSurface1'}, 'Unite cutter; chưa phải chứng minh cavity rỗng trong metal.');
end
