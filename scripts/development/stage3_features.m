%% stage3_features.m
clear; close all; clc;
c = config();

%% Load the development tile IDs and initialize parameters for feature evaluation

load(fullfile(c.resultsDirectory, 'split.mat'), 'devIds');

nUse = 30; % Number of development tiles to use for the evaluation
featNames = {'-NDVI', 'ND(R,N2)', '-REI'}; % Names of the features to evaluate
nFeatures = numel(featNames); % Number of features to evaluate
ndviThresholds = [0.2265 0.30]; % Reference NDVI threshold values to evaluate the features against
minArea = 100; % Minimum area of connected components to keep when cleaning the predicted masks
minBranch = 20; % Minimum length of branches in the centerline mask to consider for centerline metrics
radius = 35;
lOpen = 60;

D = struct('F', cell(nUse, 1), 'gt', [], 'cl', [], 'valid', [], 'tolerancePixels', []);

%% Load the development tiles, compute the features, and store the ground truth and valid masks for each tile

for k = 1:nUse
    tile = load_tile(devIds(k)); % Load the tile with the specified ID and its corresponding ground truth (if available)
    S = compute_indices(tile.A); % Compute spectral indices for the tile's multispectral image
    R = tile.A(:, :, 5); % Red band
    N2 = tile.A(:, :, 8); % NIR2 band
    D(k).F = single(cat(3, -S(:, :, 1), (R - N2) ./ (R + N2 + eps), -S(:, :, 3))); % Store the computed features for the tile: -NDVI, ND(R,N2), and -REI
    D(k).gt = tile.gt; % Store the ground truth mask for the tile
    D(k).cl = tile.cl; % Store the centerline mask for the tile
    D(k).valid = tile.valid; % Store the valid mask for the tile (indicating valid pixels)
    D(k).tolerancePixels = c.tolerance / pixel_size(tile.R); % Store the tolerance in pixels for the tile, calculated based on the pixel size in meters
    fprintf('Loaded %d/%d\n', k, nUse);
end

%% Loop through each feature and each NDVI threshold to evaluate the performance of the features in predicting road pixels

pool = cell(1, nFeatures); % Initialize a cell array to hold sampled pixel values for each feature across all development tiles

% For each development tile
for k = 1:nUse

    % For each feature
    for j = 1:nFeatures
        x = D(k).F(:, :, j); % Extract the feature values for feature j from the current tile
        x = x(D(k).valid); % Keep only the valid pixels based on the tile's validity mask
        pool{j} = [pool{j}; x(1:20:end)]; % Randomly sample 1 out of every 20 valid pixels to reduce the dataset size for histogram computation
    end

end

fraction = arrayfun(@(cut) mean(pool{1} >= -cut), ndviThresholds); % Compute the fraction of pixels predicted by each NDVI threshold by calculating the mean of the binary mask where the -NDVI feature values are greater than or equal to the negative of the threshold value. This gives an estimate of how many pixels would be classified as road pixels based on the NDVI thresholds.
fprintf('Fraction of pixels predicted by each NDVI threshold: %s\n', mat2str(fraction, 3));
thresholds = zeros(nFeatures, numel(fraction)); % Initialize an array to hold the computed thresholds for each feature and each NDVI threshold fraction. The thresholds will be determined based on the quantiles of the sampled pixel values for each feature, corresponding to the specified fractions of pixels predicted by the NDVI thresholds.

% For each feature, compute the threshold values corresponding to the specified fractions of pixels predicted by the NDVI thresholds. The thresholds are determined using quantiles of the sampled pixel values for each feature, where the quantile is calculated as 1 minus the fraction of pixels predicted by the NDVI threshold. This ensures that the thresholds are set such that a certain fraction of pixels will be classified as road pixels based on the feature values.
for j = 1:nFeatures
    for i = 1:numel(fraction), thresholds(j, i) = quantile(pool{j}, 1 - fraction(i)); end
end

%% Evaluate the performance of each feature at the computed thresholds for each development tile, both with and without morphological filtering (closing and opening)

