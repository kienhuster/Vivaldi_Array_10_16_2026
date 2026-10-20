function VivaldiBuilder(w, p, cfg)
    % Mục đích: dựng đúng một phần tử Vivaldi dual-pol từ design trống bằng hfss-api.
    % Giữ biểu thức, CS lồng nhau, cutter trước hollowing và checkpoint đo CAD thật.
    [ok, errors] = vivaldiValidateParams(p);
    assert(ok, 'Vivaldi:Parameters', '%s', strjoin(errors, newline));
    g = vivaldiCalculateGeometry(p);
    %% 1. Khai báo biến và tính chất điện từ đúng mô hình nguồn
    hfssVivaldiExtensions(w, 'variables', p, true, {});
    materials(w);
    w.call('oEditor.SetModelUnits Array("NAME:Units Parameter","Units:=","mm","Rescale:=",False)', 'Đặt đơn vị mô hình mm');
    %% 2. Tạo các hệ tọa độ và giữ gốc local theo parent
    w.stage('CHECK_01');
    for item = {'slot_t_td', 'slot_feed_td', 'patch_td', 'RelativeCS1'}
        n = item{1};
        cs = g.cs.(n);
        hfssVivaldiExtensions(w, 'coordinate', n, cs.parent, cs.originExpressions);
    end
    w.pass('CHECK_01', 'PENDING', 'Đã đọc lại parent CS; cần kiểm tra toàn bộ orientation trong HFSS');
    %% 3. Dựng hai mặt loe mũ, không thay bằng polygon ít điểm
    w.lib(@hfssSetWCS, {'Global'});
    w.stage('CHECK_02');
    hfssVivaldiExtensions(w, 'equation', 'EquationSurface1', 'L_flare');
    w.require('HasName(ObjectNames(),"EquationSurface1")', 'Không có mặt loe dài');
    w.pass('CHECK_02', 'PENDING', 'Đã tạo mặt loe dài');
    w.stage('CHECK_03');
    hfssVivaldiExtensions(w, 'equation', 'EquationSurface2', 'slot_t_L');
    w.require('HasName(ObjectNames(),"EquationSurface2")', 'Không có mặt loe ngắn');
    w.pass('CHECK_03', 'PENDING', 'Đã tạo mặt loe ngắn');
    %% 4. Clone trước khi trim; xoay transition quanh slot_t_td thay vì Global
    w.stage('CHECK_04');
    hfssVivaldiExtensions(w, 'clone', 'EquationSurface2', 'EquationSurface2_1', false);
    w.lib(@hfssSubtract, {{'EquationSurface1'}, {'EquationSurface2_1'}, 'false'});
    w.require('ExactNames(Array("EquationSurface1","EquationSurface2"))', 'Trim flare mất đối tượng hoặc còn cutter dư');
    w.pass('CHECK_04', 'PENDING', 'Đã giữ mặt ngắn gốc');
    w.stage('CHECK_05');
    w.lib(@hfssSetWCS, {'slot_t_td'});
    w.lib(@hfssRotate, {{'EquationSurface2'}, 'Y', p.deg_slot_t}, {'RotateAngle', 'deg_slot_t'});
    w.pass('CHECK_05', 'PENDING', 'Xoay transition theo deg_slot_t trong slot_t_td');
    %% 5. Tạo khe và cavity; normal Y có Width theo Z, Height theo X
    w.stage('CHECK_06');
    w.lib(@hfssSetWCS, {'slot_feed_td'});
    hfssVivaldiExtensions(w, 'rectangle', 'Rectangle1', {'0mm', '0mm'}, {'-h3_slot_feed', 'slot_feed_w'});
    hfssVivaldiExtensions(w, 'rectangle', 'Rectangle2', {'0mm', '-h3_slot_feed'}, {'-slot_feed_w', 'slot_feed_w+h2+cavity_w'});
    hfssVivaldiExtensions(w, 'rectangle', 'Rectangle3', {'slot_feed_w+h2', '-h3_slot_feed-slot_feed_w'}, {'cavity_L', 'cavity_w'});
    w.pass('CHECK_06', 'PENDING', 'Ba mặt khe/cavity trong slot_feed_td');
    w.stage('CHECK_07');
    w.lib(@hfssUnite, {{'EquationSurface1', 'EquationSurface2', 'Rectangle1', 'Rectangle2', 'Rectangle3'}});
    w.require('ExactNames(Array("EquationSurface1"))', 'Unite vùng khoét chưa thành công');
    w.pass('CHECK_07', 'PENDING', 'Đã Unite vùng khoét');
    %% 6. Khoét thật vùng loe khỏi tấm kim loại, đo tâm rỗng và hai mép còn metal
    w.stage('CHECK_08');
    w.lib(@hfssSetWCS, {'patch_td'});
    hfssVivaldiExtensions(w, 'rectangle', 'Vivaldi_1', {'0mm', '0mm'}, {'-L_patch', '-aperture_w'});
    w.lib(@hfssSubtract, {{'Vivaldi_1'}, {'EquationSurface1'}, 'false'});
    hfssVivaldiExtensions(w, 'material', 'Vivaldi_1', 'aluminum');
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 1, false);
    VivaldiValidation('cavity', w, p, false);
    w.pass('CHECK_08', 'PASS', 'Đã đo flare rỗng, hai mép kim loại và khe/cavity trên sheet');
    %% 7. Tăng độ dày đối xứng; kiểm tra flare không biến thành tấm đặc
    w.stage('CHECK_09');
    hfssVivaldiExtensions(w, 'thicken', 'Vivaldi_1');
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 1, true);
    w.pass('CHECK_09', 'PASS', 'Đã đo BothSides và vùng loe sau tăng độ dày');
    %% 8. Tạo phân cực thứ hai theo phép xoay/dịch tham số nguồn
    w.stage('CHECK_10');
    w.lib(@hfssSetWCS, {'RelativeCS1'});
    hfssVivaldiExtensions(w, 'clone', 'Vivaldi_1', 'Vivaldi_2', true);
    hfssVivaldiExtensions(w, 'moveSecond', 'Vivaldi_2');
    VivaldiValidation('flare', w, p, 'Vivaldi_2', 2, true);
    w.pass('CHECK_10', 'PASS', 'Phân cực hai còn vùng loe và chiều dày đúng');
    %% 9. Khối nối và đế, sau đó Unite thân aluminum
    w.stage('CHECK_11');
    w.lib(@hfssSetWCS, {'RelativeCS1'});
    hfssVivaldiExtensions(w, 'box', 'Box1', {'0mm', '0mm', '0mm'}, {'thickness', 'thickness', '-L_patch'}, 'aluminum');
    w.lib(@hfssSetWCS, {'Global'});
    hfssVivaldiExtensions(w, 'box', 'De', {'(de_L+thickness)/2', '-(de_W-aperture_w)/2', 'z_feed-h3_slot_feed-slot_feed_w'}, {'-de_L', 'de_W', '-h_de'}, 'aluminum');
    w.pass('CHECK_11', 'PENDING', 'Khối nối và đế đã dựng');
    w.stage('CHECK_12');
    w.lib(@hfssUnite, {{'Vivaldi_1', 'Vivaldi_2', 'Box1', 'De'}});
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 1, true);
    VivaldiValidation('flare', w, p, 'Vivaldi_1', 2, true);
    w.pass('CHECK_12', 'PASS', 'Cả hai vùng loe còn rỗng sau Unite thân');
    %% 10. Tạo hai cáp đồng trục và sáu cutter chụp khi cylinder còn đặc
    w.stage('CHECK_13');
    w.lib(@hfssSetWCS, {'slot_feed_td'});
    hfssVivaldiExtensions(w, 'cylinder', 'cable_in', 'r_cabin', '-h3_slot_feed', '-h_cabin');
    hfssVivaldiExtensions(w, 'cylinder', 'cable_out', 'r_cabout', '-h3_slot_feed-slot_feed_w', '-h_cabout');
    hfssVivaldiExtensions(w, 'cylinder', 'cable_mid', 'r_cabmid', '-h3_slot_feed-slot_feed_w', '-h_cabout');
    w.lib(@hfssCircle, {'port1', 'Z', [0 0 0], 1, 'mm', true}, ...
          {'XCenter', '-positionx+slot_feed_w+h2'; 'YCenter', '0mm'; 'ZCenter', '-h3_slot_feed-h_cabin'; 'Radius', 'r_cabmid'});
    w.pass('CHECK_13', 'PENDING', 'Đã tạo coax thứ nhất và mặt cổng');
    w.stage('CHECK_14');
    w.lib(@hfssSetWCS, {'RelativeCS1'});
    sources = {'cable_in', 'cable_out', 'cable_mid', 'port1'};
    targets = {'cable_in_1', 'cable_out_1', 'cable_mid_1', 'port2'};
    for k = 1:4
        hfssVivaldiExtensions(w, 'clone', sources{k}, targets{k}, true);
        hfssVivaldiExtensions(w, 'moveSecond', targets{k});
    end
    w.pass('CHECK_14', 'PENDING', 'Đã sao chép coax/cổng theo phân cực thứ hai');
    w.stage('CHECK_15');
    sources = {'cable_in', 'cable_in_1', 'cable_mid', 'cable_mid_1', 'cable_out', 'cable_out_1'};
    cutters = {'cable_in_2', 'cable_in_1_1', 'cable_mid_2', 'cable_mid_1_1', 'cable_out_2', 'cable_out_1_1'};
    for k = 1:6
        hfssVivaldiExtensions(w, 'clone', sources{k}, cutters{k}, false);
    end
    w.lib(@hfssSubtract, {{'cable_out'}, {'cable_mid'}, 'false'});
    w.lib(@hfssSubtract, {{'cable_out_1'}, {'cable_mid_1'}, 'false'});
    w.lib(@hfssSubtract, {{'Vivaldi_1'}, cutters, 'false'});
    for n = {'cable_in', 'cable_out', 'cable_in_1', 'cable_out_1'}
        hfssVivaldiExtensions(w, 'material', n{1}, 'copper');
    end
    w.lib(@hfssSetWCS, {'Global'});
    VivaldiValidation('full', w, p, false);
    w.pass('CHECK_15', 'PASS', 'Đã đo thể tích coax, cổng và khoét sáu cutter khỏi thân');
    %% 11–12. Gán hai Lumped Ports, radiation, setup và sweep Discrete
    VivaldiSimulation('create', w, p, cfg);
    %% 13. Kiểm tra đầy đủ; không tự Save hoặc Analyze sau khi dựng
    VivaldiValidation('full', w, p, true);
end

function materials(w)
    % Helper thêm vật liệu gốc không có permeability; cần giữ đúng giá trị điện từ nguồn.
    w.call('Set oMaterials = oProject.GetDefinitionManager()', 'Đọc danh sách vật liệu');
    for item = {{'aluminum', '1.000021', '38000000'}, {'copper', '0.999991', '58000000'}, {'vacuum', '1', '0'}}
        m = item{1};
        a = {['NAME:' m{1}], 'CoordinateSystemType:=', 'Cartesian', 'BulkOrSurfaceType:=', 1, ...
             {'NAME:PhysicsTypes', 'set:=', {'Electromagnetic'}}, 'permittivity:=', '1', 'permeability:=', m{2}, 'conductivity:=', m{3}};
        w.line(['If HasName(oMaterials.GetProjectMaterialNames(),' w.q(m{1}) ') Then']);
        w.call(['oMaterials.EditMaterial ' w.q(m{1}) ', ' w.literal(a)], ['Đặt vật liệu ' m{1}]);
        w.line('Else');
        w.call(['oMaterials.AddMaterial ' w.literal(a)], ['Thêm vật liệu ' m{1}]);
        w.line('End If');
    end
end
