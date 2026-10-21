# Vivaldi Dual-Pol — Dựng anten mới bằng hfss-api

Mỗi lần bấm **Tạo anten HFSS**: kích thước MATLAB → công thức nguồn → project HFSS trống → dựng đầy đủ anten nhôm/coax hai phân cực → kiểm tra CAD/Validate → lưu AEDT mới. Không Live Update, Working Project, rollback hoặc copy AEDT nguồn. Không tạo project khi chỉ mở GUI.

## Chạy

Trên Windows có MATLAB R2021a+ và HFSS 2021 R2, đặt Current Folder vào `Vivaldi_DualPol_Builder`:

```matlab
Vivaldi_GUI
```

1. Nhập kích thước trong miền hợp lệ; công thức/preview tự tính, không gửi HFSS.
2. Chọn thư mục xuất và `ansysedt.exe` trong tab Tạo anten HFSS.
3. Bấm Tạo anten HFSS, theo dõi Nhật ký. Mỗi lần cấp tên mới như Vivaldi_DualPol_001.aedt, _002.aedt; không ghi đè.
4. Sau khi HFSS xác nhận và lưu thành công, bấm Mở file HFSS vừa tạo hoặc Chạy mô phỏng. Solver không tự chạy trong build.

## Mã nguồn gọn

- `Vivaldi_GUI.m`: năm tab tiếng Việt, sáu nút, callback lồng theo mẫu Standard_Vivaldi_GUI.
- `Vivaldi_Calculation.m`: tham số/công thức/kiểm tra nguồn, không giới hạn preset.
- `Vivaldi_HFSS_Builder.m`: toàn bộ thứ tự CAD và helper đặc thù gộp trong file.
- `Vivaldi_HFSS_Simulation.m`: port, setup, Discrete Sweep, solver và đọc CSV thực.
- `custom_helpers/`: ghi/escape script, phép đo CAD VBS và preview; không có class/session COM.
- `third_party/hfss-api/`: nguyên thư viện upstream có GPL và provenance.
- `tests/`, `docs/`, `reference/`: kiểm tra, hướng dẫn và dữ liệu đối chiếu.

Script `.vbs` là ASCII không BOM; Unicode đường dẫn được giữ bằng ChrW. Status là UTF-16LE riêng. Trước launch, compiler cscript Windows kiểm tra toàn bộ script bằng bản thoát ngay trước thực thi.

Tên file được giữ chỗ bằng thư mục `.aedt.reserve`; thư mục này và scripts/status/CSV là output, không phải mã nguồn để commit. Mỗi job có thư mục `scripts/<id>` riêng. Dựng lỗi không báo anten hoàn chỉnh và không lưu project rỗng.

## Tình trạng kiểm chứng

Kiểm tra công thức, gọi helper sinh script và guard chạy trên Linux/Octave. **GUI MATLAB, compiler VBS Windows, CAD HFSS và solver còn Pending**, chưa có bằng chứng dựng anten thật. Xem [báo cáo kiểm tra](docs/VALIDATION_REPORT.md), [giới hạn](docs/KNOWN_LIMITATIONS.md), [cài Windows](docs/INSTALL_WINDOWS.md) và [chẩn đoán](docs/TROUBLESHOOTING.md).

Hai tệp nguồn ngày17/10 ở repository root và reference được bảo toàn SHA256. Standard_Vivaldi_GUI.m trong reference chỉ dùng đối chiếu phong cách, không phải ứng dụng bổ sung và không thay hình học nguồn. Thư mục reference không được addpath.

Mã kết hợp dùng GPL-2.0-or-later; giữ nguyên COPYING/NOTICE và thông tin tác giả upstream. MATLAB/Ansys và dữ liệu người dùng giữ quyền tương ứng.

Bản vá CHECK_02/03 tách truy vấn Sheets khỏi phép dựng mặt; xem mục lỗi450 trong [chẩn đoán](docs/TROUBLESHOOTING.md). Checkbox lưu CAD debug tạo file INCOMPLETE riêng khi lỗi; không phải anten hoàn chỉnh. CAD thực tế của bản vá còn Pending.

## Đường dẫn thư viện được kiểm tra tường minh

Root được lấy từ `fileparts(mfilename('fullpath'))`, không phụ thuộc Current Folder. `Vivaldi_HFSS_Builder('initialize')` trả về các đường dẫn tuyệt đối và kết quả `which()` đã xác minh. GUI chạy khởi tạo trước khi tạo cửa sổ; lỗi thư viện ngăn tạo anten. Sinh script/chạy HFSS kiểm tra lại, còn timer `poll` không addpath.

