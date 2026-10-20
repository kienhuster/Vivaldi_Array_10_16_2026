# Giới hạn và phần còn chờ kiểm chứng

- Cloud Linux chưa chạy MATLAB desktop, HFSS 2021 R2 hoặc solver/license. Những điều này vẫn PENDING dù helper generation, math và protocol tests đạt.
- Preview polyshape là lấy mẫu. Chưa có hai ảnh HFSS chuẩn để so hình ảnh. Point probes hữu hạn không chứng minh toàn bộ topology/tiếp xúc/RF.
- Point-query trên sheet, parent CS readback, Equation Surface và signature tương thích 2021 R2 cần test thật. Nếu unsupported, compatibility/build dừng; không dựng tiếp một tấm đặc rồi báo đạt.
- Helper gốc cũ được dùng thật, nhưng cần adapter theo format. Các method/signature như FarFieldSphere, Solve, report category, Lumped Port impedance được chỉnh output có kiểm tra. Giữ bản upstream pin và một bản vá launcher duy nhất; nâng upstream phải chạy lại regression.
- Không có persistent COM session MATLAB. Trạng thái kết nối là lần phản hồi của script gần nhất; không chọn PID AEDT cụ thể. Nhiều phiên/cùng tên project và file lock có thể làm attach lỗi; path mismatch bị chặn.
- Launcher chạy nền bằng Java chưa được chạy trên Windows trong cloud. Không coi code0 hoặc process exit là job thành công; chỉ status ACK+VERIFIED+terminal+PARAM mới được chấp nhận. Timeout giữ khóa job, không tự kill HFSS hoặc xóa lock.
- Script debug dùng MsgBox HFSS; có thể modal và chưa kiểm chứng khả năng tương tác Modeler khi dừng. Không tự export ảnh; cây đối tượng GUI/nhật ký là inventory top-level, lịch sử đầy đủ xem trong HFSS.
- Integration line outer-to-inner tái dựng từ tọa độ symbolic, chưa so azimuth/pha field với nguồn. NoArray được kiểm tra từ file sau Save, không gọi một SetArraySetup chưa xác minh.
- Sacrificial cutters KeepOriginals=false, Rectangle covered sheet và Move middle cutter=thickness là khác biệt triển khai công khai so với history serialization nguồn. Đo CAD và mặc định số học chưa thay thế chứng minh Boolean thực.
- Cavity không được xuyên ngoài biên tấm trong miền topology được hỗ trợ. Không áp min/max preset; một cấu hình bị loại không đồng nghĩa bất khả thi về mọi thiết kế vật lý.
- Save/Reopen và rollback code có đầy đủ, nhưng HFSS không có transaction nguyên tử. Sửa CAD bên ngoài ứng dụng hoặc đóng GUI khi job chạy có thể cần mở lại bản lưu bằng tay; Dirty chỉ theo dõi ứng dụng.
- CSV cần cột số hữu hạn; import riêng chưa xác minh geometry. Không tự nhận diện unit khác độ cho 3D hoặc chọn lobe wrap cho HPBW. Lỗi API ở optional expression có thể dừng export job dù các CSV trước đã xuất thật.
- Lưu shell rỗng khi scratch để định danh; nếu build lỗi trước Save, file recovery chỉ có shell, không phải model đã dựng. Không tự ghi đè nguồn gốc.
