%% stage3_search.m
clear; close all; clc;
c = config();

%% Load the development tile IDs and initialize parameters for the search

load(fullfile(c.resultsDirectory, 'split.mat'), 'devIds');

nUse = 10; % Number of development tiles to use for the search
ndviThresholds = [0.25 0.30 0.35]; % NDVI threshold values to test
radiusList = [0 35 45 55 70]; % Radius of the structuring element for morphological closing (if > 0)
lOpenList = [0 60]; % Length of the structuring element for morphological opening (if > 0)
minArea = 100; % Minimum area of connected components to keep
minBranch = 20; % Minimum length of branches in the centerline mask to consider for centerline metrics

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

%% Loop through each combination of NDVI threshold, morphological closing radius, and morphological opening length to evaluate the performance of the road detection algorithm

configs = [];

for it = 1:numel(ndviThresholds)

    for ir = 1:numel(radiusList)

        for il = 1:numel(lOpenList)
            configs = [configs; ndviThresholds(it), radiusList(ir), lOpenList(il)]; %#ok<AGROW>
        end

    end

end

nConfigs = size(configs, 1);
results = zeros(nConfigs, nUse, 7); % F1, rPrecision, rRecall, rF1, completeness, correctness, quality

% For each configuration
for ic = 1:nConfigs
    % Set the parameters for the current configuration
    p = struct('minArea', minArea, 'radius', configs(ic, 2), 'lClose', 0, 'lOpen', configs(ic, 3));

    % For each development tile
    for k = 1:nUse
        pred = clean_mask(D(k).ndvi <= configs(ic, 1), D(k).valid, p); % Create a binary mask of predicted road pixels based on the NDVI threshold and clean it using morphological operations (closing and opening) based on the specified parameters
        pm = pixel_metrics(pred, D(k).gt, D(k).valid); % Compute pixel-level metrics (F1 score and Intersection over Union) comparing the predicted mask to the ground truth mask
        rm = relaxed_metrics(pred, D(k).gt, D(k).valid, D(k).tolerancePixels); % Compute relaxed metrics (precision, recall, and F1 score) comparing the predicted mask to the ground truth mask with a specified tolerance in pixels
        cm = centerline_metrics(pred, D(k).cl, D(k).valid, D(k).tolerancePixels, minBranch); % Compute centerline-level metrics (completeness, correctness, and quality) comparing the predicted mask to the ground truth centerline mask with a specified tolerance in pixels and a minimum branch length
        results(ic, k, :) = [pm.F1, rm.rPrecision, rm.rRecall, rm.rF1, cm.completeness, cm.correctness, cm.quality]; % Store the computed metrics for the current configuration and tile in the results array
    end

    fprintf('Config %d/%d  (Threshold %.3f, Radius %d, Opening %d)\n', ic, nConfigs, configs(ic, :));
end

%% Aggregate the results across all development tiles for each configuration and store them in a table for further analysis

M = squeeze(mean(results, 2, 'omitnan')); % Compute the mean metrics across all development tiles for each configuration, ignoring NaN values. The resulting matrix M has dimensions (nConfigs x 7), where each row corresponds to a configuration and each column corresponds to a metric (F1 score, relaxed precision, relaxed recall, relaxed F1 score, completeness, correctness, quality).
T = array2table([configs, M], 'VariableNames', {'NDVIcut', 'radius', 'lOpen', 'F1', 'rPrec', 'rRec', 'rF1', 'Compl', 'Corr', 'Quality'});
T = sortrows(T, 'rF1', 'descend'); % Sort the table T based on the relaxed F1 score (rF1) in descending order to identify the best-performing configurations.
disp(T);
save(fullfile(c.resultsDirectory, 'stage3_results.mat'), 'T', 'results', 'configs');

%% Visualize the performance of the best configuration on the first development tile

b = T(1, :); % Get the best configuration based on the highest relaxed F1 score (rF1) from the sorted table T. The variable b contains the parameters of the best configuration, including the NDVI threshold (NDVIcut), morphological closing radius (radius), and morphological opening length (lOpen).
k = min(2, nUse); % Use the first development tile (or the minimum of 1 and nUse) to visualize the performance of the best configuration. The variable k is set to 1, ensuring that we are visualizing the results for the first tile in the dataset.

p0 = struct('minArea', minArea, 'radius', 0, 'lClose', 0, 'lOpen', 0);
p1 = struct('minArea', minArea, 'radius', b.radius, 'lClose', 0, 'lOpen', b.lOpen);
pred0 = clean_mask(D(k).ndvi <= ndviThresholds(1), D(k).valid, p0);
pred1 = clean_mask(D(k).ndvi <= b.NDVIcut, D(k).valid, p1);
figure;
tiledlayout(1, 2, 'TileSpacing', 'compact');

nexttile;
imshowpair(pred0, D(k).gt);
title('Baseline: NDVI threshold, no morphological operations');

nexttile;
imshowpair(pred1, D(k).gt);
title(sprintf('Threshold: %.2f, radius: %d, opening: %d', b.NDVIcut, b.radius, b.lOpen));

sgtitle('Green = prediction, Magenta = GT, White = agreement');
