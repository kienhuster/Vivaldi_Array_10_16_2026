# Báo cáo kiểm thử

Báo cáo máy đọc được ở `tests/verification/`. Các trạng thái code/static/portable không được đánh đồng với MATLAB desktop hoặc HFSS. Bản này được kiểm tra trên Linux, không có MATLAB/Ansys.

| Mức bằng chứng | Trạng thái |
|---|---|
| Mã MATLAB triển khai | Có, xem module thực tế |
| Phân tích tĩnh MATLAB | Kết quả thực tế trong lint-result.txt |
| Runtime công thức + protocol | Kết quả thực tế trong portable-test-results.json |
| MATLAB desktop/GUI | PENDING |
| Direct COM/SAFEARRAY trên HFSS | PENDING |
| HFSS geometry validated | PENDING |
| HFSS simulation completed | PENDING |
| ZIP integrity | Báo cáo packaging-verified.json trong ZIP |

## Ánh xạ Test 01–15 của yêu cầu

| Test | Phạm vi đã thực hiện / còn chờ |
|---|---|
| 01 Formulas | Portable: default L_patch và số kiểm chứng nguồn |
| 02 Arbitrary dimensions | Portable: 5 giá trị chiều dài lẻ + bộ đổi aperture/cavity/thickness |
| 03 Invalid parameters | Portable: radius order, nonpositive, nonfinite, cavity vượt biên |
| 04 Target Length | Portable: 49,50,57.35,91.624mm; residual; mục tiêu không hợp lệ |
| 05 Direct COM | PENDING Windows; có runCOMCompatibilityTests |
| 06 CAD build | PENDING Windows; có runHFSSIntegrationTests, 18 checkpoints |
| 07 Flare subtract | PENDING HFSS; portable chỉ xác minh command order/protocol |
| 08 SheetThicken | PENDING HFSS; có inside/outside/void assertions runtime |
| 09 Dual pol | Công thức transform được portable test; CAD PENDING |
| 10 Coax/port | Tọa độ và bán kính nguồn được kiểm tra công thức; CAD/field PENDING |
| 11 Live update | Protocol-double kiểm tra same-project, rollback/partial failure; COM thực PENDING |
| 12 Save/Reopen | PENDING HFSS; integration đọc lại 31 variables |
| 13 Reconnect | Protocol-double mất handles được kiểm tra; shutdown AEDT thực/manual PENDING |
| 14 Solver | PENDING Windows/HFSS/license; chỉ explicit opt-in mới Analyze Setup1 |
| 15 ZIP integrity | Đọc CRC, giải nén, so SHA từng file, kiểm tra dependencies khi đóng gói |

## Chạy lại trên Windows

```matlab
addpath('tests');
runPortableTests(fullfile(pwd,'logs','portable'));
runtests('tests/testLiveAPI.m');
runCOMCompatibilityTests(fullfile(pwd,'logs','com'));
setenv('VIVALDI_RUN_HFSS_TESTS','1');
runHFSSIntegrationTests(fullfile(pwd,'logs','integration'));
```

Chỉ khi chủ động muốn dùng solver/license, đặt thêm `setenv('VIVALDI_RUN_SOLVER_TESTS','1')` trước integration run. Test không kill phiên AEDT của người dùng. Shutdown/reconnect thật là manual test riêng: lưu project, đóng AEDT, quan sát connection lost, mở đúng 2021 R2 và Reconnect/Open.

Mock transport trong tests chỉ mô phỏng protocol trả lời/điều kiện lỗi, không mô phỏng hình học hoặc điện từ. Các record PASS do mock tạo ở unit test không phải report geometry của máy thật. Test HPBW dùng parabola tổng hợp để kiểm tra thuật toán duy nhất, không xuất nó như kết quả anten.

## Kết quả thực chạy ngày 20/10/2026

- MISS_HIT 0.9.44: 34 tệp MATLAB, không lỗi/cảnh báo.
- GNU Octave 9.4.0: 20 nhóm công thức/protocol đạt; source literals được so bằng số, derived expressions được so nguyên biểu thức sau bỏ whitespace.
- Static audit: SHA-256 nguồn đúng, 3285 block AEDT cân bằng, tên hàm/file và cấu trúc runtime đạt.
- COM compatibility runner trả PENDING trên Linux; 10 mục integration HFSS đều PENDING. MATLAB unittest có 2 test đã viết, chưa chạy MATLAB desktop.

Hồi quy bổ sung LastUpdateStatus: trạng thái thành công, thất bại và rollback được chạy bằng Octave với protocol double và đạt.
