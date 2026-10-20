# Chuẩn bị Windows

Windows 10/11, MATLAB R2021a+ có desktop/JVM, Ansys Electronics Desktop/HFSS 2021 R2 đã đăng ký scripting Automation và license khi giải. Không cần RF/Antenna toolbox, Parallel Computing Toolbox, Python hoặc PyAEDT. Thư viện GPL đi kèm toàn bộ source.

Giải nén repository vào thư mục có quyền ghi; đặt Current Folder vào `Vivaldi_DualPol_Live_API_FINAL`; chạy `Vivaldi_DualPol_Live_API`. Không chạy từng module thủ công. `work/` được tạo lúc chạy, không commit scripts/status/results này.

Trong menu Nâng cao chọn `ansysedt.exe`. Dò tự động hỗ trợ ANSYSEM_ROOT212/ANSYSEM_ROOT và các vị trí Program Files phổ biến ở C/D; không hard-code duy nhất ổ D. Launcher chạy nền truyền argument riêng nên khoảng trắng không cần escape shell. Unicode và nhiều phiên AEDT vẫn cần test trên máy đích. Không tự xóa lock hoặc kill HFSS.

Chạy kiểm tra tương thích trước: tạo Box liên kết biến, đổi biến qua helper, sheet có vùng rỗng, BothSides và đọc lại kích thước. Nếu API point-query trên sheet không hỗ trợ, test và builder dừng; không tiếp tục tạo tấm đặc rồi báo đạt. Mã nguồn có đầy đủ tests nhưng cloud Linux không thể chạy MATLAB desktop/HFSS.

ProgID 2021.2 được yêu cầu trong script. Nếu class not registered, kiểm tra cài đặt Ansys và cùng mức quyền MATLAB/AEDT. Ứng dụng không tự sửa registry hoặc dùng một phiên bản HFSS khác rồi báo 2021 R2.
