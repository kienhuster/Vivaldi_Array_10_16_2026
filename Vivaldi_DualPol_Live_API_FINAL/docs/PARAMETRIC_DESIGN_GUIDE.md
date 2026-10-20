# Tham số và miền thiết kế

19 biến độc lập đúng nguồn: L_flare_1, aperture_w, slot_feed_w, deg_slot_t, h3_slot_feed, h2, cavity_w, cavity_L, h_de, r_cabin, positionx, r_cabmid, r_cabout, lamda, scan_phi, scan_theta, thickness, them, c2. Trừ ba góc dùng độ, các biến còn lại dùng mm theo declaration gốc. Không gán thêm ý nghĩa vật lý cho c2 hoặc scan trong mô hình một phần tử NoArray.

Ô numeric không giới hạn theo preset/slider. Giá trị chuyển sang HFSS bằng `%.17g` cùng đơn vị, không làm tròn trước khi tính hoặc truyền COM. ValueDisplayFormat chỉ điều khiển hiển thị. Các range trong metadata là gợi ý cũ cho slider, không áp dụng làm numeric limit. Có thể nhập 37.628, 61.352 hoặc 90 mm và mọi giá trị thực khác nếu qua kiểm tra.

12 biến dẫn xuất được giữ bằng biểu thức HFSS trong CAD history, đồng thời tính số độc lập trong MATLAB. `slot_t_L=6.4mm+them`, không sửa trực tiếp slot_t_L. Lượng giác MATLAB dùng sind/cosd. Default L_patch=49.23630329005893mm, không phải 40mm. Dependency graph từ hàm `vivaldiDependencyGraph` có cả expressions, CS, cutter, body, coax, ports, region và results.

Target Length giải L_flare_1 bằng fzero, dò những khoảng liên tiếp có validation hợp lệ; miền mặc định mở theo target và baseline, không chỉ 49/50. Chỉ L_flare_1 thay đổi, residual <1e-6mm. Nếu không thấy nghiệm trong miền báo cáo, hàm báo lỗi; không khẳng định đã chứng minh không tồn tại nghiệm toàn cục. Có thể truyền bracket thứ ba để nghiên cứu một miền cụ thể.

Validation đại số: scalar thực hữu hạn, kích thước dương theo vật lý, aperture > slot >0, radius ngoài > giữa > lõi >0, slot_t_L>0, derived hữu hạn, z_feed nằm trong flare, slot/cavity không mở xuyên ra biên tấm ngoài ý muốn. them/positionx/góc/c2 có thể có dấu nếu vẫn thỏa geometry. Không đặt min/max tùy tiện cho góc. Các trường hợp coax lớn hơn thickness, lệch tâm lớn hoặc đổi baseline báo cần HFSS kiểm tra.

Giới hạn topology của phần mềm giữ cấu trúc nguồn: cavity không được xuyên biên ngoài; không có nghĩa mọi cấu hình bị từ chối đều bất khả thi về vật lý. Probe domain phải còn đủ đoạn flare và hai mép metal. HFSS mới xác minh Boolean, tiếp xúc, port và field. Preview polyshape là gần đúng từ mẫu, không thay thế kiểm tra CAD.
