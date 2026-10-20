# Nguồn và đối chiếu phiên bản

Giữ nguyên hai file gốc ở root và bản reference. AEDT 669840 bytes: SHA256 631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619. Tài liệu gốc: SHA256 49c5cbc0bc445e9bad6df008d9487f987c5db99cee7aca567fed0b205ad6e912.

Nhánh codex/vivaldi-hfss-api-vietnamese và PR #2 giữ phiên bản trước để đối chiếu. Phiên bản này thay ứng dụng trong thư mục Vivaldi_DualPol_Builder, không giữ thêm một ứng dụng Live chạy song song. Công thức, preview, thứ tự CAD và phép đo được tái sử dụng/gom; bỏ live update, copy reference, rollback, trạng thái dirty và lớp backend.

Standard_Vivaldi_GUI.m do người dùng gửi được giữ nguyên byte trong reference, chỉ để đối chiếu phong cách hàm GUI/callback lồng và gọi hfss-api. Không đưa thư mục reference vào MATLAB path. Không lấy hình học FR4/substrate hoặc công thức Balanis từ mẫu đó thay mô hình nhôm/coax dual-pol nguồn.

hfss-api pin a3fd32a418c726070f51e73273de93c5080bdb8d, giữ source/examples/GPL/COPYING; chỉ hfssExecuteScript có bản vá tương thích ngược đã công khai. Không đóng gói binary MATLAB/Ansys/license hoặc dependency Python chạy ứng dụng.
