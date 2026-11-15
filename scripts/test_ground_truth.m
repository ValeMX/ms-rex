%% test_ground_truth.m
clear; close all; clc;
root = 'C:\Users\valer\Desktop\Università\Image Processing\ms-rex\data\AOI_3_Paris';
msFiles = dir(fullfile(root, 'PS-MS', '*.tif'));

%% Test the ground truth generation for a few tiles

for k = 1:5
    % Extract the tile ID from the filename and construct the corresponding geojson filename
    id = regexp(msFiles(k).name, 'img\d+', 'match', 'once');
    geojson_file = fullfile(root, 'geojson_roads', sprintf('SN3_roads_train_AOI_3_Paris_geojson_roads_%s.geojson', id));
    if ~isfile(geojson_file), fprintf('%s: no geojson file\n', id); continue; end

    % Read the PS-MS tile and the corresponding geojson file
    [A, R] = readgeoraster(fullfile(msFiles(k).folder, msFiles(k).name));
    lines = read_geojson(geojson_file);

    % Generate the ground truth and centerline masks
    [gt, cl] = generate_ground_truth(lines, R, size(A, [1 2]));
    fprintf('%s: %d segments, road = %.1f%% of the pixels\n', id, numel(lines), 100 * mean(gt(:)));

    % Display the results
    rgb = double(A(:, :, [5 3 2]));
    lo = prctile(rgb(:), 2);
    hi = prctile(rgb(:), 98);
    figure('Name', id);
    imshow(min(max(rescale(rgb, 0, 1, 'InputMin', lo, 'InputMax', hi), 0), 1));

    hold on

    visboundaries(gt, 'Color', 'r', 'LineWidth', 0.5);
    [r, c] = find(cl);
    plot(c, r, 'y.', 'MarkerSize', 1);
    title(sprintf('%s: Ground Truth is red, Centerline is yellow', id));
end
