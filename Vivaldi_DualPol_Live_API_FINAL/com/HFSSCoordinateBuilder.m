function HFSSCoordinateBuilder(s, p)
    s.Diagnostics.CurrentStep = 'CHECK_01';
    g = vivaldiCalculateGeometry(p);
    s.call(s.Editor, 'SetModelUnits', {'NAME:Units Parameter', 'Units:=', 'mm', 'Rescale:=', false});
    for item = {'slot_t_td', 'slot_feed_td', 'patch_td', 'RelativeCS1'}
        name = item{1};
        cs = g.cs.(name);
        xyz = cs.originExpressions;
        HFSSCAD.wcs(s, cs.parent);
        s.call(s.Editor, 'CreateRelativeCS', {'NAME:RelativeCSParameters', 'Mode:=', 'Axis/Position', ...
                                              'OriginX:=', xyz{1}, 'OriginY:=', xyz{2}, 'OriginZ:=', xyz{3}, ...
                                              'XAxisXvec:=', '1mm', 'XAxisYvec:=', '0mm', 'XAxisZvec:=', '0mm', ...
                                              'YAxisXvec:=', '0mm', 'YAxisYvec:=', '1mm', 'YAxisZvec:=', '0mm'}, ...
               {'NAME:Attributes', 'Name:=', name});
        s.call(s.Editor, 'ChangeProperty', {'NAME:AllTabs', {'NAME:Geometry3DCSTab', ...
                                                             {'NAME:PropServers', name}, {'NAME:ChangedProps', {'NAME:Reference CS', 'Value:=', cs.parent}}}});
        s.call(s.Editor, 'ChangeProperty', {'NAME:AllTabs', {'NAME:Geometry3DCSTab', ...
                                                             {'NAME:PropServers', name}, {'NAME:ChangedProps', ...
                                                                                       {'NAME:Origin', 'X:=', xyz{1}, 'Y:=', xyz{2}, 'Z:=', xyz{3}}}}});
        actual = char(s.call(s.Editor, 'GetPropertyValue', 'Geometry3DCSTab', name, 'Reference CS'));
        assert(strcmp(actual, cs.parent), 'Vivaldi:CoordinateParent', 'Parent CS không đúng: %s.', name);
    end
    s.Diagnostics.checkpoint('CHECK_01', fieldnames(g.cs), 'Đã đọc lại Parent CS; symbolic origins giữ trong history.');
end
