# Solver và kết quả

Nguồn giữ adaptive5GHz, deltaS.02, min5/max50 passes, minimum converged3, refinement10; Discrete5–20GHz bước.25GHz, SaveFields/SaveRadFields. Mesh slider5 và các flag InitialMeshSettings được giữ. Port1 mặc định1W0°, port2=0W0°; có thể chọn cổng2 hoặc tùy chỉnh công suất/pha trong menu. Không tự cấp hai port1W.

Chỉ nút Chạy mô phỏng gọi helper hfssSolveSetup và adapter Analyze "Setup1". Không AnalyzeAll hoặc chạy sáu Optimetrics. Trước solve kiểm tra full model; sau solve hỏi dữ liệu S thực ở nominal variation hiện tại. Có dữ liệu không chứng minh đã hội tụ; cần xem convergence HFSS. Field frequency dùng menu thiết lập solver nâng cao.

Nâng cao → Xuất kết quả thực từ HFSS gọi hfssCreateReport/hfssExportToFile. Có S11/S22/S21/S12 dB, VSWR1/2, re/im Z11/Z22, realized gain, elevation/azimuth, pattern3D và efficiency khi HFSS cung cấp. Gate GetSolutionDataPerVariation/GetRealDataValues trước report; các field còn kiểm tra đúng tần số và đơn vị sweep. Báo cáo không có dữ liệu bị bỏ qua có thông báo; lỗi Automation thật vẫn dừng job và giữ lỗi, không đổi thành dữ liệu giả.

Nominal families dùng 19 independent variables; không lấy toàn bộ các variation cũ. Export tự động yêu cầu đã giải geometry hiện tại trong phiên ứng dụng. Mỗi lần update/restore/solve làm cũ signature. Có metadata gồm params, solver/excitation/version/project và các CSV đã xuất. File CSV đang có không bị ghi đè.

Chọn đồ thị bằng dropdown duy nhất. CSV riêng có provenance chưa xác nhận; importer không đổi trạng thái ứng dụng thành simulated. Có thể chọn cột X/Y/Phi trong menu nếu header không nhận dạng. 3D dùng scatter từ mẫu Theta/Phi độ và gain dB, không thêm số liệu ngoài mẫu. HPBW nội suy hai giao điểm peak-3dB; thiếu crossing trả unsupported/NaN. Muốn đo lobe qua ±180° cần chọn/unwrap mặt cắt phù hợp trước.

Chưa có aedtresults kèm nguồn; không có số S/gain/efficiency mẫu giả. Parabola trong test HPBW chỉ kiểm tra thuật toán, không đi vào GUI như kết quả anten.
