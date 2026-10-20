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
