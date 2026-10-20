# Cài đặt trên Windows

Yêu cầu Windows 10/11 64-bit, MATLAB R2021a+ có MATLAB desktop và COM Automation, HFSS/Ansys Electronics Desktop 2021 R2 đã cài và đăng ký COM, license phù hợp khi giải. Không cần toolbox RF/Antenna, Python hoặc PyAEDT. Tính toán dùng base MATLAB, `fzero`, `polyshape`; GUI dùng `uifigure`.

Giải nén ZIP vào đường dẫn có quyền ghi. Tránh chạy trực tiếp trong ZIP hoặc `Program Files`. Giữ nguyên các thư mục con. Tệp chính kiểm tra phiên bản MATLAB trước khi tạo GUI. Mã UTF-8 có hướng dẫn tiếng Việt.

Đường dẫn HFSS ví dụ `D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe` chỉ để nhận diện bản cài. COM không cần truyền đường dẫn executable và không dùng `/RunScript`. Nút Detect truy vấn registry ProgID; ô ProgID cho phép nhập đăng ký thực tế của máy.

Mở AEDT 2021 R2 bằng tay nếu muốn attach phiên đang chạy. Chạy MATLAB và AEDT cùng mức quyền Windows để tránh lỗi access denied. Chọn Connect. Phiên generic ProgID phải trả phiên bản bắt đầu `2021.2`; phiên khác bị từ chối.

Đường dẫn được truyền bằng COM arguments và Java canonical File, không ghép shell command nên khoảng trắng không cần escape. Unicode còn cần kiểm thử trên bản cài HFSS thực tế; nếu AEDT từ chối tên Unicode, thử đường dẫn ASCII trên ổ cục bộ và gửi log. Tránh thư mục đồng bộ/ổ mạng trong lần test đầu.

Bấm COM Compatibility Test trước khi dựng anten. Nếu lỗi SAFEARRAY, giữ report FAIL và gửi log; chương trình không tự chuyển sang script. Có thể tiếp tục dùng tính toán và preview offline.
