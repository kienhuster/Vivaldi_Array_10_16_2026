# Tham số hình học

Giữ 19 biến độc lập từ nguồn, bao gồm L_flare_1, aperture_w, slot_feed_w, deg_slot_t, h3_slot_feed, h2, cavity_w, cavity_L, h_de, r_cabin, positionx, r_cabmid, r_cabout, lamda, scan_phi, scan_theta, thickness, them và c2. Các góc dùng độ, các biến còn lại dùng mm như declaration gốc.

12 biến dẫn xuất giữ biểu thức HFSS và giá trị MATLAB. slot_t_L=6.4mm+them; L_flare=L_flare_1+slot_t_L; lượng giác dùng sind/cosd. Default L_patch=49.23630329005893mm. Ô numeric cho nhập số thực bất kỳ, giữ 17 chữ số khi truyền sang script; không ép preset hoặc làm tròn trung gian.

Validation từ chối số không hữu hạn, kích thước âm không hợp lệ, aperture<=slot, bán kính coax sai thứ tự, surface suy biến hoặc cavity vượt tấm. them/positionx/góc/c2 có thể có dấu nếu miền hình học hợp lệ. Coax quá lớn hoặc lệch cảnh báo cần kiểm tra tiếp xúc HFSS. Đây là kiểm tra đại số, chưa phải chứng nhận topology hoặc RF.

Thay kích thước chỉ tính lại preview và thông số dẫn xuất. Muốn tạo CAD theo kích thước mới, bấm Tạo anten HFSS: luôn một project trống và một file mới.
