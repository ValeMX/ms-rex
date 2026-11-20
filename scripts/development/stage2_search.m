%% stage2_search.m
clear; close all; clc;
c = config();

%% Load the development tile IDs and initialize parameters for the search

load(fullfile(c.resultsDirectory, 'split.mat'), 'devIds');

nUse = 50; % Number of development tiles to use for the search
ndviThresholds = [0.2265 0.30 0.40]; % NDVI threshold values to test
lCloseList = [0 0 0 0 25 25 25]; % Length of the structuring element for morphological closing (if > 0)
lOpenList = [0 30 60 90 30 60 90]; % Length of the structuring element for morphological opening (if > 0)
minArea = 100; % Minimum area of connected components to keep

D = struct('ndvi', cell(nUse, 1), 'gt', [], 'cl', [], 'valid', [], 'tolerancePixels', []);

%% Load the development tiles, compute NDVI, and store the ground truth and valid masks for each tile

for k = 1:nUse
    tile = load_tile(devIds(k)); % Load the tile with the specified ID and its corresponding ground truth (if available)
    S = compute_indices(tile.A); % Compute spectral indices for the tile's multispectral image
    D(k).ndvi = single(S(:, :, 1)); % Store the NDVI index (first index in S) for the tile
    D(k).gt = tile.gt; % Store the ground truth mask for the tile
    D(k).cl = tile.cl; % Store the centerline mask for the tile
    D(k).valid = tile.valid; % Store the valid mask for the tile (indicating valid pixels)
    D(k).tolerancePixels = c.tolerance / pixel_size(tile.R); % Store the tolerance in pixels for the tile, calculated based on the pixel size in meters
    fprintf('Loaded %d/%d\n', k, nUse);
end

%% Loop through each combination of NDVI threshold, morphological closing length, and morphological opening length to evaluate the performance of the road detection algorithm

nThresholds = numel(ndviThresholds);
nOpen = numel(lOpenList);
results = zeros(nThresholds, nOpen, nUse, 5);

fprintf('\n');

% For each NDVI threshold
for it = 1:nThresholds

    % For each combination of morphological closing length and opening length
    for io = 1:nOpen
        p = struct('minArea', minArea, 'lClose', lCloseList(io), 'lOpen', lOpenList(io));

        % For each development tile
        for k = 1:nUse
            pred = D(k).ndvi <= ndviThresholds(it); % Create a binary mask of predicted road pixels based on the NDVI threshold
            pred = clean_mask(pred, D(k).valid, p); % Clean the predicted mask using morphological operations (closing and opening) based on the specified parameters
            pm = pixel_metrics(pred, D(k).gt, D(k).valid); % Compute pixel-level metrics (F1 score and Intersection over Union) comparing the predicted mask to the ground truth mask
            cm = centerline_metrics(pred, D(k).cl, D(k).valid, D(k).tolerancePixels); % Compute centerline-level metrics (completeness, correctness, and quality) comparing the predicted mask to the ground truth centerline mask
            results(it, io, k, :) = [pm.F1, pm.IoU, cm.completeness, cm.correctness, cm.quality]; % Store the computed metrics for the current combination of parameters and tile
        end

        fprintf('NDVI<=%.3f  lClose=%d lOpen=%d done\n', ndviThresholds(it), lCloseList(io), lOpenList(io));
    end

end

%% Aggregate the results across all development tiles for each combination of parameters and store them in a table for further analysis

rows = [];

for it = 1:nThresholds

    % For each combination of morphological closing length and opening length, compute the mean metrics across all development tiles and store them in a table
    for io = 1:nOpen
        m = reshape(mean(results(it, io, :, :), 3, 'omitnan'), 1, 5);
        rows = [rows; ndviThresholds(it), lCloseList(io), lOpenList(io), m]; %#ok<AGROW>
    end

end

% Create a table from the aggregated results, sort it by the quality metric in descending order, and display the table
T = array2table(rows, 'VariableNames', {'NDVIcut', 'lClose', 'lOpen', 'F1', 'IoU', 'Completeness', 'Correctness', 'Quality'});
T = sortrows(T, 'Quality', 'descend'); % Sort the table T based on the quality metric in descending order to identify the best-performing combinations of parameters
disp(T);
save(fullfile(c.resultsDirectory, 'stage2_results.mat'), 'T', 'results', 'ndviThresholds', 'lCloseList', 'lOpenList');

%% Visualize the effect of the best-performing combination of parameters on a sample development tile

b = T(1, :);
p = struct('minArea', minArea, 'lClose', b.lClose, 'lOpen', b.lOpen);
k = min(2, nUse);
pred0 = D(k).ndvi <= 0.2265;
pred1 = clean_mask(D(k).ndvi <= b.NDVIcut, D(k).valid, p);

figure; 
tiledlayout(1, 2, 'TileSpacing', 'compact');
nexttile;
imshowpair(pred0, D(k).gt);
title('Optimal NDVI threshold only');
nexttile; imshowpair(pred1, D(k).gt);
title('Optimal NDVI threshold + morphological operations');
sgtitle('GT (magenta) and prediction (green), white = agreement');
