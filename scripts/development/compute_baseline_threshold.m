%% baseline_threshold.m
clear; close all; clc;
c = config();

%% Load the development tile IDs and initialize parameters for baseline threshold computation

load(fullfile(c.resultsDirectory, 'split.mat'), 'devIds');
featureNames = {'-NDVI', 'ND(R,N2)', '-REI'};
nFeatures = numel(featureNames);

sampledPixels = zeros(0, nFeatures); % Initialize an empty array to hold sampled pixel values for each feature across all development tiles

for k = 1:5
    tile = load_tile(devIds(k), false); % Load the development tile without loading the ground truth
    F = reshape(getfeatures(tile.A, tile.valid), [], nFeatures); % Reshape the features into a 2D array where each row corresponds to a pixel and each column corresponds to a feature
    F = F(tile.valid(:), :); % Keep only the valid pixels based on the tile's validity mask
    sampledPixels = [sampledPixels; F(1:50:end, :)]; %#ok<AGROW> % Randomly sample 1 out of every 50 valid pixels to reduce the dataset size for histogram computation
end

edges = cell(1, nFeatures); % Initialize a cell array to hold histogram edges for each feature

%% Compute histogram edges and counts for each feature

for j = 1:nFeatures
    % Compute histogram edges for feature j using the 0.5th and 99.5th percentiles of the sampled pixel values
    edges{j} = [-inf, linspace(prctile(sampledPixels(:, j), 0.5), prctile(sampledPixels(:, j), 99.5), 400), inf];
end

countRoad = cell(1, nFeatures); % Initialize a cell array to hold the histogram counts for true positive pixels (pixels that are part of the ground truth) for each feature
countBackground = cell(1, nFeatures); % Initialize a cell array to hold the histogram counts for false positive pixels (pixels that are not part of the ground truth) for each feature

for j = 1:nFeatures
    countRoad{j} = zeros(1, numel(edges{j}) - 1); % Initialize the histogram counts for true positive pixels for feature j
    countBackground{j} = countRoad{j}; % Initialize the histogram counts for false positive pixels for feature j
end

%% Compute histograms for each development tile and each feature

for k = 1:numel(devIds)
    tile = load_tile(devIds(k)); % Load the development tile along with its ground truth and validity mask
    F = getfeatures(tile.A, tile.valid); % Compute the spectral features for the tile's multispectral image

    % Compute histograms for each feature based on the ground truth and validity mask
    for j = 1:nFeatures
        Fj = F(:, :, j); % Extract the feature values for feature j
        countRoad{j} = countRoad{j} + histcounts(Fj(tile.gt & tile.valid), edges{j}); % Update the histogram counts for true positive pixels (pixels that are part of the ground truth) for feature j
        countBackground{j} = countBackground{j} + histcounts(Fj(~tile.gt & tile.valid), edges{j}); % Update the histogram counts for false positive pixels (pixels that are not part of the ground truth) for feature j
    end

    fprintf('histogram %d/%d\n', k, numel(devIds));
end

%% Compute precision-recall curves and determine the optimal threshold for each feature

threshold = zeros(1, nFeatures);
figure;
hold on;
grid on;

fprintf('\n');

for j = 1:nFeatures
    TP = fliplr(cumsum(fliplr(countRoad{j}))); % Compute the cumulative sum of true positive counts in reverse order to get the number of true positives for each threshold
    FP = fliplr(cumsum(fliplr(countBackground{j}))); % Compute the cumulative sum of false positive counts in reverse order to get the number of false positives for each threshold
    FN = sum(countRoad{j}) - TP; % Compute the number of false negatives for each threshold by subtracting the cumulative true positives from the total true positives

    P = TP ./ max(TP + FP, 1); % Compute precision for each threshold
    Rc = TP ./ max(TP + FN, 1); % Compute recall for each threshold
    F1 = 2 * TP ./ max(2 * TP + FP + FN, 1); % Compute F1 score for each threshold

    [bestF1, i] = max(F1); % Find the index of the threshold that gives the best F1 score
    threshold(j) = edges{j}(i); % Store the optimal threshold for feature j based on the best F1 score

    plot(Rc, P, 'LineWidth', 1.5, 'DisplayName', featureNames{j}); % Plot the precision-recall curve for feature j
    prev = sum(countRoad{j}) / (sum(countRoad{j}) + sum(countBackground{j})); % Compute the prevalence of road pixels in the dataset for feature j
    fprintf('%-10s threshold %.4f | F1 %.3f  P %.3f  R %.3f  (prevalence %.3f)\n', featureNames{j}, threshold(j), bestF1, P(i), Rc(i), prev);
end

