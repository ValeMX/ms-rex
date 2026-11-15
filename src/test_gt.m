%% test_gt.m
clear; close all; clc;
root = 'C:\Users\valer\Desktop\Università\Image Processing\ms-rex\data\AOI_3_Paris';
msFiles = dir(fullfile(root, 'PS-MS', '*.tif'));

for k = 1:5 % prova con i primi 5 tile
    id = regexp(msFiles(k).name, 'img\d+', 'match', 'once');
    gjf = fullfile(root, 'geojson_roads', ...
        sprintf('SN3_roads_train_AOI_3_Paris_geojson_roads_%s.geojson', id));
    if ~isfile(gjf), fprintf('%s: nessun geojson\n', id); continue; end

    [A, R] = readgeoraster(fullfile(msFiles(k).folder, msFiles(k).name));
    lines = geojson_lines(gjf);
    [gt, cl] = rasterize_gt(lines, R, size(A, [1 2]));
    fprintf('%s: %d tratti, strada = %.1f%% dei pixel\n', id, numel(lines), 100 * mean(gt(:)));

    rgb = double(A(:, :, [5 3 2]));
    lo = prctile(rgb(:), 2); hi = prctile(rgb(:), 98);
    figure('Name', id);
    imshow(min(max(rescale(rgb, 0, 1, 'InputMin', lo, 'InputMax', hi), 0), 1));
    hold on
    visboundaries(gt, 'Color', 'r', 'LineWidth', 0.5);
    [r, c] = find(cl); plot(c, r, 'y.', 'MarkerSize', 1);
    title(sprintf('%s: GT rossa, centerline gialla', id));
end
