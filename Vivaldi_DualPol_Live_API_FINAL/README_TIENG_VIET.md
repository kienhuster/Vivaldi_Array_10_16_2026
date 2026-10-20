# Vivaldi Dual-Polarized Antenna — Live HFSS Designer Pro

Ứng dụng MATLAB điều khiển HFSS 2021 R2 bằng **COM trực tiếp, giữ session và Working Project**. Mã được bàn giao dưới dạng ZIP, trong thư mục riêng. Không cần Python, PyAEDT hoặc thư viện hfss-api để chạy.

**Mức kiểm chứng của bản bàn giao:** đã viết mã và kiểm tra trên Linux; MATLAB desktop, nested SAFEARRAY trên MATLAB COM, CAD HFSS và solver thực tế còn **PENDING — requires Windows MATLAB + HFSS**. Không coi kiểm thử protocol bằng mock là kiểm chứng HFSS. Đọc `docs/VALIDATION_REPORT.md` và `docs/KNOWN_LIMITATIONS.md` trước khi dùng.

## Chạy ứng dụng

1. Giải nén toàn bộ ZIP vào thư mục có quyền ghi trên Windows, ví dụ `D:\AntennaTools\Vivaldi_DualPol_Live_API_FINAL`.
2. Dùng MATLAB R2021a trở lên, đặt **Current Folder** vào thư mục vừa giải nén.
3. Chạy một lệnh:

```matlab
Vivaldi_DualPol_Live_API
```

Ứng dụng tự thêm `core`, `com`, `results`; không cần chạy các module thủ công. Khi chưa kết nối HFSS vẫn chỉnh số, tính L_patch, giải Target Length và xem preview được.

## Lần chạy đầu trên Windows

Trong tab LIVE HFSS CONNECTION, chạy **COM Compatibility Test** trước. Bài test tạo project riêng, kiểm tra nested cell/VARIANT, Box liên kết biến, vùng rỗng trên sheet, Thicken BothSides và Save/Close. Chỉ coi kết nối cơ bản đã xác nhận nếu báo cáo JSON mới có PASS. Kiểm chứng anten hoàn chỉnh là bước riêng.

Hai lựa chọn tiếp theo:

- **Create Working Copy:** sao chép AEDT tham chiếu sang đường dẫn Working Project mới, chuẩn hóa riêng Move Y của `cable_mid_1` từ `2mm` thành `thickness`, rồi mở/validate. Đây là bản sao CAD, không phải dựng từ đầu.
- **Build From Scratch:** tạo project/design trống, khai báo biến và gọi COM để dựng toàn bộ CAD, coax, port, region và solver. File rỗng ban đầu được lưu để định danh; CAD chỉ lưu khi nhấn Save sau khi các kiểm tra đạt.

Chỉnh các ô numeric → Calculate → Update Geometry. Mọi Update tiếp theo dùng cùng project/design. Không sinh VBScript. Nếu cập nhật lỗi, phần mềm thử rollback biến và validate lại; không tự Save.

## Các tab

| Tab | Chức năng |
|---|---|
| ANTENNA PARAMETERS | 19 biến độc lập, 12 biến dẫn xuất, tính/validate đại số, mục tiêu L_patch bất kỳ, JSON tùy chọn |
| GEOMETRY PREVIEW | Hai tấm trực giao, flare/transition, slot/cavity, base và coax; Front/Side/Top/Isometric, xoay/zoom |
| LIVE HFSS CONNECTION | Detect/Connect/Reconnect, working copy, build, attach/update, validate, Save/Save As/Reload |
| SIMULATION | Dải tần, excitation, chạy Setup1 riêng, xuất CSV thật, import và vẽ kết quả |
| DEBUG & DIAGNOSTICS | 18 checkpoint, dừng từng bước, object inventory, lỗi COM/CAD, restore và xuất log |

## Tài liệu và log

Hướng dẫn chi tiết trong `docs/`. Log TXT/JSON ở `logs/`; kết quả portable thực chạy trong `tests/verification/`. Nếu HFSS báo lỗi, gửi TXT, JSON chẩn đoán, phiên bản MATLAB/HFSS, checkpoint thất bại và ảnh geometry trong HFSS. Không gửi license hoặc thông tin đăng nhập.

Không có hai ảnh HFSS chuẩn trong workspace của lần bàn giao này. Chưa so sánh ảnh. AEDT ngày 17/10 là nguồn hình học chính, giữ nguyên byte trong `reference/`.
