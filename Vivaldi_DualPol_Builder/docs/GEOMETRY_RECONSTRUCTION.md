# Tái dựng và đo kiểm hình học

Nguồn chính là `17_10_2026_vivaldi.aedt`, design `dual_pol_vivaldi_patch_Wflare_20`, DrivenModal/mm. Không dùng HFSSDesign1 gần rỗng hoặc mô hình Vivaldi trên Internet. Hai ảnh chuẩn chưa có trong workspace nên chưa so hình ảnh.

`Vivaldi_HFSS_Builder` gọi helper thật của hfss-api; các phần mở rộng và validator được gộp cục bộ. Bốn CS giữ đúng parent, gốc symbolic; RelativeCS1 có parent patch_td và local (0,-thickness/2,0). Normal Y của Rectangle có Width theo Z, Height theo X. Rectangle dùng covered sheet của helper thay cho wire+CoverLines riêng; mặt CAD tương đương còn cần runtime kiểm tra.

| Checkpoint | Thao tác và bằng chứng |
|---|---|
| CHECK_01 | Bốn CS; đọc parent sau khi đặt lại local origin |
| CHECK_02/03 | EquationSurface1 u=0..L_flare và EquationSurface2 u=0..slot_t_L, x=_v*(slot_feed_w/2)*exp(_u*r_flare) |
| CHECK_04 | Clone short trước trim long, không làm mất short gốc |
| CHECK_05 | Rotate short quanh slot_t_td Y bằng deg_slot_t (default21°) |
| CHECK_06/07 | Rectangle1/2/3 trong slot_feed_td; Unite thành cutter tổng |
| CHECK_08 | Subtract cutter khỏi Vivaldi sheet; đo tâm rỗng, hai mép metal, slot/cavity |
| CHECK_09 | Thicken thickness, BothSides=true; đo trong/ngoài ±t/2 và lỗ còn rỗng |
| CHECK_10 | Duplicate Z=-90deg, NumClones=2 trong RelativeCS1, Move Y=thickness; đo pol2 |
| CHECK_11/12 | Box1, De và Unite thân; cả hai vùng flare vẫn rỗng |
| CHECK_13/14 | Tạo coax1/port1, duplicate/Move coax2/port2 theo cùng phép biến đổi |
| CHECK_15 | 6 full-cylinder snapshots trước hollowing, Subtract khỏi nhôm, giữ 4 conductors, đo volume/ports |
| CHECK_16 | 2 Lumped Ports50Ω, outer-to-inner; field phase vẫn chờ đối chiếu |
| CHECK_17 | Region20mm sáu hướng, Open1 Radiation |
| CHECK_18 | Mesh nguồn, Setup1, sweep Discrete, farfield và excitation; chưa tự solve |

Sau Subtract, hệ thống không chỉ hỏi object còn tên hay bounding box. Probe z=10/25/40mm nếu nằm trong miền loe hợp lệ, đồng thời ba cao độ tương đối cho kích thước khác. Tâm phải rỗng, hai bên phải có metal. Phép biến đổi nguồn áp dụng cả probes pol2. Sau thicken thêm điểm ±0.45t trong metal và ±0.55t ngoài metal. Không hỗ trợ point-query trên sheet thì dừng và báo chưa kiểm chứng/không đạt.

Coax được đo volume πr²h và π(ro²-ri²)h, điểm lõi/bore/annulus; port face area πr_mid² và face center; material/SolveInside đọc lại. Body vertex bounds chỉ là bằng chứng bổ sung. Cuối cùng đúng 8 top-level parts, 2 Lumped Ports, Open1 và ValidateDesign success code1.

Khác biệt công khai: dùng sacrificial snapshot với KeepOriginals=false thay tool operand giữ lại trong nguồn; snapshot chụp outer còn đặc trước hollowing. Middle cutter Move dùng thickness thay literal2mm. Default tương đương công thức, không tuyên bố CAD tương đương đã chạy. Ports dùng tọa độ symbolic outer-to-inner, không lấy Edge IDs cũ; hướng azimuth/pha cần so field nguồn. Không thêm FR4/PTFE/Rogers hoặc array/Optimetrics.

Execution PASS chỉ xác nhận phần gọi/readback của bước đã chạy; geometry PENDING nếu chưa đo đầy đủ. CHECK08/09/10/12/15 mới ghi geometry PASS sau các probes thực. Sinh script trên cloud không sinh PASS cho CAD. Mỗi checkpoint được ghi vào status UTF-16LE; chưa chạy HFSS thật thì toàn bộ CAD vẫn Pending. Save chỉ xảy ra sau full validation, không lưu shell trước CAD. Không có ảnh CAD giả hoặc tự export screenshot chưa hỗ trợ.
