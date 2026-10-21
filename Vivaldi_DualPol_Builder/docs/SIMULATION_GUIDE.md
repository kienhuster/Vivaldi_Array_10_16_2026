# Mô phỏng chủ động và kết quả thực

Dựng mới không tự chạy solver. Chỉ sau khi HFSS trả VERIFIED và đã lưu anten hoàn chỉnh, nút Chạy mô phỏng mới được bật. Thông số anten sửa sau đó chỉ ảnh hưởng lần dựng tiếp theo, không thay đổi file đã tạo.

Tab Mô phỏng cho chọn Start/Stop/Step/Adaptive GHz và cổng kích thích 1W/0W. Mặc định Setup1 5GHz, deltaS .02, min5/max50 passes, Discrete Sweep 5..20GHz bước .25GHz. Bấm Chạy mô phỏng sẽ mở/chọn đúng file vừa tạo, kiểm tra CAD, thiết lập solver, Analyze riêng Setup1 rồi xuất báo cáo có dữ liệu thật.

S-parameters, VSWR, trở kháng và các báo cáo trường xa được lấy ở nominal variation của 19 biến. Gain/pattern/efficiency chỉ xuất khi có dữ liệu ở tần số yêu cầu; log ghi UNAVAILABLE khi thiếu. Dropdown chỉ liệt kê CSV HFSS đã xuất; đồ thị không có dữ liệu mẫu hoặc RF suy ra từ công thức.

Mỗi job mô phỏng có thư mục CSV riêng để tránh ghi đè. Mô phỏng có thể lưu lại kết quả vào đúng AEDT vừa dựng; đây không phải cập nhật hình học. Không hỗ trợ chọn AEDT bất kỳ làm baseline.
