# Thông tin bản quyền và giấy phép

Thư viện `third_party/hfss-api` từ https://github.com/yuip/hfss-api, commit a3fd32a418c726070f51e73273de93c5080bdb8d, phân phối theo GNU GPL phiên bản2 hoặc mới hơn như copyright header upstream. Giữ nguyên các thông báo đó và văn bản COPYING. Không tuyên bố tác giả của thư viện là tác giả dự án này.

Các thay đổi refactor, adapter tích hợp, builder, GUI và tests của phần mềm kết hợp trong bản này được cung cấp theo GPL-2.0-or-later tương thích thư viện. Có đầy đủ source để người dùng sửa và xây dựng lại. Những đóng góp/bản quyền nguồn kế thừa được mô tả trong docs/SOURCE_PROVENANCE.md.

Dữ liệu anten AEDT và tài liệu người dùng trong root/reference giữ nguyên nội dung và quyền của chủ dự án; văn bản GPL ở đây không tự chuyển quyền sở hữu dữ liệu đó. MATLAB và Ansys là phần mềm riêng, không kèm hoặc cấp license trong repository.

Bản vá upstream duy nhất: hfssExecuteScript nhận waitForExit tùy chọn mặc định true, trả process handle ở output thứ hai và khởi chạy nền bằng Java khi false; khởi tạo runAndExit đúng khi chỉ truyền3 arguments. Các cách gọi cũ vẫn giữ hành vi đồng bộ. Mọi thay đổi/hash được công khai ở third_party/HFSS_API_PROVENANCE.json.
