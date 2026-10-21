# Chạy trên Windows

Cần MATLAB R2021a trở lên có JVM, Windows Script Host (cscript.exe), HFSS 2021 R2 và license Ansys hợp lệ. Không cần MATLAB Antenna Toolbox cho công thức và builder; preview dùng polyshape/MATLAB graphics.

Tải nhánh GitHub bằng Code → Download ZIP, giải nén, đặt Current Folder vào `Vivaldi_DualPol_Builder`, chạy `Vivaldi_GUI`. Không addpath(genpath(...)) vì reference chứa chương trình mẫu chỉ để đọc.

Trong tab Tạo anten HFSS, chọn thư mục có quyền ghi và đường dẫn `ansysedt.exe`, ví dụ `D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe`. Nhập tham số, bấm Tạo anten HFSS rồi xem Nhật ký. Sau xác nhận thành công mới có thể Mở file HFSS vừa tạo hoặc Chạy mô phỏng.

Không tạo project khi mở GUI. Mỗi lần dựng dùng một file mới, không có nút cập nhật project. File gốc ngày 17/10 chỉ để đối chiếu.
