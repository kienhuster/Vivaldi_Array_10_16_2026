# Nguồn và những thay đổi

Hai file gốc và reference giữ nguyên SHA-256. AEDT669840 bytes có SHA256 `631820b2c07f457fd22f5cdab2aeae15694788c869629935460b2cefda1ba619`. Source chuẩn thuộc repository kienhuster/Vivaldi_Array_10_16_2026.

Bản trước đã vào main qua PR1, commit5d6ba22. Refactor này sửa đúng ứng dụng hiện có: engine công thức/preview/parser được giữ và Việt hóa chú thích; bỏ các class COM và wrapper trùng lặp; thay bằng backend sử dụng hfss-api, helper mở rộng gộp, GUI gọn và tests tương ứng. Entry point không đổi. Báo cáo cũ không được dùng làm bằng chứng CAD của backend mới.

Thư viện upstream yuip/hfss-api được pin tại commit a3fd32a418c726070f51e73273de93c5080bdb8d, giữ source/examples/copyright/COPYING. Chỉ hfssExecuteScript được thay đổi có chủ đích và tương thích ngược; các thay đổi 2021 khác áp lên output trong adapter. Hash gốc và hash bản vá ghi tại third_party/HFSS_API_PROVENANCE.json. Phân tích bốn example trong HFSS_API_EXAMPLE_STUDY.md.

COPYING/NOTICE ghi GPL2-or-later cho phần mềm kết hợp và quyền riêng của dữ liệu người dùng. Không đóng gói binary MATLAB/Ansys, license hoặc Python/PyAEDT. Chú thích API errors gốc từ Ansys có thể là tiếng Anh; thông báo và giao diện do dự án tạo đã Việt hóa.
