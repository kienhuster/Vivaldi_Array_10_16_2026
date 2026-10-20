classdef HFSSResultImporter
    % Mục đích: nhập/vẽ CSV thật và đo HPBW từ mẫu; không tạo kết quả anten giả.
    methods (Static)

        function data = read(path)
            % Đọc cột số, giữ header và đơn vị gốc; không tự xác nhận provenance CAD.
            assert(isfile(path), 'Vivaldi:CSV', 'Không có file CSV.');
            tableData = readtable(path, 'VariableNamingRule', 'preserve');
            assert(height(tableData) > 0 && width(tableData) >= 2, 'Vivaldi:CSV', 'CSV cần ít nhất 2 cột và dữ liệu.');
            numeric = varfun(@isnumeric, tableData, 'OutputFormat', 'uniform');
            assert(all(numeric), 'Vivaldi:CSV', 'Chọn CSV HFSS có các cột số; bỏ metadata text.');
            values = table2array(tableData);
            assert(isreal(values) && all(isfinite(values(:))), 'Vivaldi:CSV', 'Dữ liệu cần số thực hữu hạn.');
            data = struct('path', path, 'headers', {tableData.Properties.VariableNames}, 'values', values, ...
                          'status', 'CSV nhập riêng — chưa xác nhận trùng hình học hiện tại');
        end

        function plot(ax, data, xColumn, yColumns)
            % Vẽ các cột thực đã chọn, giữ nhãn đơn vị từ CSV.
            if nargin < 3
                xColumn = 1;
            end
            if nargin < 4
                yColumns = setdiff(1:size(data.values, 2), xColumn);
            end
            plot(ax, data.values(:, xColumn), data.values(:, yColumns), 'LineWidth', 1.3);
            grid(ax, 'on');
            xlabel(ax, data.headers{xColumn}, 'Interpreter', 'none');
            ylabel(ax, strjoin(data.headers(yColumns), ' / '), 'Interpreter', 'none');
            legend(ax, data.headers(yColumns), 'Interpreter', 'none', 'Location', 'best');
            title(ax, data.status, 'Interpreter', 'none');
        end

        function plot3D(ax, data, thetaColumn, phiColumn, gainColumn)
            % Dùng mẫu Theta/Phi/Gain thật; không nội suy bổ sung dữ liệu thiếu.
            theta = data.values(:, thetaColumn);
            phi = data.values(:, phiColumn);
            gain = data.values(:, gainColumn);
            assert(numel(unique(theta)) > 2 && numel(unique(phi)) > 2, 'Vivaldi:Pattern3D', 'Cần dữ liệu Theta/Phi dạng lưới 3D.');
            radius = 10.^(gain / 20);
            x = radius .* sind(theta) .* cosd(phi);
            y = radius .* sind(theta) .* sind(phi);
            z = radius .* cosd(theta);
            scatter3(ax, x, y, z, 18, gain, 'filled');
            axis(ax, 'equal');
            colorbar(ax);
            view(ax, 3);
            title(ax, 'Giản đồ HFSS lấy mẫu — bán kính căn gain tuyến tính, màu dB');
            xlabel(ax, 'X');
            ylabel(ax, 'Y');
            zlabel(ax, 'Z');
        end

        function out = hpbw(angle, gainDB)
            % Nội suy hai giao điểm peak-3dB quanh búp chính của mặt cắt đã chọn.
            assert(isnumeric(angle) && isnumeric(gainDB) && isreal(angle) && isreal(gainDB), ...
                   'Vivaldi:HPBW', 'Cần angle độ và gain dB thực.');
            angle = angle(:);
            gainDB = gainDB(:);
            assert(numel(angle) == numel(gainDB) && numel(angle) >= 5 && all(isfinite([angle; gainDB])), ...
                   'Vivaldi:HPBW', 'Cần ít nhất 5 mẫu hữu hạn.');
            [angle, order] = sort(angle);
            gainDB = gainDB(order);
            assert(all(diff(angle) > 0), 'Vivaldi:HPBW', 'Góc phải khác nhau; chọn một mặt cắt Phi cố định.');
            [peak, index] = max(gainDB);
            level = peak - 3;
            left = find(gainDB(1:index) < level, 1, 'last');
            right = index - 1 + find(gainDB(index:end) < level, 1, 'first');
            out = struct('widthDeg', NaN, 'leftDeg', NaN, 'rightDeg', NaN, 'peakDB', peak, 'status', 'PENDING');
            if isempty(left) || isempty(right)
                out.status = 'UNSUPPORTED';
                return
            end
            a = interp1(gainDB(left:left + 1), angle(left:left + 1), level);
            b = interp1(gainDB(right - 1:right), angle(right - 1:right), level);
            out.widthDeg = b - a;
            out.leftDeg = a;
            out.rightDeg = b;
            out.status = 'PASS';
        end

    end
end
