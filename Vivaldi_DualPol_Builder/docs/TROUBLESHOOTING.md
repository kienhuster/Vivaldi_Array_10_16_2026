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
