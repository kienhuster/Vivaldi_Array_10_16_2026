function [q, report] = vivaldiSolveTargetLength(p, target, bracket)
    % Mục đích: tìm L_flare_1 bằng fzero để đạt chiều dài tổng L_patch bất kỳ.
    % Chỉ dò những khoảng liên tiếp hợp lệ; không vượt qua miền topology bị loại.
    [ok, errors, ~, before] = vivaldiValidateParams(p);
    assert(ok, 'VivaldiBuilder:InvalidParameters', '%s', strjoin(errors, newline));
    assert(isnumeric(target) && isreal(target) && isscalar(target) && ...
           isfinite(target) && target > 0, 'VivaldiBuilder:InvalidTarget', ...
           'Chiều dài mục tiêu phải là số thực hữu hạn dương.');
    target = double(target);
    if nargin < 3 || isempty(bracket)
        bracket = [max(realmin, eps(target)) max(4 * target, 4 * before.L_flare)];
    end
    assert(isnumeric(bracket) && isreal(bracket) && numel(bracket) == 2 ...
           && all(isfinite(bracket(:))) && all(bracket(:) > 0) ...
           && bracket(1) < bracket(2), 'VivaldiBuilder:SearchDomain', ...
           'Miền tìm L_flare_1 cần hai số thực dương tăng dần.');
    bracket = double(bracket(:)');
    xs = unique([logspace(log10(bracket(1)), log10(bracket(2)), 201), linspace(bracket(1), bracket(2), 601)]);
    ys = nan(size(xs));
    for k = 1:numel(xs)
        trial = p;
        trial.L_flare_1 = xs(k);
        [valid, ~, ~, geom] = vivaldiValidateParams(trial);
        if valid
            ys(k) = geom.L_patch - target;
        end
    end
    exact = find(abs(ys) < 1e-10, 1);
    if ~isempty(exact)
        root = xs(exact);
    else
        pair = find(isfinite(ys(1:end - 1)) & isfinite(ys(2:end)) ...
                    & sign(ys(1:end - 1)) ~= sign(ys(2:end)), 1);
        assert(~isempty(pair), 'VivaldiBuilder:NoRoot', ...
               'Không có nghiệm hợp lệ trong miền L_flare_1 [%g, %g] mm.', bracket);
        root = fzero(@residual, xs(pair:pair + 1), optimset('TolX', 1e-10, 'Display', 'off'));
    end
    q = p;
    q.L_flare_1 = root;
    [ok, errors, ~, after] = vivaldiValidateParams(q);
    assert(ok, 'VivaldiBuilder:InvalidRoot', '%s', strjoin(errors, newline));
    assert(abs(after.L_patch - target) < 1e-6, 'VivaldiBuilder:Residual', ...
           'Sai số chiều dài sau tìm nghiệm vượt 1e-6 mm.');
    report = struct('before', before, 'after', after, 'target', target, ...
                    'beforeParams', p, 'afterParams', q, 'residual', after.L_patch - target, ...
                    'bracket', bracket, 'bounds', bracket, 'changedVariable', 'L_flare_1', ...
                    'verificationStatus', 'Chỉ xác nhận chiều dài bằng số — chờ kiểm tra HFSS');

    function y = residual(x)
        trial = p;
        trial.L_flare_1 = x;
        [valid, err, ~, geom] = vivaldiValidateParams(trial);
        assert(valid, 'VivaldiBuilder:InvalidTrial', '%s', strjoin(err, newline));
        y = geom.L_patch - target;
    end

end
