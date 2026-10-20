# Cơ chế hfss-api và các mở rộng

Không còn backend COM trực tiếp trong MATLAB. `VivaldiHFSS` tải thư viện qua `hfssIncludePaths`, tạo `VivaldiScriptWriter`, gọi helper gốc với file identifier thật, đóng tệp rồi thực thi bằng `hfssExecuteScript`. `VivaldiScriptWriter.capture` dùng `fopen`/`fclose`, gọi helper thực và đọc đúng đầu ra, không tái tạo primitive bằng wrapper khác.

Các helper cũ chủ yếu nhận số và ghi `%f` hoặc `%.4f`. Adapter giữ helper là nguồn sinh lệnh, thay những trường khai báo rõ bằng biểu thức hoặc số `%.17g`. Mỗi trường phải được tìm thấy đúng một lần; nếu upstream đổi format, generation báo lỗi. Không dùng regex để sửa file AEDT gốc và không biến toàn bộ CAD thành hằng số số học.

| Helper được gọi thật | Phần dùng trong ứng dụng |
|---|---|
| hfssNewProject, hfssInsertDesign | Chỉ mode dựng mới hoặc project kiểm tra riêng |
| hfssOpenProject, hfssSetDesign | Mở nếu chưa có, bind đúng tên/path; update không NewProject/InsertDesign |
| hfssRectangle, hfssBox, hfssCylinder, hfssCircle | Tạo primitive, giữ WCS nguồn và biểu thức liên kết |
| hfssSubtract, hfssUnite, hfssRotate, hfssMove | Boolean, transition và dịch phân cực hai |
| hfssCreateRelativeCS, hfssSetWCS | Tạo CS gốc; bổ sung parent/local origin symbolic bằng ChangeProperty |
| hfssThickenSheet | Thay Thickness bằng biến, BothSides=true có kiểm chứng format |
| hfssAssignMaterial, hfssAssignLumpedPort, hfssAssignRadiation | Vật liệu/cổng/biên; sửa SolveInside aluminum=false và signature impedance 2021 |
| hfssInsertSolution | Adaptive setup với đầy đủ 8 arguments, giữ 5GHz/.02/min5/max50/conv3/refine10 |
| hfssInsertFarFieldSphereSetup | Giữ dữ liệu helper, đổi method Automation thành InsertInfiniteSphereSetup cho 2021 R2 |
| hfssSetVariable | Tạo cả biến độc lập và biểu thức dẫn xuất; adapter giữ Value chính xác và PropType riêng của alpha |
| hfssVariableChange | Chỉ các independent variables thay đổi; không làm tròn 6 chữ số |
| hfssSaveProject | Chỉ lưu shell mới và Save As có chủ đích; Save thường dùng oProject.Save vì helper luôn SaveAs |
| hfssSolveSetup | Gọi helper, chuyển Solve(Array) cũ sang Analyze "Setup1"; không AnalyzeAll |
| hfssCreateReport, hfssExportToFile | Báo cáo/CSV thật; sửa category Modal Solution Data và nominal families |
| hfssExecuteScript | Khởi chạy HFSS thực thi VBS; status job quyết định thành công |

`hfssHollowCylinder` được nghiên cứu nhưng không dùng cho chain coax: phải chụp outer cylinder còn đặc trước khi hollowing, sau đó mới Subtract six cutters. Gọi hai hfssCylinder và hfssSubtract riêng bảo toàn thứ tự và checkpoint. `hfssSweepAnalysis` là Optimetrics Parametric Sweep, không dùng thay Frequency Sweep.

## Những chức năng thư viện thiếu

Equation Surface thực dùng `CreateEquationSurface`/`EquationBasedSurfaceParameters`. DuplicateAroundAxis helper runtime so sánh inventory trước/sau để đặt tên clone, hỗ trợ Z=-90°, NumClones=2 trong RelativeCS1. Region absolute padding, source permeability, mesh flags, EditSources, point/volume/face probes, status và rollback không có helper tương đương đầy đủ; chúng được bổ sung tại các module hiện tại. Không thêm hàng chục wrapper tách rời.

## Tương thích launcher và quản lý job

Giữ upstream nguyên vẹn, chỉ mở rộng `third_party/hfss-api/general/hfssExecuteScript.m`:

```matlab
[status, process] = hfssExecuteScript(exe, script, false, false, false);
```

Tham số thứ năm `waitForExit` mặc định true giữ cách gọi 2/3/4 arguments cũ. Khi false dùng Java ProcessBuilder với từng argument, không shell interpolation. Sửa khởi tạo `runAndExit` cho trường hợp 3 arguments. Trả status=0 chỉ có nghĩa process được khởi chạy. Không đợi launcher kết thúc để suy ra CAD thành công.

VBS được ghi UTF16LE BOM, lấy HFSS 2021.2 bằng version-specific ProgID thay ProgID HFSS9 trong output helper. Script kiểm tra GetVersion; không tự khẳng định ProgID nào tồn tại trên mọi máy. Nếu class chưa đăng ký, log lỗi; không silently đổi sang kiến trúc khác.

Mỗi script có JOB ID riêng, file status cùng ID, marker VERIFIED và terminal phù hợp action. Parser chỉ đọc dòng hoàn tất. Trường PARAM phải đủ 19 giá trị và khớp job. Timeout không giải phóng khóa hoặc đánh dấu successful. Nhật ký tách execution/geometry; chỉ phép đo đã chạy đạt mới ghi geometry PASS. Windows/HFSS runtime còn PENDING tại thời điểm refactor.