Chỉ nạp root ứng dụng, `custom_helpers`, `third_party/hfss-api` và tám thư mục con `general`, `3dmodeler`, `boundary`, `analysis`, `radiation`, `reporter`, `mesh`, `fieldsCalculator`. Không gọi `genpath` hoặc phụ thuộc `hfssIncludePaths` nữa. Hai thư mục mesh/fieldsCalculator vẫn được kiểm tra tồn tại dù chưa có helper trực tiếp được dùng từ đó.

Mọi thư mục/file phải qua `isfolder`/`isfile`; mỗi hàm phải được `which()` nhận đúng file trong bản dự án. Phát hiện bản ngoài dự án sẽ dừng với tên helper, đường dẫn mong đợi và đường dẫn đang nhận, không âm thầm che xung đột. Gỡ thư mục gây xung đột khỏi MATLAB path hoặc đổi Current Folder nếu nó chứa helper trùng tên, rồi mở GUI lại.

| Hàm | Thư mục tính từ `Vivaldi_DualPol_Builder` | File chính xác |
|---|---|---|
| `hfssAssignLumpedPort` | `third_party/hfss-api/boundary` | `hfssAssignLumpedPort.m` |
| `hfssAssignMaterial` | `third_party/hfss-api/3dmodeler` | `hfssAssignMaterial.m` |
| `hfssAssignRadiation` | `third_party/hfss-api/boundary` | `hfssAssignRadiation.m` |
| `hfssBox` | `third_party/hfss-api/3dmodeler` | `hfssBox.m` |
| `hfssCircle` | `third_party/hfss-api/3dmodeler` | `hfssCircle.m` |
| `hfssCreateRelativeCS` | `third_party/hfss-api/3dmodeler` | `hfssCreateRelativeCS.m` |
| `hfssCreateReport` | `third_party/hfss-api/reporter` | `hfssCreateReport.m` |
| `hfssCylinder` | `third_party/hfss-api/3dmodeler` | `hfssCylinder.m` |
| `hfssExecuteScript` | `third_party/hfss-api/general` | `hfssExecuteScript.m` |
| `hfssExportToFile` | `third_party/hfss-api/reporter` | `hfssExportToFile.m` |
| `hfssInsertDesign` | `third_party/hfss-api/general` | `hfssInsertDesign.m` |
| `hfssInsertFarFieldSphereSetup` | `third_party/hfss-api/radiation` | `hfssInsertFarFieldSphereSetup.m` |
| `hfssInsertSolution` | `third_party/hfss-api/analysis` | `hfssInsertSolution.m` |
| `hfssMove` | `third_party/hfss-api/3dmodeler` | `hfssMove.m` |
| `hfssNewProject` | `third_party/hfss-api/general` | `hfssNewProject.m` |
| `hfssOpenProject` | `third_party/hfss-api/general` | `hfssOpenProject.m` |
| `hfssRectangle` | `third_party/hfss-api/3dmodeler` | `hfssRectangle.m` |
| `hfssRotate` | `third_party/hfss-api/3dmodeler` | `hfssRotate.m` |
| `hfssSaveProject` | `third_party/hfss-api/general` | `hfssSaveProject.m` |
| `hfssSetDesign` | `third_party/hfss-api/general` | `hfssSetDesign.m` |
| `hfssSetVariable` | `third_party/hfss-api/general` | `hfssSetVariable.m` |
| `hfssSetWCS` | `third_party/hfss-api/3dmodeler` | `hfssSetWCS.m` |
| `hfssSolveSetup` | `third_party/hfss-api/analysis` | `hfssSolveSetup.m` |
| `hfssSubtract` | `third_party/hfss-api/3dmodeler` | `hfssSubtract.m` |
| `hfssThickenSheet` | `third_party/hfss-api/3dmodeler` | `hfssThickenSheet.m` |
| `hfssUnite` | `third_party/hfss-api/3dmodeler` | `hfssUnite.m` |
| `hfssVivaldiScript` | `custom_helpers` | `hfssVivaldiScript.m` |
| `vivaldiPreview3D` | `custom_helpers` | `vivaldiPreview3D.m` |
| Runtime CAD (đọc bằng đường dẫn đầy đủ) | `custom_helpers` | `hfssVivaldiChecks.vbs` |

`hfssVivaldiExtensions` là hàm cục bộ trong `Vivaldi_HFSS_Builder.m`, không phải helper upstream hoặc một file cần thêm vào path. Không tạo file wrapper riêng cho nó.

Có thể mở ứng dụng từ Current Folder khác bằng cách thêm riêng root ứng dụng:

```matlab
addpath('D:\Vivaldi_Array_10_16_2026\Vivaldi_DualPol_Builder');
Vivaldi_GUI
```
