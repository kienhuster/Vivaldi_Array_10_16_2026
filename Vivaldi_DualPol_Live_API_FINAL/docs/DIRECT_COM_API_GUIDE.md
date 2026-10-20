# Kiến trúc Direct COM

`HFSSCOMConnection` giữ Application, Desktop, Project, Design, Editor và cache module. `actxGetRunningServer` được thử trước cho tất cả ProgID phù hợp, rồi mới `actxserver` nếu cho phép tạo phiên. `GetAppDesktop` lấy Desktop. `GetVersion` kiểm tra 2021.2. Các handles dùng lại qua những lần Update. `invoke` là gateway; không có VBS, RunScript hoặc subprocess trong runtime.

ProgID ứng viên `Ansoft.ElectronicsDesktop.2021.2` và `Ansoft.ElectronicsDesktop` cần kiểm tra registry máy đích bằng Detect. Không đảm bảo cả hai tồn tại. `winqueryreg` đọc CLSID đăng ký, còn Connect/Test mới chứng minh gọi được server. Có thể nhập ProgID thực tế vào ô GUI. Không tự sửa registry hoặc đăng ký COM trong ứng dụng.

## Nested VARIANT/SAFEARRAY

Các mảng `Array(...)` của Automation được biểu diễn bằng row cell MATLAB lồng nhau, ví dụ:

```matlab
args = {'NAME:AllTabs', ...
    {'NAME:LocalVariableTab', {'NAME:PropServers','LocalVariables'}, ...
    {'NAME:ChangedProps', {'NAME:L_flare_1','Value:=','43.287mm'}}}};
session.call(session.Design, 'ChangeProperty', args);
```

Gateway truyền `invoke(handle,method,varargin{:})`; các cell bên trong không bị flatten. Giá trị logic và số giữ đúng kiểu, biểu thức HFSS dùng char. Không ghép command text để thực thi. Không dùng `get` để giả lập method invocation: `get` chỉ phù hợp với COM property; trong AEDT phần lớn thao tác cần các method Get... qua invoke.

`runCOMCompatibilityTests` là mã kiểm chứng độc lập: thiết kế DrivenModal thử, Box, biến 10→12.345mm, vertex bounds đọc lại, điểm trong/ngoài, sheet có lỗ, Thicken ±1mm, SaveAs và đóng đúng project thử. Báo cáo chỉ PASS nếu tất cả assertions thực chạy. Linux trả PENDING. FAIL không được đổi thành Direct COM Verified. Test cơ bản chưa chứng minh CreateEquationSurface hoặc toàn bộ anten trên 2021 R2; chạy integration suite riêng.

Nếu MATLAB COM không marshal được nested cell của một method, log ghi method/identifier/message và dừng. Chưa có bằng chứng runtime để chọn một phương án marshaling khác; không ngụy tạo một đường truyền đã kiểm chứng. Cần log máy Windows để xác định phương thức cụ thể. Không có fallback VBScript.

## Vòng đời

Monitor dùng timer 5 giây, bỏ qua khi đang thao tác. `GetVersion` thất bại làm session mất kết nối. Reconnect tạo lại các proxy; người dùng Open Working Project để bind đúng design và validate lại. Đóng GUI giải phóng MATLAB proxy, không QuitApplication và không đóng project người dùng. Run/Analyze là COM đồng bộ và có thể chặn UI; không hứa hẹn Cancel tức thời.

## Nguồn tham khảo API

Đã đọc 11 helper được yêu cầu trong `yuip/hfss-api` commit `a3fd32a418c726070f51e73273de93c5080bdb8d`. Chỉ tham khảo tên lệnh và cấu trúc tham số; không đóng gói hoặc sao chép mã GPL đó. `hfssThickenSheet` cũ ghi BothSides=false nên không dùng. `hfssSweepAnalysis` là Optimetrics, không phải frequency sweep; ứng dụng dùng InsertFrequencySweep của AnalysisSetup.

Đối chiếu thêm mã Ansys PyAEDT v0.6.94 commit `0e7642bd2d07711f2912e221521e2354e7ab31e2` (CreateRelativeCS/DuplicateAroundAxis/point query/material/port/report) và nguồn Ansys hiện hành `primitives_3d.py` cho `CreateEquationSurface` với block `EquationBasedSurfaceParameters`. Tên method và trường dữ liệu đã đối chiếu mã tham khảo, **chưa xác minh runtime 2021 R2**. Không phụ thuộc các thư viện này khi chạy.

Liên kết: https://github.com/yuip/hfss-api/ ; https://github.com/ansys/pyaedt/tree/v0.6.94 ; https://github.com/ansys/pyaedt/blob/main/src/ansys/aedt/core/modeler/cad/primitives_3d.py .