pv = {struct('minArea', minArea, 'radius', 0, 'lClose', 0, 'lOpen', 0), struct('minArea', minArea, 'radius', radius, 'lClose', 0, 'lOpen', lOpen)};
results = zeros(nFeatures, numel(fraction), 2, nUse, 3); % Initialize a 5D array to hold the evaluation results for each feature, each NDVI threshold fraction, both with and without morphological filtering, for each development tile, and for three metrics: relaxed F1 score (rF1), quality metric (Q), and pixel-level F1 score (F1). The dimensions of the array are as follows: number of features x number of NDVI threshold fractions x 2 (for filtered and unfiltered) x number of development tiles x 3 (for the three metrics).

% For each development tile
for k = 1:nUse

    % For each feature
    for j = 1:nFeatures

        % For each NDVI threshold fraction
        for i = 1:numel(fraction)
            pred0 = D(k).F(:, :, j) >= thresholds(j, i); % Create a binary mask of predicted road pixels based on the computed threshold for the current feature and NDVI threshold fraction

            for v = 1:2
                pred = clean_mask(pred0, D(k).valid, pv{v}); % Clean the predicted mask using morphological operations (closing and opening) based on the specified parameters for the current filtering option (v = 1 for unfiltered, v = 2 for filtered)
                pm = pixel_metrics(pred, D(k).gt, D(k).valid); % Compute pixel-level metrics (F1 score and Intersection over Union) comparing the predicted mask to the ground truth mask
                rm = relaxed_metrics(pred, D(k).gt, D(k).valid, D(k).tolerancePixels); % Compute relaxed metrics (precision, recall, and F1 score) comparing the predicted mask to the ground truth mask with a specified tolerance in pixels
                cm = centerline_metrics(pred, D(k).cl, D(k).valid, D(k).tolerancePixels, minBranch); % Compute centerline-level metrics (completeness, correctness, and quality) comparing the predicted mask to the ground truth centerline mask with a specified tolerance in pixels and a minimum branch length
                results(j, i, v, k, :) = [rm.rF1, cm.quality, pm.F1]; % Store the computed metrics for the current feature, NDVI threshold fraction, filtering option, and development tile in the results array. The metrics stored are relaxed F1 score (rF1), quality metric (Q), and pixel-level F1 score (F1).
            end

        end

    end

    fprintf('Validation %d/%d\n', k, nUse);
end

%% Aggregate the results across all development tiles for each feature, NDVI threshold fraction, and filtering option, and store them in a table for further analysis

rows = {};

% For each feature
for j = 1:nFeatures

    % For each NDVI threshold fraction
    for i = 1:numel(fraction)

        % For each filtering option (unfiltered and filtered)
        for v = 1:2
            x = squeeze(results(j, i, v, :, :)); % Extract the results for the current feature, NDVI threshold fraction, and filtering option across all development tiles. The resulting matrix x has dimensions (nUse x 3), where each row corresponds to a development tile and each column corresponds to a metric (rF1, Q, F1).
            mu = mean(x, 1, 'omitnan'); se = std(x, 0, 1, 'omitnan') / sqrt(nUse); % Compute the mean and standard error of the metrics across all development tiles for the current feature, NDVI threshold fraction, and filtering option. The mean is calculated while ignoring NaN values, and the standard error is computed as the standard deviation divided by the square root of the number of development tiles. The resulting vectors mu and se contain the mean and standard error for each metric (rF1, Q, F1), respectively.
            rows(end + 1, :) = {featNames{j}, fraction(i), v == 2, mu(1), se(1), mu(2), se(2), mu(3)}; %#ok<SAGROW> % Append a new row to the results table for the current feature, NDVI threshold fraction, and filtering option. The row contains the feature name, fraction of pixels predicted by the NDVI threshold, whether morphological filtering was applied (true for filtered, false for unfiltered), mean relaxed F1 score (rF1) and its standard error, mean quality metric (Q) and its standard error, and mean pixel-level F1 score (F1). The rows are stored in a cell array for further analysis and visualization.
        end

    end

end

T = cell2table(rows, 'VariableNames', {'feature', 'predFrac', 'filtered', 'rF1', 'rF1_se', 'Quality', 'Q_se', 'F1'});
disp(T);
save(fullfile(c.resultsDirectory, 'stage3_features.mat'), 'T', 'results', 'thresholds', 'fraction');
