%% scan_dataset.m
clear; clc;
root = 'C:\Users\valer\Desktop\Università\Image Processing\ms-rex\data\AOI_3_Paris';
msFiles = dir(fullfile(root, 'PS-MS', '*.tif'));
N = numel(msFiles);

id = strings(N, 1); validPct = zeros(N, 1);
nLines = zeros(N, 1); hasGT = false(N, 1);
allType = []; allPaved = []; allLanes = [];

for k = 1:N
    id(k) = regexp(msFiles(k).name, 'img\d+', 'match', 'once');
    A = readgeoraster(fullfile(msFiles(k).folder, msFiles(k).name));
    validPct(k) = 100 * mean(any(A > 0, 3), 'all');

    gjf = fullfile(root, 'geojson_roads', ...
        sprintf('SN3_roads_train_AOI_3_Paris_geojson_roads_%s.geojson', id(k)));

    if isfile(gjf)
        L = geojson_lines(gjf);
        nLines(k) = numel(L);
        hasGT(k) = ~isempty(L);
        allType = [allType, [L.rtype]]; %#ok<AGROW>
        allPaved = [allPaved, [L.paved]]; %#ok<AGROW>
        allLanes = [allLanes, [L.lanes]]; %#ok<AGROW>
    end

    if mod(k, 25) == 0, fprintf('%d/%d\n', k, N); end
end

T = table(id, validPct, nLines, hasGT);
save('scan_results.mat', 'T', 'allType', 'allPaved', 'allLanes');

fprintf('\nTile con GT non vuota: %d / %d\n', sum(hasGT), N);
fprintf('Tile con pixel neri (valid < 100%%): %d\n', sum(validPct < 100));
fprintf('Pixel validi: min %.1f%%, mediana %.1f%%\n', min(validPct), median(validPct));
disp(sortrows(T(T.validPct < 100, :), 'validPct'));

for nm = {'allType', 'allPaved', 'allLanes'}
    v = eval(nm{1}); v(isnan(v)) = -1;
    [u, ~, j] = unique(v);
    fprintf('\n%s (valore, conteggio):\n', nm{1});
    disp([u(:), accumarray(j(:), 1)]);
end
