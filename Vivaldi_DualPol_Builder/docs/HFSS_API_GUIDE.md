# Cơ chế dựng từ đầu bằng hfss-api

Bốn file chính: `Vivaldi_GUI.m` (callback lồng, sáu nút), `Vivaldi_Calculation.m` (19 biến và công thức/kiểm tra), `Vivaldi_HFSS_Builder.m` (trình tự CAD và phép đo), `Vivaldi_HFSS_Simulation.m` (port, solver, report và CSV).

`custom_helpers/hfssVivaldiScript.m` là struct callback ghi tệp, không phải class/session COM. Nó gọi helper gốc với fid thật, thay duy nhất các trường số/biểu thức mà helper cũ không biểu diễn đủ, thêm guard lỗi và xuất script ASCII không BOM. Không viết lại Rectangle/Box/Cylinder/Boolean. `hfssVivaldiChecks.vbs` chứa các phép đo CAD và dữ liệu kết quả; `vivaldiPreview3D.m` là preview lấy mẫu. Không còn các lớp VivaldiHFSS, ScriptWriter, COM Adapter hay rollback.

Luồng dựng: fopen → hfssNewProject → hfssInsertDesign → helper CAD và phần mở rộng cục bộ → Validate → hfssSaveProject(overwrite=false) → fclose → compiler VBScript Windows → hfssExecuteScript. Preamble gốc được sửa ProgID thành Ansoft.ElectronicsDesktop.2021.2. Không có OpenProject trong script build. OpenProject chỉ dùng khi người dùng chủ động solve file vừa tạo.

Các helper thật được tái sử dụng: hfssRectangle, hfssBox, hfssCylinder, hfssCircle, hfssSubtract, hfssUnite, hfssRotate, hfssMove, hfssCreateRelativeCS, hfssSetWCS, hfssSetVariable, hfssAssignMaterial, hfssAssignLumpedPort, hfssAssignRadiation, hfssInsertSolution, hfssInsertFarFieldSphereSetup, hfssSaveProject, hfssSolveSetup, hfssCreateReport, hfssExportToFile và hfssExecuteScript.

Phần thiếu được gộp ngay trong Builder/Simulation: EquationBasedSurface, DuplicateAroundAxis và đặt tên bằng inventory diff, parent/local CS, BothSides=true, vùng Radiation 20mm, Discrete Sweep, thuộc tính vật liệu/mesh nguồn và phép đo CAD. Coax giữ snapshot hình trụ đặc trước hollowing nên không gọi hfssHollowCylinder thay thứ tự nguồn.

Thư viện upstream giữ nguyên 89 tệp và GPL; chỉ bản vá hfssExecuteScript kế thừa từ phiên bản trước được giữ. Hash/pin ở third_party/HFSS_API_PROVENANCE.json. Không có persistent COM trong MATLAB.