yline(prev, '--k', 'random guess');
xlabel('Recall');
ylabel('Precision');
legend('Location', 'northeast');
title('Precision-Recall Curves for Baseline Thresholds');

%% Evaluate the performance of the optimal thresholds on the development tiles

% Initialize a 3D array to hold the evaluation metrics for each development tile and each feature.
% The third dimension corresponds to the following metrics:
% F1 score, Intersection over Union (IoU), completeness, correctness, and quality.
results = zeros(numel(devIds), nFeatures, 5);

fprintf('\n');

for k = 1:numel(devIds)
    tile = load_tile(devIds(k)); % Load the development tile along with its ground truth and validity mask
    F = getfeatures(tile.A, tile.valid); % Compute the spectral features for the tile's multispectral image
    tolerancePixels = c.tolerance / pixel_size(tile.R); % Compute the tolerance in pixels based on the specified tolerance in meters and the pixel size of the tile's spatial referencing object

    for j = 1:nFeatures
        pred = (F(:, :, j) >= threshold(j)) & tile.valid; % Generate a binary prediction mask for feature j based on the optimal threshold and the validity mask
        pm = pixel_metrics(pred, tile.gt, tile.valid); % Compute pixel-level evaluation metrics (F1 score and IoU) for the prediction mask against the ground truth and validity mask
        cm = centerline_metrics(pred, tile.cl, tile.valid, tolerancePixels); % Compute centerline-level evaluation metrics (completeness, correctness, and quality) for the prediction mask against the ground truth centerline and validity mask
        results(k, j, :) = [pm.F1, pm.IoU, cm.completeness, cm.correctness, cm.quality]; % Store the evaluation metrics for feature j and development tile k in the results array
    end

    fprintf('evaluation %d/%d\n', k, numel(devIds));
end

%% Save the evaluation results and display a summary table of the average metrics for each feature

% Compute the mean evaluation metrics across all development tiles for each feature, ignoring NaN values.
% The resulting matrix M has dimensions (nFeatures x 5), where each row corresponds to a feature and
% each column corresponds to an evaluation metric (F1 score, IoU, completeness, correctness, quality).
M = squeeze(mean(results, 1, 'omitnan'));

T = array2table(M, 'RowNames', featureNames, 'VariableNames', {'F1', 'IoU', 'Completeness', 'Correctness', 'Quality'});
disp(T);
save(fullfile(c.resultsDirectory, 'baseline_results.mat'), 'threshold', 'featureNames', 'results', 'T');

%% Display a visual example of the best-performing feature (by Quality)

[~, jb] = max(M(:, 5));
tile = load_tile(devIds(2));
F = getfeatures(tile.A, tile.valid);
pred = (F(:, :, jb) >= threshold(jb)) & tile.valid;
figure;
imshowpair(pred, tile.gt);
title(sprintf('%s: prediction (green) and GT (magenta), white = agreement', featureNames{jb}));

function F = getfeatures(A, valid)
    %GETFEATURES Computes spectral features (ND values and indices) for a multispectral image.
    %   F = GETFEATURES(A) computes the spectral features for a multispectral image A
    %   with 8 bands (B, G, R, NIR, REI, NDVI, NDWI, BAI). The output F is a 3D array
    %   where each slice corresponds to a specific feature.
    %
    %   Input:
    %       A     - Multispectral image (3D array) with 8 bands.
    %       valid - (Optional) 2D logical mask indicating valid pixels. If not provided,
    %               all pixels are considered valid.
    %
    %   Output:
    %       F - 3D array of spectral features, where each slice corresponds to a specific feature:
    %           F(:, :, 1) - Negative NDVI (-NDVI)
    %           F(:, :, 2) - Normalized difference between Red (R) and NIR2 (N2) bands (ND(R,N2))
    %           F(:, :, 3) - Negative REI (-REI)

    if nargin < 2, valid = true(size(A, 1), size(A, 2)); end

    [S, ~] = compute_indices(A); % Compute spectral indices (NDVI, NDWI, REI, BAI, Brightness) for the multispectral image A
    R = A(:, :, 5); % Extract the Red (R) band from the multispectral image A
    N2 = A(:, :, 8); % Extract the NIR2 (N2) band from the multispectral image A
    F = cat(3, -S(:, :, 1), ... % Negative NDVI (-NDVI)
        (R - N2) ./ (R + N2 + eps), ... % Normalized difference between Red (R) and NIR2 (N2) bands (ND(R,N2))
        -S(:, :, 3)); % Negative REI (-REI)

    % Normalize each feature slice to have zero mean and unit variance based on valid pixels
    for j = 1:size(F, 3)
        x = F(:, :, j);
        v = x(valid);
        F(:, :, j) = (x - mean(v)) / std(v);
    end

end
