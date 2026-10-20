# Báo cáo kiểm thử backend hfss-api

Kết quả thực chạy được lưu trong `tests/verification/`. Script được sinh trên Linux, không chạy bên trong HFSS. Không đánh đồng code implemented, syntax/static passed, Octave runtime và HFSS geometry/simulation validated.

| Phạm vi | Trạng thái tại cloud |
|---|---|
| Helper gốc thực được gọi để sinh VBS | Có; danh sách helper trong từng job JSON, được portable test kiểm tra |
| Công thức/kích thước tự do/target/transform/HPBW | Chạy bằng GNU Octave, xem báo cáo portable thực tế |
| Update script cùng project, changed-only, rollback, no solve/save | Kiểm tra nội dung sinh và protocol status giả, không phải CAD runtime |
| Lint module tự viết và helper vendor được dùng | Xem lint-result.txt; không tự sửa toàn bộ helper upstream không dùng |
| Kiểm tra VBS vật lý dòng/continuation/quotes/ngoặc/block | Kiểm tra tĩnh, không thay VBScript parser/Ansys runtime |
| GUI MATLAB mở/callback/tất cả tab/nút Việt hóa | PENDING — có testVivaldiGUI, thiếu MATLAB desktop |
| HFSS API cơ bản | PENDING — có runHFSSAPIIntegration |
| CAD flare/transition/cavity/BothSides/pol2/coax/port thực | PENDING — checkpoint đo runtime có sẵn |
| Save/Reopen/Update thật trong HFSS | PENDING |
| Solver, field phase, hội tụ và so ảnh chuẩn | PENDING |

## Kiểm thử đã viết

`runHFSSAPITests` có nhóm helper thật/precision, mở rộng CS/BothSides, full build script, thứ tự cutter, update4 biến không NewProject/Save/Analyze, Save vs SaveAs, solver/report gates, bảo vệ nguồn/literal, UTF16/ACK/partial line, terminal/rollback status giả, offline Pending, timeout khóa job, default/arbitrary/invalid dimensions, fzero arbitrary target, transform/dependency và HPBW. Fixtures status và parabola là test thuật toán, không được đưa vào GUI như kết quả HFSS.

`testVivaldiGUI` (MATLAB unittest) kiểm tra5 tab tiếng Việt, số nút3/0/5/2/1, numeric callback, không phát sinh HFSS job khi sửa số. Native axes-toolbar của MATLAB hoặc API error gốc có thể theo ngôn ngữ bản cài.

`runHFSSAPIIntegration` trên Windows tạo project thử Box liên kết biến, sheet Subtract, BothSides và positive/negative point probes; fullBuild=true bổ sung dựng anten, hai lượt đổi kích thước cùng file, Save/Reload và đọc biến. Không đóng hoặc sửa project tham chiếu. Chỉ khi đặt biến môi trường solver mới Analyze trong integration.

## Chạy lại trên Windows

```matlab
addpath('tests');
runHFSSAPITests(fullfile(pwd,'work','portable'));
runtests('tests/testVivaldiGUI.m');
exe = 'D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe'; % thay theo máy
runHFSSAPIIntegration(fullfile(pwd,'work','integration'),exe,true);
```

Muốn chạy solver trong bài test tích hợp, chủ động `setenv('VIVALDI_RUN_SOLVER_TESTS','1')`. Không bỏ pending hoặc mock thành Direct COM Verified/HFSS Passed.

## Kết quả thực chạy ngày 20/10/2026

- MISS_HIT 0.9.44: 21 tệp tự viết và 28 helper upstream được dùng, tổng49 tệp, không lỗi/cảnh báo.
- GNU Octave 9.4.0: 16 nhóm portable đạt trên mã refactor hiện tại; báo cáo hfss-api-portable-results.json.
- 8 kịch bản VBS sinh thực: BOM UTF16, strings/ngoặc, số dòng vật lý/continuation và Sub/Function cân bằng đều đạt kiểm tra tĩnh; không coi là đã thực thi VBS.
- Nguồn AEDT đúng SHA-256, 3285 khối cân bằng. 89 tệp upstream được đối chiếu hash; chỉ launcher có bản vá công khai.
- Module MATLAB tự viết giảm34 → 21. Kiểm tra tĩnh xác nhận5 tab Việt hóa và11 nút chính, không có actxserver/actxGetRunningServer trong runtime MATLAB.
- Integration runner trả PENDING trên Linux. GUI, API/CAD thật, Save/Reopen trong HFSS, pha port và solver vẫn chưa chạy.
