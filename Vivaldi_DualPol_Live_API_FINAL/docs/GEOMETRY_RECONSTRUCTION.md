# Tái dựng CAD

Chuỗi thực thi nằm ở `HFSSGeometryBuilder`, các builder con và `HFSSGeometryValidator`. Mỗi method gọi trực tiếp COM và dừng nếu có lỗi. Đây là implementation chưa có xác nhận CAD thực tế trên môi trường bàn giao.

| Checkpoint | Thao tác / bằng chứng runtime cần có |
|---|---|
| CHECK_01 | Tạo Global-relative slot_t_td, slot_feed_td, patch_td, RelativeCS1; parent cuối là patch_td, đọc lại Reference CS |
| CHECK_02 | EquationSurface1: x=_v*(slot_feed_w/2)*exp(_u*r_flare), y=0, z=_u, u=0..L_flare; object và face IDs |
| CHECK_03 | EquationSurface2 cùng công thức, u=0..slot_t_L; object và face IDs |
| CHECK_04 | Copy short surface trước xoay, Subtract khỏi long surface, giữ short gốc |
| CHECK_05 | Rotate EquationSurface2 quanh slot_t_td Y, góc deg_slot_t |
| CHECK_06 | Ba rectangle + CoverLines trong slot_feed_td, normal Y; Width theo Z, Height theo X |
| CHECK_07 | Unite composite cutter; không còn cutter ngoài dự kiến |
| CHECK_08 | Subtract cutter khỏi Vivaldi sheet trong patch_td; probe lỗ flare, 2 mép metal và slot/cavity |
| CHECK_09 | ThickenSheet thickness, BothSides=true; probe vùng ±0.45t/±0.55t và lỗ vẫn rỗng |
| CHECK_10 | Duplicate Z=-90deg quanh RelativeCS1, NumClones=2, Move +thickness Y; probe flare thứ hai |
| CHECK_11 | Box1 local RelativeCS1 và De Global, toàn bộ dùng biểu thức |
| CHECK_12 | Unite 2 tấm + connector + base; kiểm tra cả 2 flare |
| CHECK_13 | Inner/outer/middle coax1 và circular port1 trong slot_feed_td |
| CHECK_14 | Clone feeds và port quanh RelativeCS1, Move +thickness |
| CHECK_15 | 6 full-cylinder snapshots, hollow copper outer, Subtract 6 cutters khỏi metal, đo volume/port/void |
| CHECK_16 | 2 Lumped Ports 50ohm, mode1; đọc danh sách excitations |
| CHECK_17 | Region 20mm sáu hướng; Open1 Radiation đọc lại |
| CHECK_18 | DrivenModal Setup1, discrete sweep, 3 farfield spheres, excitation mặc định 1W/0W |

Các số nguồn không thay biểu thức. Ví dụ RelativeCS1 local (0,-thickness/2,0) so với patch_td. Box1 sizes (thickness,thickness,-L_patch). Base position ((de_L+thickness)/2,-(de_W-aperture_w)/2,z_feed-h3_slot_feed-slot_feed_w), sizes (-de_L,de_W,-h_de).

Flare probes chọn z=10,25,40mm khi các mặt cắt nằm trong đoạn loe hợp lệ; thêm ba cao độ tương đối khi thiết kế đổi. Mỗi mặt cắt đo tâm phải rỗng, hai điểm giữa mép flare và biên tấm phải là metal. Phép biến đổi dual-pol áp dụng cho cả probes của tấm thứ hai. Bounding box chỉ là kiểm tra bổ sung. Nếu point-query trên sheet không được HFSS hỗ trợ, compatibility test và CHECK_08 sẽ dừng; không dựng tiếp một tấm đặc rồi báo thành công.

Coax đo volume inner/outer so với πr²h và π(ro²-ri²)h, point topology trong bore/annulus, port area πr_mid² và tâm face. Sau cùng inventory phải đúng tám top-level names. ValidateDesign chỉ được chấp nhận nếu trả số 1. Các mẫu hữu hạn không chứng minh toàn bộ miền liên tục; phải inspect CAD và field phase trước khi dùng cho chế tạo hoặc RF study.

Debug Build có thể dừng ở từng checkpoint bằng hộp thoại Continue/Stop để xem Modeler thật trong HFSS. Object tree ở GUI là inventory top-level, không phải toàn bộ child history. Không có ảnh HFSS giả; export ảnh HFSS tự động chưa triển khai vì chưa kiểm chứng signature 2021 R2, có thể chụp trực tiếp trong HFSS khi gửi log.

Mỗi record có executionStatus và geometryStatus riêng. Checkpoint đã dispatch/query được có thể executionStatus=PASS nhưng geometryStatus=PENDING nếu chưa đo đủ; không gộp chúng thành xác nhận toàn bộ CAD. Các probes thực đo thành công mới ghi geometryStatus=PASS trong phạm vi mẫu đã đo.
