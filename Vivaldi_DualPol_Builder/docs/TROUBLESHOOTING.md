# Chẩn đoán

| Hiện tượng | Cách xử lý |
|---|---|
| 800a0408, dòng 1 ÿþO | Bản này xuất .vbs ASCII không BOM/NUL; không dùng UTF-16 cho script. Không mở rồi lưu lại script bằng encoding khác. Kiểm tra file mới trong scripts/<id>/build.vbs. |
| Đường dẫn có tiếng Việt | Script dùng ChrW để giữ Unicode chính xác. Không tự bỏ dấu đường dẫn. Status dùng UTF-16LE riêng. |
| Compiler VBScript từ chối | Xem build.vbs.syntax.log. Bản syntax có WScript.Quit 0 trước mọi thực thi; HFSS chưa được launch. |
| Không có ACK từ HFSS | Kiểm tra executable 2021 R2, license, hộp thoại Ansys và launcher.log. Chưa có ACK không có nghĩa dựng xong. |
| Checkpoint FAIL | Xem CHECK cuối trong status.txt; không có nhãn file anten hoàn chỉnh. Sửa tham số rồi bấm tạo để cấp tên mới. |
| Point-query không hỗ trợ | Cần xác minh API bằng HFSS thật. Không bỏ guard để tự báo PASS. |
| Không thấy file AEDT | Save chỉ chạy sau toàn bộ CAD/Validate; không lưu shell rỗng. Dựng lỗi có thể không tạo AEDT. |
| Tên đã tồn tại | Chương trình tự lấy số tiếp theo; kiểm tra lại ngay trước Save và overwrite=false. |
| Không có đồ thị | Chỉ mô phỏng file vừa build thành công. Không có dữ liệu thật thì không vẽ kết quả. Xem UNAVAILABLE hoặc lỗi report trong log. |

## CHECK_02/03 báo lỗi 450 sau khi đã thấy mặt loe

Một mặt tím trong HFSS cho biết có hình được hiển thị, chưa đủ chứng minh toàn bộ phép dựng đúng. Ở báo cáo lỗi đã nhận, lỗi xuất hiện trong phép kiểm tra sau CreateEquationSurface; thông báo cũ «Không có mặt loe dài» đã gộp lỗi query với không tìm thấy tên.

Bản vá đọc riêng Sheets bằng QueryGroup("Sheets"), chuẩn hóa SAFEARRAY/chuỗi đơn/nhóm rỗng rồi mới kiểm tra tên. ObjectNames không còn dùng default Item/Keys của Dictionary; vẫn truy vấn đủ Sheets, Solids, Lines và Unclassified. Một nhóm truy vấn lỗi sẽ được ghi rõ và buộc dừng, không được biến thành danh sách rỗng hay bỏ qua kiểm chứng.

- COMMAND: checkpoint, tên công đoạn và lệnh thực tế.
- OPERATION ... METHOD_OK: lệnh trả về không có lỗi API; chưa chứng nhận CAD.
- QUERY ... ERROR: phương thức/nhóm, mã lỗi, Err.Source và Err.Description. QUERY ... OK có kiểu trả về, số lượng và tên đối tượng.
- ERROR: checkpoint, tên công đoạn, phase COMMAND/QUERY/ASSERTION, operation, lệnh đang thực hiện, mã lỗi/nguồn/mô tả. QUERY lỗi không được mô tả là mặt chưa tạo; ASSERTION chỉ được dùng nếu query chạy được và predicate trả False.

Copy/Paste, DuplicateAroundAxis, truy vấn point/volume/face/material và cổng cũng ghi method nội bộ trước khi gọi. Các helper CAD được guard từng statement thay vì chỉ xét lỗi cuối block. Không loại bỏ probe hoặc checkpoint CHECK_01..18.

Trong GUI, bật **Lưu CAD debug riêng nếu gặp lỗi (chưa hoàn chỉnh)** trước khi bấm Tạo anten HFSS. Khi lỗi, chương trình thử lưu `scripts/<id>/CAD_DEBUG_INCOMPLETE.aedt`, overwrite=false; log DEBUG ghi kết quả riêng. File này không có nghĩa anten hoàn chỉnh: job vẫn FAILED, không VERIFIED và không bật nút mô phỏng. Nếu SaveAs debug cũng lỗi, lỗi gốc vẫn được giữ trong ERROR. Tùy chọn mặc định tắt.

Có thể sinh script debug qua API:

```matlab
p = Vivaldi_Calculation('defaults');
c = Vivaldi_HFSS_Simulation('defaults');
job = Vivaldi_HFSS_Builder('generate', p, 'D:\Vivaldi_Output', c, 'full', true);
```

Các phép CAD trong bản vá chưa chạy trên HFSS tại Cloud: PENDING. Để chẩn đoán tiếp trên Windows, đọc toàn bộ status.txt và xác định QUERY ... ERROR hoặc ERROR đầu tiên, không chỉ dòng CHECK cuối.
