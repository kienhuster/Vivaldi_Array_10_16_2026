function tests = testVivaldiGUI
% Mục đích: kiểm tra GUI MATLAB thật, callback và việc mở GUI không tạo project.
tests = functiontests(localfunctions);
end

function testTabsAndCallbacks(testCase)
% Mục đích: năm tab tiếng Việt, sáu nút, nhập lẻ và reset; không gọi HFSS.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
output = fullfile(root, 'output');
before = listing(output);
fig = Vivaldi_GUI('Visible', 'off');
cleanup = onCleanup(@()closeIfValid(fig)); %#ok<NASGU>
% CloseRequestFcn thu hồi timer; cleanup cũng đi qua callback khi thành công.
tabs = findall(fig, 'Type', 'uitab');
verifyEqual(testCase, sort({tabs.Title}), sort({'Thông số anten','Xem trước 3D','Tạo anten HFSS','Mô phỏng','Nhật ký'}));
buttons = findall(fig, 'Type', 'uibutton');
verifyEqual(testCase, numel(buttons), 6);
verifyTrue(testCase, any(strcmp({buttons.Text}, 'Tạo anten HFSS')));
verifyFalse(testCase, any(contains({buttons.Text}, 'Cập nhật')));
fields = findall(fig, 'Type', 'uinumericeditfield');
antenna = fields(arrayfun(@(f)isequal(f.Limits, [-Inf Inf]), fields));
verifyEqual(testCase, numel(antenna), 19);
index = find([antenna.Value] == 40, 1);
antenna(index).Value = 43.287123456789;
callback = antenna(index).ValueChangedFcn; callback(antenna(index), []);
reset = buttons(strcmp({buttons.Text}, 'Khôi phục mặc định'));
callback = reset.ButtonPushedFcn; callback(reset, []);
verifyEqual(testCase, antenna(index).Value, 40);
verifyEqual(testCase, listing(output), before);
close(fig);
end

function names = listing(folder)
% Mục đích: so sánh đầu ra trước/sau mở GUI, không cần tạo thư mục thử.
if ~isfolder(folder), names = {}; return; end
items = dir(fullfile(folder, '**', '*')); names = sort({items.name});
end

function closeIfValid(fig)
% Mục đích: đóng qua callback để thu hồi timer kể cả khi test lỗi.
if isvalid(fig), close(fig); end
end
