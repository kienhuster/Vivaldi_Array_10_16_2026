# Phạm vi kiểm tra bản chỉ dựng mới

Bằng chứng thực trong tests/verification; không dùng báo cáo của phiên bản Live để xác nhận CAD bản này.

| Kiểm tra | Trạng thái môi trường Cloud |
|---|---|
| Công thức mặc định, số lẻ, topology guard | Chạy bằng GNU Octave |
| Helper thật và thứ tự script CAD, save sau Validate | Chạy bằng GNU Octave và audit Python |
| Tên mới, chống ghi đè, Unicode, ASCII không BOM | Chạy bằng GNU Octave và audit Python |
| ACK/terminal/status UTF16 | Unit test với fixture được ghi rõ nguồn |
| Cú pháp MATLAB | Lint MISS_HIT; không thay MATLAB runtime |
| Compiler VBScript Windows | PENDING |
| GUI mở/callback/preview MATLAB | PENDING; testVivaldiGUI chưa chạy |
| Project trống và Rectangle thật | PENDING |
| Equation Surfaces, flare/cavity/BothSides/dual-pol | PENDING |
| Coax/port, Validate và Save AEDT thật | PENDING |
| Solver và CSV/đồ thị thực | PENDING |

Trên Windows, đặt Current Folder vào thư mục ứng dụng rồi chạy:

```matlab
addpath('tests');
runBuildOnlyTests(tempname);
runtests('tests/testVivaldiGUI.m');
runHFSSBuildIntegration('D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe', ...
    fullfile(tempdir, 'Vivaldi_KiemTra'), true, false);
```

Hàm tích hợp chạy Rectangle thử trước, sau đó anten đầy đủ; đọc log CHECK_01..18 để xem phép đo. Tham số cuối true mới cho phép chạy solver. Không bật solver để chỉ kiểm tra dựng CAD.

## Hồi quy lỗi truy vấn 450

Bổ sung kiểm tra script CHECK_02/03 đọc riêng Sheets, tách lỗi query khỏi False, duy trì đủ 18 checkpoint, trace statement và SaveAs debug riêng. Trên Linux chỉ chạy kiểm tra sinh script và audit tĩnh; runtime query/COM và tất cả CAD vẫn PENDING.

Có test fixture Windows cho mảng/chuỗi/Empty/Null, loại trùng, query lỗi 450 theo nhóm, giá trị trả về không hợp lệ và debug opt-in/không ghi đè. Chạy từ thư mục ứng dụng:

```text
cscript //nologo tests\testRuntimeQueries.vbs custom_helpers\hfssVivaldiChecks.vbs
```

Fixture chỉ dùng FakeEditor/FakeProject, không tạo hay validate CAD HFSS. Test này chưa được chạy ở Cloud và không thay thế runHFSSBuildIntegration trên HFSS thật.

## Kiểm tra đường dẫn thư viện

Kiểm thử dùng bản sao riêng trong thư mục tạm: kiểm tra đủ 26 helper; gọi khởi tạo ngoài Current Folder và lặp lại không đổi path; poll không thêm đường dẫn; tự sửa ưu tiên hfssRectangle khi bị shadow trên path, dừng khi bị shadow trong Current Folder; phát hiện thiếu từng thư mục API/custom và các file API/helper/VBS. Lỗi phải có tên và đường dẫn mong đợi/đang nhận. Không sửa/xóa file thư viện thật trong quá trình kiểm thử.

Audit Python đối chiếu toàn bộ function handle/lời gọi upstream với bảng manifest trong Builder, vị trí file thật, bảng README và cả lời gọi phụ thuộc bên trong helper. GUI có test dừng trước uifigure khi thư viện xung đột; test GUI MATLAB này chưa chạy ở Cloud. CAD/API/solver HFSS 2021 R2 vẫn PENDING.

Có thể chạy riêng các kiểm tra đường dẫn bằng `runBuildOnlyTests(tempname, 'library')`; fixture chỉ sao chép mã thư viện và bốn module, không sao chép output/reference hoặc dữ liệu mô phỏng của người dùng.


## Bản vật liệu và addpath trực tiếp

`runBuildOnlyTests` gồm 28 nhóm kiểm tra dữ liệu, công thức, đường dẫn và sinh script. Sáu nhóm vật liệu kiểm tra 11 mặc định, PEC không conductivity giả, tìm kiếm không phân biệt hoa/thường, số không hợp lệ, từ chối điện môi cho thân, lưu/nạp/backup MAT, trùng tên và bảo toàn cấu hình hỏng. Có thể chạy riêng bằng `runBuildOnlyTests(tempname,'materials')`.

Script hồi quy bao gồm Aluminum, Copper, PEC và custom metal có conductivity số lẻ; kiểm tra snapshot/job.json, gán tất cả phần thân, coax Copper, MaterialValue/SolveInside, lệnh readback. Các assertion này chỉ xác minh script được sinh, không xác nhận HFSS đã thực thi. Fixture VBS bổ sung đối chiếu thuộc tính đủ/thiếu mặc định/mismatch/không hợp lệ; chưa chạy vì không có cscript Windows.

GUI test bổ sung cửa sổ thư viện, tìm kiếm, OK/Cancel, thêm/lưu custom metal và mở lại. GUI MATLAB thật còn PENDING.

Để chạy riêng các ca vật liệu CAD trên Windows (không chạy solver):

```matlab
addpath('tests');
runHFSSBuildIntegration('D:\Program Files\AnsysEM\AnsysEM21.2\Win64\ansysedt.exe', ...
    fullfile(tempdir,'Vivaldi_VatLieu'), true, false, true);
```

Ca Aluminum/Copper/PEC/custom metal trong báo cáo tích hợp đều PENDING cho tới khi thực thi thành công trên HFSS 2021 R2. Các CHECK_01..18, compiler Windows, ValidateDesign, SaveAs, solver và thuộc tính HFSS đọc lại đều chưa được kiểm chứng thực tế trong Cloud. Không coi lint, fixture hoặc script generation là kết quả CAD.
