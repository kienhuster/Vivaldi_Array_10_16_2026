# Giới hạn đã biết

- MATLAB desktop và HFSS COM/CAD/solver **chưa chạy** trên cloud Linux này. Nested SAFEARRAY, CreateEquationSurface 2021 R2, hierarchy CS, point-query trên sheet, port fields và convergence đều cần integration test trên máy đích. Không phát hành với nhãn Fully Verified.
- Hai ảnh HFSS chuẩn chưa có trong workspace; chưa đối chiếu hình ảnh. Không sử dụng ảnh Internet thay mô hình.
- Preview là polyshape từ mẫu, có thể cảnh báo khi polygon suy biến. Không chứng minh CAD hoặc tiếp xúc điện.
- Point probes hữu hạn kiểm tra flare/slot/cavity, thickness, coax; không là chứng minh hình học toàn cục. Nếu sheet point-query unsupported, builder dừng ở CHECK_08. Chưa triển khai phương án thay thế bằng intersection/section CAD có recorder 2021 R2 xác nhận.
- Parent CS được đọc lại; symbolic origin giữ trong history, chưa có runtime so sánh đầy đủ orientation matrix của tất cả CS trong 2021 R2. Công thức local/global được unit test.
- Integration line outer-to-inner được tái dựng; hướng azimuth và pha field cần so với mô hình nguồn, không suy từ IDs/tọa độ placeholder.
- Có hai thay đổi kỹ thuật được công khai: middle cutter Move dùng thickness; cutter snapshots dùng một lần với KeepOriginals=false. Default tương đương theo công thức, Boolean tương đương còn cần chạy HFSS.
- Chỉ tái dựng các tính chất điện từ vật liệu; không mang toàn bộ thuộc tính cơ/nhiệt. Không tạo Optimetrics hoặc array; mục tiêu là một phần tử dual-pol.
- COM đồng bộ có thể chặn UI khi dựng/solve; chưa có cancellation/progress đáng tin cậy, không ép kill server. Không tự giả định COM transaction nguyên tử.
- Unsaved flag theo dõi ứng dụng; sửa CAD bằng tay ngoài ứng dụng có thể không bị phát hiện đầy đủ. Baseline variable readback ngăn ghi đè thay đổi biến ngoài GUI; topology probes chỉ phát hiện các vùng được đo.
- CSV importer chỉ nhận cột số; chọn cột/đơn vị đúng. Import riêng không xác minh provenance geometry. 3D là scatter từ mẫu thật. HPBW không tự chọn lobe qua discontinuity ±180°.
- Export tự động chỉ cho dữ liệu vừa giải trong session hiện tại; dự án mở lại có nghiệm cũ cần giải lại qua ứng dụng hoặc import CSV có chú thích provenance. Không suy có kết quả chỉ vì IsSolved trong preview nguồn.
- NoArray được kiểm tra từ file sau Save; scratch builder không gọi một method SetArraySetup chưa xác minh. Default AEDT cần giữ NoArray; nếu không, Save readback báo lỗi.
- Chưa export screenshot HFSS tự động; không tạo ảnh giả. Object tree GUI là top-level inventory, xem chi tiết lịch sử CAD trực tiếp trong HFSS.
- Đường dẫn Unicode và nhiều phiên AEDT cần kiểm thử Windows. Generic ProgID không cho chọn PID cụ thể, kết nối phiên mà COM đăng ký trả về rồi kiểm tra phiên bản.

Mã integration test có sẵn; các mục PENDING cần log/ảnh thật để tiếp tục hoàn thiện, không được đổi nhãn PASS bằng kiểm tra tĩnh.
