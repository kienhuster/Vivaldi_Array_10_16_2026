# Chẩn đoán

| Triệu chứng | Hành động |
|---|---|
| PENDING COM trên Linux | Chạy phần COM trong Windows MATLAB có AEDT; offline preview vẫn dùng được |
| ProgID không có CLSID / Class not registered | Kiểm tra bản cài HFSS 2021 R2 và đăng ký COM bằng công cụ cài đặt Ansys; Detect đọc registry, không tự chỉnh |
| Server trả 2022/2023/... | Mở đúng 2021 R2 hoặc nhập ProgID version-specific đã đăng ký; không bỏ version guard |
| Access denied / running server không attach | Chạy MATLAB/AEDT cùng tài khoản và cùng mức quyền Windows; kiểm tra nhiều phiên AEDT |
| Nested cell/SAFEARRAY type mismatch | Chạy COM Compatibility Test, gửi method + identifier/message; không tự coi VBS là Direct COM |
| CHECK_08 fail / hai tấm đặc | Kiểm tra Subtract composite cutter, CS patch_td/slot_feed_td và point-query trên sheet; dừng build, không Save |
| CHECK_09 fail | Kiểm tra BothSides=true và tổng thickness; gửi mặt cắt ±t/2 |
| CHECK_10/12 fail | Kiểm tra parent RelativeCS1=patch_td, Z=-90deg, NumClones=2 và Move Y=thickness |
| Coax volume/hole sai | Kiểm tra cutter được chụp trước hollowing, 6 cutters cuối và 4 conductors còn lại |
| Port area/center sai | Xem cap face tại z_feed-h3-h_cabin, bán kính r_cabmid; không dùng Edge IDs cũ |
| Update rollback thất bại | Không Save; Reload Last Saved Version hoặc mở bản lưu/backup an toàn trong HFSS |
| Working path đang khóa / tên trùng | Chọn đường dẫn mới khi Build/Copy; Attach đúng project hiện có thay vì tạo lại |
| Export không có dữ liệu | Solve Setup1 tại nominal variation, lưu fields tại frequency cần; xem convergence/license trong HFSS |
| CSV có text/NaN/Inf | Xuất lại CSV cột số hoặc chọn report phù hợp; không thay NaN bằng dữ liệu giả |

Debug Build dừng từng checkpoint bằng Continue/Stop. Log TXT và diagnostic JSON chứa bộ params, timestamp, project path, step và error. View Object Tree hiển thị tên top-level từ HFSS; xem child history đầy đủ trong Modeler. Show Failed Step lấy lỗi gần nhất. Gửi kèm report `com-compatibility.json`, phiên bản MATLAB/HFSS, ảnh hai mặt anten và file Working Project nếu cho phép. Không gửi license/secret.

Không có cơ chế tự kill HFSS, tự xóa lock hay sửa project nguồn. Đóng GUI khi COM đang solve phải đợi call trả về. Nếu MATLAB/HFSS treo, xử lý bằng công cụ Windows và mở lại bản lưu; kết quả chưa lưu có thể mất.
