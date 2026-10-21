# Vật liệu, đường dẫn và bàn giao

## Chọn và lưu

Mở `Vivaldi_GUI` từ thư mục ứng dụng. Tab Thông số anten → Thư viện → tìm tên hoặc chọn dòng → OK. Cancel giữ lựa chọn cũ; chưa chọn dòng thì OK yêu cầu chọn. Add Material... mở form thêm tên/loại/thông số, Lưu cập nhật bảng và file dữ liệu; sau đó chọn dòng và OK mới đổi vật liệu thân. Chỉ thay lựa chọn không chạy HFSS.

Có tám điện môi theo Standard_Vivaldi_GUI, Aluminum, Copper và PEC. Điện môi dùng epsilon_r/loss tangent; kim loại dùng conductivity (S/m), mu_r, epsilon_r và loss tangent trong dữ liệu nội bộ. Form kim loại dùng epsilon_r=1, loss=0; PEC không yêu cầu thông số hữu hạn. Thân gốc không có substrate, vì vậy điện môi bị từ chối, không âm thầm thay topology. Coax luôn Copper; port/radiation giữ theo thiết kế nguồn.

Schema nhỏ dùng chung: `name`, `kind`, `permittivity`, `lossTangent`, `conductivity`, `permeability`. Tên không rỗng, kiểm tra trùng không phân biệt hoa/thường; số phải hữu hạn, epsilon/mu dương, loss/sigma không âm và sigma kim loại dương. PEC dùng bốn trường rỗng, không dùng độ dẫn lớn giả tạo.

Dữ liệu tùy chỉnh: `fullfile(prefdir,'Vivaldi_DualPol_Builder','custom_materials.mat')`. File MAT gồm `schemaVersion=1` và `customMaterials`; không lưu vào source/reference, không tự ghi khi khởi động. Ghi file tạm, sao lưu file cũ `.bak`, rồi thay file dữ liệu. File lỗi hoặc trùng tên trong cấu hình được báo cùng đường dẫn và giữ nguyên, không cho ghi đè; người dùng có thể sao lưu/sửa cấu hình riêng. Không có thao tác cập nhật tên trùng tự động.

## Script API và kiểm chứng vật liệu

MATLAB dùng helper thực của yuip/hfss-api để sinh VBScript. Chỗ thư viện thiếu chức năng dùng local function/VBScript trong các file hiện có. `hfssExecuteScript` khởi chạy ansysedt.exe bất đồng bộ; GUI đọc log theo job id, VERIFIED và trạng thái terminal cùng file thực để xác nhận, không dựa vào launcher exit code.

Builder chụp lựa chọn vào `job.bodyMaterial`, `scripts/<id>/job.json` và script. Simulation dùng snapshot của anten đã dựng, không lấy lựa chọn GUI vừa đổi. Các phép gán thân dùng tên snapshot cho Vivaldi_1, Vivaldi_2, Box1, De trước Unite. Coax Copper không thay đổi.

Lời gọi `AssignMaterial` xuất `MaterialValue:=` với tên nằm trong dấu nháy và `SolveInside:=False`, theo cách dùng trong Standard_Vivaldi_GUI tham chiếu. Helper hfssAssignMaterial upstream được capture rồi đổi khóa đầu ra; không sửa mã upstream. Script đọc lại Material/Solve Inside sau gán và kiểm tra định nghĩa qua `GetDefinitionManager().GetManager("Material").GetData(name)`.

Nếu định nghĩa có sẵn đọc được và đúng thuộc tính thì tái sử dụng. Nếu chưa có, tạo định nghĩa project bằng AddMaterial, rồi đọc lại; không EditMaterial để âm thầm đổi thuộc tính có sẵn. Sai khác dừng job và ghi công đoạn/lệnh/mã lỗi. PEC dùng `pec` tích hợp và xác minh sau gán, không AddMaterial với conductivity hữu hạn.

