# Giới hạn và những phần chưa kiểm chứng

Môi trường Codex Linux không có MATLAB desktop, Windows Script Host hoặc HFSS. Kiểm thử Octave chỉ chứng minh công thức, gọi helper sinh script, mã hóa và protocol; không chứng minh anten dựng thành công.

GUI MATLAB, compiler VBScript Windows, Rectangle thử, Equation Surfaces, Boolean flare, BothSides, phân cực hai, coax/ports, Validate, Save AEDT và solver đều chưa được chạy thực tế. Tất cả giữ PENDING trong bằng chứng tích hợp.

Point-query/volume/face/CS API có thể khác hành vi ở HFSS 2021 R2; guard sẽ dừng nếu không đo được. Phạm vi geometry PASS trong log chỉ là các điểm/thuộc tính đã đo, không phải chứng nhận toàn bộ topology hoặc RF. Hướng pha/field ở cổng cần đối chiếu nguồn trên Windows.

Preview dùng polyshape lấy mẫu và extrusion, không phải CAD HFSS. Chương trình chỉ dựng một phần tử dual-pol, không tạo mảng/Optimetrics. Các cấu hình khác nguồn vẫn cần kiểm tra Boolean và tiếp xúc trên HFSS.

GUI chỉ theo dõi job hiện tại; đóng GUI không kill HFSS. Script/status còn trong thư mục xuất để chẩn đoán. Không có phục hồi session, mở lại tham số, quản lý unsaved changes hoặc cập nhật anten cũ. Muốn đổi kích thước thì dựng file mới.

Thư mục .aedt.reserve được giữ để tên đã cấp không bị dùng lại, kể cả khi dựng lỗi. Có thể dọn thủ công sau khi chắc chắn không còn job chạy; không cần dọn để tạo anten tiếp theo.
