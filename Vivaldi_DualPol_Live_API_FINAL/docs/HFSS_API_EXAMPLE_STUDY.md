# Đối chiếu bốn example upstream

Nguồn đọc trực tiếp: https://github.com/yuip/hfss-api , commit `a3fd32a418c726070f51e73273de93c5080bdb8d`. Đã đọc toàn bộ bốn tệp dưới đây, không chỉ README. Bản nguồn đi kèm để người dùng tự đối chiếu.

| Example | Cách làm và phần áp dụng |
|---|---|
| `examples/1_Dipole/dipole_example.m` | Khởi đầu từ fC=150MHz và L=λ/2; include paths; fopen; NewProject/InsertDesign; dipole và Lumped Port; airbox/radiation; setup/sweep; SaveProject; SolveSetup; ExportNetworkData; fclose/ExecuteScript; load m-file f/S/Z và lặp chỉnh chiều dài theo tần số cộng hưởng. Ứng dụng giữ cấu trúc sinh/đóng/chạy script, nhưng không thực thi m-file kết quả lạ và không tự solve trong update. |
| `examples/2_Horn/temHorn.m` | Đọc polyline CSV, dựng plate và rectangular feed; Unite; tạo coax với Cylinder/HollowCylinder; Circle cutter; wave port; array DuplicateAlongLine; nhiều setup và save/execute. Vivaldi giữ cách dùng helper thật cho kim loại/coax, nhưng không lấy hình horn, điện môi Teflon hoặc wave port của example làm mô hình nguồn. |
| `examples/3_Patch/microwave_patch.m` | Tính λ và kích thước patch/feed; Rectangle/Unite; substrate Rogers và ground; Lumped Port; tạo array M×N; airbox; setup/interpolating sweep; save/execute. Ứng dụng chỉ tái sử dụng cách tổ chức/helper, không thêm substrate/ground/mảng hoặc interpolating sweep vào Vivaldi. |
| `examples/4_Folded_dipole/folded_dipole.m` | Circle + SweepAroundAxis + Move tạo semicircle; Cylinder, Unite/Rename, copper; rectangular source và Lumped Port 200Ω; ground, airbox/array; setup/sweep; save/execute. Vivaldi giữ helper material/Boolean/port, nhưng cổng phải là hai Lumped Ports 50Ω theo AEDT, không lấy 200Ω hoặc geometry folded dipole. |

Các example đều dùng MATLAB ghi VBS qua `fopen`, gọi helper có fid, `fclose`, rồi `hfssExecuteScript`. Đây là nền tảng hiện tại, không phải persistent COM API trực tiếp trong MATLAB. Chúng cũng cho thấy nhiều thông số numeric cố định, không đủ để Live Update Vivaldi có CS lồng nhau và biến phụ thuộc; lớp expression patch và validation runtime được bổ sung đúng chỗ thiếu.

Những khác biệt kỹ thuật được xử lý: ProgID cũ `AnsoftHfss.HfssScriptInterface`; SaveProject luôn SaveAs; VariableChange chỉ `%f`; RelativeCS chỉ `%.4f` và chưa biểu diễn parent; ThickenSheet BothSides=false; FarFieldSphere method cũ; Solve(Array) signature cũ; Modal S Parameter report category cũ; Frequency Sweep khác Optimetrics. Giữ GPL và ghi hash/pin ở `third_party/HFSS_API_PROVENANCE.json`.