Aluminum của nguồn: sigma=38,000,000 S/m, mu_r=1.000021; Copper: sigma=58,000,000 S/m, mu_r=0.999991. AEDT nguồn bỏ các khóa epsilon/loss mặc định. Với định nghĩa NAME hợp lệ đọc thành công, chỉ khóa scalar bị thiếu mới dùng mặc định HFSS epsilon=1, mu=1, sigma=0, loss=0 và ghi MATERIAL_DEFAULT. Query lỗi, mảng rỗng, giá trị explicit không phải số hoặc thuộc tính không khớp không được coi là mặc định thành công. Các giá trị mặc định đối chiếu thêm với [MatProperties của PyAEDT v0.6.94](https://github.com/ansys/pyaedt/blob/v0.6.94/pyaedt/modules/Material.py); [MaterialLib](https://github.com/ansys/pyaedt/blob/v0.6.94/pyaedt/modules/MaterialLib.py) cho cơ chế GetData. Không thêm phụ thuộc Python/PyAEDT vào phần mềm MATLAB.

**Chưa chạy các lời gọi này trên HFSS 2021 R2 thật.** Cần xác nhận GetData, AddMaterial, AssignMaterial, readback và CAD/port/solver trên Windows. Nếu API trả dữ liệu khác, job phải báo lỗi thay vì báo hoàn thành. Fixture không thay thế kiểm tra HFSS.

## Khởi tạo thư viện

Root tính bằng `fileparts(mfilename('fullpath'))`. Trong local function sẵn có của Builder: kiểm tra isfolder/isfile, addpath tường minh, sau đó kiểm tra which từng helper. Nạp ngay trước khi tạo GUI; poll không thêm path. Không cần biến apiRoot, hfssIncludePaths, genpath, restoredefaultpath hoặc savepath.

Toàn bộ thư mục được addpath, theo thứ tự câu lệnh:

1. Root `Vivaldi_DualPol_Builder`.
2. `third_party/hfss-api/boundary`.
3. `third_party/hfss-api/3dmodeler`.
4. `third_party/hfss-api/analysis`.
5. `third_party/hfss-api/general`.
6. `third_party/hfss-api/radiation`.
7. `third_party/hfss-api/reporter`.
8. `third_party/hfss-api/fieldsCalculator`.
9. `third_party/hfss-api/mesh`.
10. `custom_helpers`.

Không addpath thư mục API root, reference, examples hoặc tests trong sử dụng bình thường. Tất cả dùng '-begin'; bản local được ưu tiên hơn bản cũ trên path. Current Folder vẫn có ưu tiên MATLAB cao hơn nên nếu chứa helper trùng tên thì dừng với expected/actual rõ ràng. Không tự reset toàn bộ path. Bảng chính xác 26 helper và hai helper dự án nằm trong README.

## File và phạm vi thay đổi

Không thêm file MATLAB mới, giữ bốn module chính và hai helper MATLAB cũ. Sửa Vivaldi_GUI (cửa sổ vật liệu), Vivaldi_Calculation (dữ liệu MAT/validation), Vivaldi_HFSS_Builder (addpath/snapshot/gán/readback), custom_helpers/hfssVivaldiScript (biến snapshot), custom_helpers/hfssVivaldiChecks.vbs (định nghĩa/readback vật liệu), các test/audit và README/tài liệu/.gitignore/manifest. Vivaldi_HFSS_Simulation không cần đổi, vẫn dùng helper đã kiểm tra.

Không xóa helper hoặc module upstream. Loại bỏ bước chặn which trước addpath và biến apiRoot của bản trước; không loại kiểm chứng CAD, checkpoint hay tạo COM adapter mới. Công thức, topology và dữ liệu HFSS nguồn giữ nguyên. Hai ảnh cửa sổ vật liệu không có trong tệp đính kèm truy cập được ở lượt này; giao diện dựa trên openMatLibrary trong file Standard được cung cấp, chưa xác nhận khớp ảnh hay render MATLAB thật.

Kết quả kiểm tra chi tiết: VALIDATION_REPORT.md và tests/verification. Trạng thái CAD, compiler Windows, GUI và solver phải giữ PENDING đến khi có kết quả thực tế.
