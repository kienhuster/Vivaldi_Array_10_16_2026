# Nguồn và phân phối

Nguồn người dùng: https://github.com/kienhuster/Vivaldi_Array_10_16_2026 , ref main, AEDT ngày17/10/2026 và tài liệu phân tích. Những file này được kèm theo yêu cầu của chủ repository. Bản sao tham chiếu giữ nguyên byte và có SHA-256 trong manifest.

Engine công thức, phân loại biến, parser và preview được kế thừa có điều chỉnh từ workspace `kienhuster/Vivaldi-array` (commit178d948d510b8d96fc0d41741b972f511432ff83) do người dùng đã yêu cầu xây dựng trước. COM builders/session/working-project/live-update/test và GUI Live API được viết riêng cho yêu cầu V2. Không sửa checkout nguồn và không commit/push/PR trong lần bàn giao V2.

Tham khảo cấu trúc Automation trong hfss-api GPL và PyAEDT, không kèm hoặc copy mã các thư viện đó. Không áp đặt giấy phép mới lên dữ liệu người dùng hoặc tuyên bố sở hữu nguồn cũ. Nếu phân phối ra ngoài phạm vi chủ dự án, cần rà soát quyền đối với toàn bộ nguồn kế thừa. ZIP không chứa Ansys/MATLAB, license, kết quả giả hoặc binary thư viện ngoài.
