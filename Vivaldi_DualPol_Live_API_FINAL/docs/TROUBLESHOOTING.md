# Nhật ký và khắc phục

Chọn dòng trong tab Nhật ký & kiểm tra để xem bước, execution/geometry, project và thông số. Xuất TXT hoặc JSON trong menu Nâng cao. Mỗi job ở work có script UTF16, JSON mô tả helper/params và status có JOB ID. Khi gửi lỗi, gửi ba tệp này cùng phiên bản MATLAB/HFSS và ảnh Modeler; không gửi license/token.

| Lỗi | Cách kiểm tra |
|---|---|
| Chỉ có script, chưa có CAD | Xem chế độ Chỉ tạo kịch bản. Trên Linux đây là chế độ mặc định, không phải HFSS đã chạy |
| Không tìm thấy ansysedt.exe | Chọn executable trong menu; không dùng đường dẫn duy nhất ổ D |
| Class not registered | Kiểm tra cài đặt/đăng ký scripting HFSS2021R2 và cùng quyền MATLAB/AEDT |
| HFSS trả sai phiên bản | Mở đúng 2021R2; không bỏ version guard |
| Không có ACK hoặc timeout | Xem lỗi script trong HFSS, launcher.log và file status; không gửi update mới khi job chưa kết thúc |
| Project cùng tên khác path | Đóng/đổi tên project trùng trong đúng phiên hoặc chọn đường dẫn/tên khác; ứng dụng không tự đóng project người dùng |
| CHECK08 sai / hai tấm đặc | Xem Unite cutter, CS, Subtract và khả năng point-query trên sheet; dừng, không Save |
| CHECK09/10/12 sai | Kiểm tra BothSides tổng thickness, parent RelativeCS1, góc Z=-90 và Move Y=thickness |
| Coax/port sai | Xem 6 full cutters trước hollowing, volume copper, face area/center và integration line |
| Rollback lỗi | Không Save; dùng mở lại bản lưu hoặc xử lý backup bằng HFSS |
| Export thiếu dữ liệu | Solve Setup1 đúng nominal, lưu field tại tần số yêu cầu, xem license/convergence |
| CSV không nhận cột | Nhập cột số thật; dùng menu Chọn cột đồ thị CSV, giữ đúng đơn vị |

Kiểm tra tương thích trong menu chạy project thử độc lập, không nguồn gốc. Với kiểm tra đầy đủ: `runHFSSAPIIntegration(outputDir,exe,true)`. Solver chỉ chạy trong integration khi chủ động đặt `VIVALDI_RUN_SOLVER_TESTS=1`. Trạng thái Pending không được đổi thành Passed bằng cách bỏ assertions.
