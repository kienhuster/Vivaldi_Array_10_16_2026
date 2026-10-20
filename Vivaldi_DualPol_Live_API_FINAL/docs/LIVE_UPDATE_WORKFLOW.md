# Cập nhật trong cùng Working Project

**Dựng mới:** hfssNewProject → hfssInsertDesign → SaveAs shell rỗng để định danh → variables/CAD/ports/solver → runtime probes. Geometry chỉ được lưu khi người dùng chọn Lưu dự án. Nếu build lỗi, shell trên đĩa vẫn rỗng; CAD hỏng đang ở bộ nhớ không tự save.

**Bản sao từ nguồn:** tạo file làm việc riêng, chỉ chuẩn hóa Move Y của cable_mid_1 từ literal 2mm thành thickness trên bản sao. Không sửa AEDT gốc. Đây là copy CAD, không phải scratch build. Mở dự án phải đọc và validate bộ biến trong bản lưu.

**Mở/Update:** hfssOpenProject chỉ gọi OpenProject nếu tên chưa mở; cùng tên nhưng khác đường dẫn bị chặn. hfssSetDesign chọn đúng design DrivenModal. Script update không chứa NewProject/InsertDesign/Save/Analyze. hfssVariableChange chỉ được gọi cho biến khác LastValid, giữ %.17g. Các công thức dẫn xuất và history CAD chịu trách nhiệm tái tính.

Trước mutation, verify 19 literal + 12 derived expressions so với baseline đã xác nhận. Sau mutation đo flare rỗng/metal, BothSides, cavity, coax, port, inventory và ValidateDesign. Nếu lỗi, RestorePrevious ghi lại những biến đã đổi và chạy lại các kiểm tra. Update vẫn thất bại dù rollback đạt. Rollback thất bại không đánh dấu healthy, không cho Save/Update mới trước khi phục hồi/validate.

Save thường dùng oProject.Save vì helper hfssSaveProject luôn là SaveAs. Menu Lưu thành phiên bản mới gọi helper với đích mới không tồn tại. Sau Save, MATLAB đọc lại file để kiểm tra variables/ports/radiation/NoArray. Mở lại bản lưu có xác nhận bỏ thay đổi chưa lưu, CloseProject đúng Working Project, rồi mở lại. Không đóng/mở project cho mỗi update thông thường.

Kết quả được làm stale trước update/restore/solve, kể cả khi update sau đó rollback. Validate không đổi hình học giữ kết quả hiện tại nếu baseline không đổi. Sửa CAD bằng tay ngoài ứng dụng chỉ có thể được phát hiện trong phạm vi probes; unsaved flag theo dõi ứng dụng, không phải tất cả chỉnh sửa ngoài HFSS.

Không còn COM handles persistent trong MATLAB. Mỗi script ràng buộc lại Desktop/project/design qua thư viện và kiểm tra đường dẫn. Trạng thái kết nối trên GUI là lần phản hồi gần nhất, không phải heartbeat liên tục. Launcher bất đồng bộ; timeout giữ job chưa kết thúc để tránh hai script ghi cùng project. Kiểm tra lại trạng thái trong menu Nâng cao.
