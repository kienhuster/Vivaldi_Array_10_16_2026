function tests = testVivaldiGUI
% Mục đích: kiểm tra GUI MATLAB thật, callback và việc mở GUI không tạo project.
tests = functiontests(localfunctions);
end

function testTabsAndCallbacks(testCase)
% Mục đích: năm tab tiếng Việt, bảy nút, nhập lẻ và reset; không gọi HFSS.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
output = fullfile(root, 'output');
before = listing(output);
fig = Vivaldi_GUI('Visible', 'off', 'MaterialFile', fullfile(tempdir,'Vivaldi_GUI_isolated_test','custom_materials.mat'));
cleanup = onCleanup(@()closeIfValid(fig)); %#ok<NASGU>
% CloseRequestFcn thu hồi timer; cleanup cũng đi qua callback khi thành công.
tabs = findall(fig, 'Type', 'uitab');
verifyEqual(testCase, sort({tabs.Title}), sort({'Thông số anten','Xem trước 3D','Tạo anten HFSS','Mô phỏng','Nhật ký'}));
buttons = findall(fig, 'Type', 'uibutton');
verifyEqual(testCase, numel(buttons), 7);
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

function testLibraryFailureBeforeWindow(testCase)
% Mục đích: khi helper bị shadow, GUI dừng trước uifigure và không tạo project.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
Vivaldi_HFSS_Builder('initialize');
oldPath = path; oldFolder=pwd; temporary = tempname; mkdir(temporary);
cleanup = onCleanup(@()restoreShadow(oldPath, oldFolder, temporary)); %#ok<NASGU>
fid = fopen(fullfile(temporary, 'hfssRectangle.m'), 'w');
fprintf(fid, 'function hfssRectangle(varargin)\nerror(''Vivaldi:ShadowExecuted'',''Unexpected'');\nend\n'); fclose(fid);
clear hfssRectangle;
addpath(temporary, '-begin'); cd(temporary); before = findall(0, 'Type', 'figure');
verifyError(testCase, @()Vivaldi_GUI('Visible', 'off'), 'Vivaldi:LibraryConflict');
verifyEqual(testCase, findall(0, 'Type', 'figure'), before);
end

function restoreShadow(oldPath, oldFolder, temporary)
% Mục đích: trả path nguyên trạng sau khi kiểm tra lỗi, kể cả khi assertion thất bại.
cd(oldFolder); path(oldPath); clear hfssRectangle;
if isfolder(temporary), rmdir(temporary, 's'); end
end

function testMaterialLibrary(testCase)
% Mục đích: callback thật cho tìm kiếm, chọn, Cancel, thêm/lưu và mở lại dữ liệu.
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);
folder=tempname;mkdir(folder); cleanupFolder=onCleanup(@()rmdir(folder,'s')); %#ok<NASGU>
file=fullfile(folder,'custom_materials.mat');
fig=Vivaldi_GUI('Visible','off','MaterialFile',file);cleanup=onCleanup(@()closeIfValid(fig)); %#ok<NASGU>
pushTag(fig,'materialLibrary'); dialog=materialWindow();
searchMaterial(dialog,'Rogers');table=findall(dialog,'Tag','materialTable');verifyEqual(testCase,size(table.Data,1),2);
verifyEqual(testCase,fig.UserData.bodyMaterial.name,'Aluminum');pushTag(dialog,'materialCancel');
pushTag(fig,'materialLibrary');dialog=materialWindow();searchMaterial(dialog,'cOpPeR');selectFirst(dialog);pushTag(dialog,'materialOK');
verifyEqual(testCase,fig.UserData.bodyMaterial.name,'Copper');
pushTag(fig,'materialLibrary');dialog=materialWindow();searchMaterial(dialog,'Aluminum');selectFirst(dialog);pushTag(dialog,'materialCancel');
verifyEqual(testCase,fig.UserData.bodyMaterial.name,'Copper');
pushTag(fig,'materialLibrary');dialog=materialWindow();pushTag(dialog,'addMaterial');
form=findall(0,'Type','figure','Name','Thêm vật liệu');
name=findall(form,'Tag','newMaterialName');name.Value='GUI_Custom_Metal';
sigma=findall(form,'Tag','newMaterialConductivity');sigma.Value=42345678.9;
pushTag(form,'saveMaterial');verifyTrue(testCase,isfile(file));selectFirst(dialog);pushTag(dialog,'materialOK');
verifyEqual(testCase,fig.UserData.bodyMaterial.name,'GUI_Custom_Metal');
verifyEqual(testCase,fig.UserData.bodyMaterial.conductivity,42345678.9);
close(fig);
second=Vivaldi_GUI('Visible','off','MaterialFile',file);cleanupSecond=onCleanup(@()closeIfValid(second)); %#ok<NASGU>
pushTag(second,'materialLibrary');dialog=materialWindow();searchMaterial(dialog,'GUI_Custom_Metal');
table=findall(dialog,'Tag','materialTable');verifyEqual(testCase,size(table.Data,1),1);
verifyEqual(testCase,table.Data{1,1},'GUI_Custom_Metal');
close(second);
end

function pushTag(parent,tag)
% Mục đích: gọi đúng callback UI, không nhân bản logic vật liệu trong test.
button=findall(parent,'Tag',tag);callback=button.ButtonPushedFcn;callback(button,[]);
end

function dialog = materialWindow()
% Mục đích: lấy cửa sổ thư viện tách riêng khỏi năm tab chính.
dialog=findall(0,'Type','figure','Name','Select Definition - Vật liệu');assert(isscalar(dialog));
end

function searchMaterial(dialog,term)
% Mục đích: lọc qua callback thật, không sửa bảng trực tiếp.
field=findall(dialog,'Tag','materialSearch');field.Value=term;callback=field.ValueChangedFcn;callback(field,[]);
end

function selectFirst(dialog)
% Mục đích: mô phỏng chọn dòng trong bảng đã lọc để kiểm tra ánh xạ index.
table=findall(dialog,'Tag','materialTable');callback=table.CellSelectionCallback;callback(table,struct('Indices',[1 1]));
end
