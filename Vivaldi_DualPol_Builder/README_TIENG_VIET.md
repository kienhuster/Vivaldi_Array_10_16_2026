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
