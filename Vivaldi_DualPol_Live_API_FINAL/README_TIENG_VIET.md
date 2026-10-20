# Vivaldi hai phân cực — bản refactor dùng hfss-api

Ứng dụng hiện tại được tinh gọn trên cùng entry point `Vivaldi_DualPol_Live_API`, dùng **MATLAB → helper thật của yuip/hfss-api → VBScript → HFSS 2021 R2**. MATLAB không giữ persistent COM handles. Update thay các biến cần thiết trong cùng Working Project, không tạo project/design mới và không tự chạy solver.

**Mức bằng chứng:** đã viết và chạy các kiểm tra khả dụng trên Linux; MATLAB desktop/GUI và HFSS CAD/solver thực tế vẫn **PENDING**. Không coi script sinh thành công hoặc launcher trả 0 là CAD đã đúng. Xem `docs/VALIDATION_REPORT.md`.

## Chạy trong MATLAB

Tải ZIP của nhánh/PR từ GitHub bằng **Code → Download ZIP**. Giải nén toàn bộ repository, đặt Current Folder vào thư mục `Vivaldi_DualPol_Live_API_FINAL`, chạy trên MATLAB R2021a+:

```matlab
Vivaldi_DualPol_Live_API
```

Ứng dụng tự gọi `hfssIncludePaths([apiRoot filesep])`; thư viện và giấy phép đã đi kèm trong `third_party/hfss-api`, không cần tải thêm Python hoặc PyAEDT. Các tên hàm/biến được giữ bằng tiếng Anh để tương thích AEDT; nội dung giao diện và chú thích lớn bằng tiếng Việt.

## Luồng sử dụng

1. Trong **Nâng cao → HFSS và kiểm tra**, chọn `ansysedt.exe`; đường dẫn có khoảng trắng được truyền bằng các argument riêng, không ghép shell khi chạy nền.
2. Chạy **Kiểm tra tương thích HFSS API** lần đầu trên Windows. Bài test tạo project thử riêng, gọi helper thật, đổi biến liên kết Box, kiểm tra sheet có lỗ và BothSides. Chỉ PASS nếu HFSS trả đúng kết quả đo.
3. Chọn đường dẫn Working Project. **Dựng anten mới** tạo từ design trống. Hoặc **Nâng cao → Dự án và tham số → Tạo bản làm việc từ nguồn** tạo bản sao CAD đã chuẩn hóa literal Move; hai chế độ được phân biệt rõ, không gọi bản sao là dựng mới.
4. Nhập số thực; kết quả dẫn xuất và xem trước tự cập nhật. **Cập nhật HFSS/Cập nhật mô hình** sinh script ngắn, chỉ đổi những biến thay đổi, đọc lại và đo CAD. Nếu lỗi, thử rollback và kiểm tra lại; không tự lưu mô hình lỗi.
5. **Lưu dự án** lưu file hiện tại. Save As, mở lại bản lưu, khôi phục biến, cấu hình JSON và debug từng bước nằm trong menu Nâng cao.
6. Chỉ **Chạy mô phỏng** mới gọi Analyze Setup1. Xuất/nhập CSV thật trong menu Nâng cao, chọn S11/S21/VSWR/Gain/giản đồ bằng một dropdown.

Ngoài Windows, chế độ **Chỉ tạo kịch bản, chưa chạy HFSS** tự bật. Có thể dùng tính toán, preview và xem VBS sinh ra ở `work/`, nhưng không được coi đó là kết quả build/update/solve. Script, status UTF16, danh sách helper thực đã gọi và thông số job được lưu cạnh nhau để chẩn đoán.

## Giao diện gọn

| Tab | Số nút chính | Chức năng |
|---|---:|---|
| Thông số anten | 3 | Chiều dài mục tiêu, mặc định, cập nhật HFSS; 19 biến độc lập và 12 dẫn xuất |
| Xem trước 3D | 0 | Một dropdown góc nhìn; vùng anten lớn, xoay/zoom bằng công cụ trục |
| Kết nối HFSS | 5 | Kết nối, mở, dựng mới, cập nhật, lưu |
| Mô phỏng | 2 | Kiểm tra mô hình, chạy mô phỏng; một dropdown chọn đồ thị |
| Nhật ký & kiểm tra | 1 | Xuất nhật ký; chọn dòng xem lỗi và bằng chứng chi tiết |

## Cấu trúc và giấy phép

- `automation/`: điều phối job, dùng thư viện, dựng Vivaldi, solver và kiểm tra runtime; không có bộ wrapper COM cũ.
- `custom_helpers/hfssVivaldiExtensions.m`: những mở rộng thiếu về biểu thức, Equation Surface, Duplicate, CS, BothSides và Discrete Sweep.
- `core/`: công thức, validation đại số, target length, preview và parser nguồn.
- `results/`: đọc/vẽ CSV thực và HPBW.
- `tests/`: hồi quy sinh script/protocol, test GUI MATLAB và test tích hợp HFSS có điều kiện.
- `third_party/hfss-api/`: nguồn upstream được pin, giữ copyright/GPL; chỉ `hfssExecuteScript` có mở rộng tương thích ngược để chạy nền.

Xem `docs/HFSS_API_GUIDE.md`, `docs/HFSS_API_EXAMPLE_STUDY.md`, `docs/KNOWN_LIMITATIONS.md`, `NOTICE.md` và `COPYING`. Hai ảnh HFSS chuẩn chưa có trong workspace; chưa so hình ảnh. Hai file nguồn ở root repository và bản tham chiếu AEDT được giữ nguyên.
