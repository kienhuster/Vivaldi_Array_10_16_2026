# Một Working Project, nhiều lần Update

1. Connect đúng 2021.2; chạy COM Compatibility Test lần đầu.
2. Chọn đường dẫn mới ngoài reference. Create Working Copy hoặc Build From Scratch. Hai mode được ghi riêng trong trạng thái/log.
3. Validate Geometry trên mô hình hiện tại để có LastValid. Đường dẫn Project và Design được kiểm tra qua COM trước mỗi thao tác ghi.
4. Nhập số trong GUI; Calculate/Apply Changes chỉ tính draft và preview, chưa sửa HFSS.
5. Update Geometry gọi một ChangeProperty chứa 19 independent variables. Không NewProject, InsertDesign, SaveAs hoặc Analyze trong Update.
6. Đọc lại 19 số và 12 expressions, inventory, flare void/metal/thickness, cavity, coax, ports, bounds và ValidateDesign. Chỉ PASS nếu các assertions thực chạy đạt.
7. Khi lỗi, thử ghi lại bộ biến trước và validate rollback. Update vẫn báo thất bại dù rollback thành công. Rollback thất bại khóa Save/Update cho tới restore/reload và validate.
8. Save chỉ khi healthy và validate lại. Save As New Version là thao tác chủ động tạo AEDT mới; sau đó các lần update/save tiếp tục dùng phiên bản vừa chọn.
9. Reload Last Saved Version có xác nhận bỏ thay đổi chưa lưu, đóng đúng working project rồi mở lại. Không mở/đóng file tham chiếu. Nếu build chưa Save, file recovery chỉ là project shell trống; cần build lại vào đường dẫn mới hoặc kiểm tra project chưa lưu trong HFSS.

COM không có transaction nguyên tử. Một call có thể thay đổi vài biến rồi lỗi; vì vậy rollback thử cả bộ và kiểm tra lại. Không tự Save mô hình hỏng. LastValid và Dirty trong ứng dụng chỉ theo dõi những lần kiểm tra của phiên hiện tại, không suy đoán trạng thái chỉnh tay trong HFSS. Trước Update, verify baseline phát hiện biến bị sửa bên ngoài; hãy Validate lại trước khi áp dụng draft. Các sửa CAD bằng tay không thay biến có thể chỉ được phát hiện bởi topology checks.

Nếu Working Project cũ chứa Move middle cutter cứng 2mm, cập nhật thickness bị chặn. Create Working Copy của bản này chuẩn hóa đúng literal trên bản sao và ghi thông báo log; scratch builder dùng thickness ngay từ đầu. Không tự chỉnh các history khác.

Kết quả bị đánh dấu `RESULTS OUTDATED — RE-SIMULATION REQUIRED` trước lần mutation đầu, kể cả update/solver-setting thất bại và đã rollback. Không phục hồi cờ simulated chỉ vì tham số quay về giá trị cũ.

Monitor không ping trong lúc COM đang busy. Reconnect không tự đóng project đang mở. Sau Reconnect chọn Open Working Project để bind handles, kiểm tra cùng đường dẫn và validate. Phần mềm không tự kết nối một design tên HFSSDesign1.
