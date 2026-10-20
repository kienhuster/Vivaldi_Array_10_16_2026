# Mô phỏng và kết quả thật

Baseline: DrivenModal, adaptive 5GHz, MaxDeltaS=.02, min5/max50 passes, minimum converged3; sweep Discrete 5–20GHz bước .25GHz, SaveFields/SaveRadFields. Mesh slider5 và các flag nguồn. Radiation Open1 với padding 20mm. Far-field 3D, Elevation, Azimuth; không tạo array. Save đọc file và kiểm tra NoArray.

GUI cho chỉnh adaptive/start/stop/step/field frequency, deltaS và passes. Excite Port1=1W/0W hoặc Port2=0W/1W. Custom nhập cả hai công suất W và phase độ. Không tự chuyển thành 1W cả hai port. Apply Solver Settings làm dữ liệu cũ stale. RUN SIMULATION hỏi chủ động trong GUI rồi chỉ Analyze Setup1; không AnalyzeAll, không chạy Optimetrics.

Analyze là COM đồng bộ, có thể chặn MATLAB lâu; không có thanh tiến độ/cancel solver độc lập đã kiểm chứng. Sau khi call trả về, chương trình truy vấn dữ liệu S thực cho nominal variation hiện tại trước khi đặt trạng thái SIMULATED. Trạng thái này không đồng nghĩa solver đã hội tụ: kiểm tra convergence và warnings trong HFSS.

Export HFSS Results yêu cầu signature geometry đã giải trong phiên hiện tại và verify biến trực tiếp. Tạo reports/CSV cho S11,S22,S21,S12 dB; VSWR; re/im Z11/Z22 khi có; Realized Gain; Elevation/Azimuth; 3D pattern; efficiency nếu API có. Mỗi report query dữ liệu trước và kiểm tra file không rỗng sau export. Báo UNSUPPORTED cho các đại lượng thiếu; không sinh số thay thế. Metadata JSON ghi project/design/variables/excitation/version/frequency. Trường phải được lưu tại field frequency đã chọn; nếu không, far-field export có thể không có dữ liệu.

Import CSV là đường đọc số thực từ file HFSS của người dùng, không tự coi file thuộc geometry hiện tại. GUI luôn ghi provenance chưa xác nhận, không đổi manager sang simulated. Chọn X/Y headers có đơn vị để vẽ S/gain/impedance/VSWR. Với 3D, chọn X=Theta độ, Phi=Phi độ, Y=Gain dB, dùng scatter3 với bán kính sqrt(linear gain), màu gain dB. Chỉ hỗ trợ CSV cột số; bỏ cột text/metadata trước khi import. 3D dùng các mẫu thật, không nội suy một mặt liên tục để che dữ liệu thiếu.

HPBW: chỉ chọn mặt cắt góc độ/gain dB, ít nhất 5 mẫu góc phân biệt, có hai giao điểm peak-3dB quanh cực đại. Nội suy tuyến tính hai crossing. Nếu thiếu crossing trả unsupported/NaN; không áp dụng công thức này vào S-parameters. Cắt qua wrap ±180° cần unwrap và chọn lobe đúng trước khi tính.

Chưa có aedtresults đi kèm nguồn và chưa chạy solver trong cloud. Không có plot S/gain mẫu trong bản giao; dữ liệu parabola chỉ nằm trong unit test HPBW, không được đưa lên GUI như kết quả anten.
