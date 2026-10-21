function report = runHFSSBuildIntegration(exe, folder, runFullCAD, runSolver, runMaterials)
% Mục đích: chạy tuần tự Rectangle thử, anten đầy đủ và solver tùy chọn trên Windows.
% Các mục không chạy luôn PENDING; không coi sinh script hoặc fixture là bằng chứng HFSS.
if nargin < 1, exe = ''; end
if nargin < 2, folder = fullfile(tempdir, 'vivaldi-hfss-build-check'); end
if nargin < 3, runFullCAD = true; end
if nargin < 4, runSolver = false; end
if nargin < 5, runMaterials = false; end
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
report = struct('library', 'PENDING', 'emptyProjectAndRectangle', 'PENDING', ...
    'materials', struct('Aluminum','PENDING','Copper','PENDING','PEC','PENDING','CustomMetal','PENDING'), ...
    'fullAntennaCAD', 'PENDING', 'saveAEDT', 'PENDING', 'solver', 'PENDING', ...
    'scope', 'Cần Windows, MATLAB R2021a+ và HFSS 2021 R2.', 'jobs', {{}});
if ~isfolder(folder), mkdir(folder); end
if ~ispc || ~isfile(exe)
    writeReport(report, folder); return
end
p = Vivaldi_Calculation('defaults');
probe = Vivaldi_HFSS_Builder('generate', p, folder, Vivaldi_HFSS_Simulation('defaults'), 'rectangle');
assert(~isempty(which('hfssRectangle')) && ~isempty(which('hfssNewProject')));
report.library = 'PASS';
probe = waitForJob(Vivaldi_HFSS_Builder('launch', probe, exe));
report.jobs{end + 1} = probe;
report.emptyProjectAndRectangle = probe.state;
if ~strcmp(probe.state, 'SUCCEEDED'), writeReport(report, folder); return; end
if runFullCAD
    built = Vivaldi_HFSS_Builder('generate', p, folder);
    built = waitForJob(Vivaldi_HFSS_Builder('launch', built, exe));
    report.jobs{end + 1} = built; report.fullAntennaCAD = built.state;
    if strcmp(built.state, 'SUCCEEDED')
        report.saveAEDT = 'PASS';
        if runSolver
            solved = Vivaldi_HFSS_Builder('simulate', built);
            solved = waitForJob(Vivaldi_HFSS_Builder('launch', solved, exe));
            report.jobs{end + 1} = solved; report.solver = solved.state;
        end
    end
end
if runMaterials
    % Mỗi ca dựng CAD riêng; log phải có readback thuộc tính trước khi lưu.
    database=Vivaldi_Calculation('material_defaults');
    cases=database(ismember({database.name},{'Aluminum','Copper','PEC'}));
    custom=database(strcmp({database.name},'Copper'));custom.name='Integration_Custom_Metal';
    custom.conductivity=41234567.89;custom.permeability=1.01;cases(end+1)=custom;
    labels={'Aluminum','Copper','PEC','CustomMetal'};
    for k=1:numel(cases)
        testJob=Vivaldi_HFSS_Builder('generate',p,fullfile(folder,labels{k}), ...
            Vivaldi_HFSS_Simulation('defaults'),'full',true,cases(k));
        testJob=waitForJob(Vivaldi_HFSS_Builder('launch',testJob,exe));
        report.jobs{end+1}=testJob;report.materials.(labels{k})=testJob.state;
        writeReport(report,folder);
    end
end
report.scope = 'Đọc log từng checkpoint để phân biệt thực thi, phép đo CAD và mục còn Pending.';
writeReport(report, folder);
end

function job = waitForJob(job)
% Mục đích: chờ phản hồi thật; quá hạn vẫn Pending, không dừng/kill HFSS tự động.
started = tic;
while toc(started) < 3600
    job = Vivaldi_HFSS_Builder('poll', job);
    if ismember(job.state, {'SUCCEEDED', 'FAILED'}), return; end
    pause(1); drawnow;
end
job.state = 'PENDING';
end

function writeReport(report, folder)
% Mục đích: lưu bằng chứng gồm log nguyên văn, không cập nhật chứng nhận khi chưa chạy.
fid = fopen(fullfile(folder, 'hfss-integration.json'), 'w', 'n', 'UTF-8');
assert(fid >= 0, 'Vivaldi:Write', 'Không lưu được báo cáo kiểm tra.');
cleanup = onCleanup(@()fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', jsonencode(report));
end
