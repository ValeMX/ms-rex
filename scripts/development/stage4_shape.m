%% stage4_shape.m
clear; close all; clc;
c = config();

%% Load the development tile IDs and initialize parameters for the shape filtering stage

load(fullfile(c.resultsDirectory, 'split.mat'), 'devIds');

nUse = 30; % Number of development tiles to use for the evaluation
threshold = 0.30; % NDVI threshold to use for the initial mask generation (stage B)
radius = 55; % Radius for morphological closing operation to fill small gaps in the predicted masks
lOpen = 60; % Length for morphological opening operation to remove small objects from the predicted masks
minArea = 100; % Minimum area of connected components to keep when cleaning the predicted masks
minBranch = 20; % Minimum length of branches in the skeleton
wMin = 6; % Minimum mean width of connected components to keep when filtering based on shape metrics
wMax = 60; % Maximum mean width of connected components to keep when filtering based on shape metrics
pB = struct('minArea', minArea, 'radius', radius, 'lClose', 0, 'lOpen', lOpen); % Parameters for cleaning the predicted masks in stage B (morphological operations and area filtering)

minLengthList = [0 40 80 120]; % Minimum length of segments to keep
cvList = [Inf 0.8 0.5]; % Coefficient of variation of width to keep
elList = [0 4]; % Minimum elongation (length/width) of segments to keep
configs = [0 Inf 0 0]; % Initial configuration for shape filtering (no filtering applied)

% Generate all combinations of the specified parameters for shape filtering and store them in the 'configs' array. Each row of 'configs' corresponds to a unique combination of parameters: minimum length, maximum coefficient of variation, minimum elongation, and whether to use width filtering (1 for yes, 0 for no). The nested loops iterate through each parameter list and append the resulting configurations to the 'configs' array.
for a = minLengthList

    for b = cvList

        for e = elList
            configs = [configs; a b e 1]; %#ok<AGROW>
        end

    end

end

nConfigs = size(configs, 1);
D = struct('lab', cell(nUse, 1), 'st', [], 'gt', [], 'cl', [], 'valid', [], 'tolerancePixels', []);

%% Load the development tiles, clean the predicted masks from stage B, compute connected component statistics, and store the results for each tile

for k = 1:nUse
    tile = load_tile(devIds(k)); % Load the tile with the specified ID and its corresponding ground truth (if available)
    S = compute_indices(tile.A); % Compute spectral indices for the tile's multispectral image
    m = clean_mask(S(:, :, 1) <= threshold, tile.valid, pB); % Clean the predicted mask from stage B by applying the NDVI threshold, morphological operations, and area filtering based on the specified parameters in 'pB'
    [labels, stats] = component_stats(m, minBranch); % Compute connected component statistics for the cleaned predicted mask, including labeling the connected components and calculating their properties (area, length, mean width, coefficient of variation of width, etc.) while considering only branches longer than 'minBranch' pixels
    D(k).lab = uint16(labels); % Store the labeled image of connected components as a uint16 array in the 'lab' field of the struct 'D' for the current tile
    D(k).st = stats; % Store the computed statistics of the connected components in the 'st' field of the struct 'D' for the current tile
    D(k).gt = tile.gt; % Store the ground truth mask for the current tile in the 'gt' field of the struct 'D'
    D(k).cl = tile.cl; % Store the centerline mask for the current tile in the 'cl' field of the struct 'D'
    D(k).valid = tile.valid; % Store the valid mask for the current tile in the 'valid' field of the struct 'D' (indicating valid pixels)
    D(k).tolerancePixels = c.tolerance / pixel_size(tile.R); % Store the tolerance in pixels for the current tile, calculated based on the pixel size in meters and the specified tolerance in the configuration
    fprintf('Loaded %d/%d\n', k, nUse);
end

%% Evaluate the performance of each configuration of shape filtering parameters for each development tile

% Initialize an array to hold the evaluation results for each configuration of shape filtering parameters and each development tile.
% The dimensions of the 'results' array are (number of configurations) x (number of development tiles) x (number of metrics),
% where the metrics include rF1, rPrecision, rRecall, relaxed F1, and centerline quality.
results = zeros(nConfigs, nUse, 5);

% For each configuration
for ic = 1:nConfigs
    % Set the parameters for shape filtering based on the current configuration
    p = struct('minLen', configs(ic, 1), 'cvMax', configs(ic, 2), 'minElong', configs(ic, 3), 'wMin', configs(ic, 4) * wMin, 'wMax', Inf);
    if configs(ic, 4), p.wMax = wMax; end % If the 'useW' parameter in the current configuration is set to 1, set the maximum mean width for shape filtering to 'wMax'; otherwise, leave it as Inf (no upper limit on mean width).

    % For each development tile
    for k = 1:nUse
        pred = shape_filter(D(k).lab, D(k).st, p) & D(k).valid; % Apply the shape filtering function to the labeled image and statistics of the current tile using the specified parameters in 'p'. The result is a binary mask indicating which connected components to keep based on the shape metrics. The '& D(k).valid' operation ensures that only valid pixels are considered in the final prediction mask.
        pm = pixel_metrics(pred, D(k).gt, D(k).valid); % Compute pixel-level metrics (precision, recall, F1 score) for the predicted mask 'pred' against the ground truth mask 'D(k).gt', considering only valid pixels as indicated by 'D(k).valid'. The result is stored in the struct 'pm', which contains fields for precision, recall, and F1 score.
        rm = relaxed_metrics(pred, D(k).gt, D(k).valid, D(k).tolerancePixels); % Compute relaxed metrics (relaxed precision, relaxed recall, relaxed F1 score) for the predicted mask 'pred' against the ground truth mask 'D(k).gt', considering only valid pixels as indicated by 'D(k).valid' and using the specified tolerance in pixels 'D(k).tolerancePixels'. The result is stored in the struct 'rm', which contains fields for relaxed precision, relaxed recall, and relaxed F1 score.
        cm = centerline_metrics(pred, D(k).cl, D(k).valid, D(k).tolerancePixels, minBranch); % Compute centerline-level metrics (completeness, correctness, quality) for the predicted mask 'pred' against the ground truth centerline mask 'D(k).cl', considering only valid pixels as indicated by 'D(k).valid', using the specified tolerance in pixels 'D(k).tolerancePixels', and considering only branches longer than 'minBranch' pixels. The result is stored in the struct 'cm', which contains fields for completeness, correctness, and quality.
        results(ic, k, :) = [pm.F1, rm.rPrecision, rm.rRecall, rm.rF1, cm.quality]; % Store the computed metrics for the current configuration and tile in the 'results' array. The metrics stored are:pixel - level F1 score (pm.F1), relaxed precision (rm.rPrecision), relaxed recall (rm.rRecall), relaxed F1 score (rm.rF1), and centerline quality (cm.quality).
    end

    fprintf('Config %d/%d\n', ic, nConfigs);
end

%% Analyze the results of the shape filtering evaluation, compute summary statistics, and display the top configurations based on relaxed F1 score

base = squeeze(results(1, :, :));
rows = zeros(nConfigs, 11);

for ic = 1:nConfigs
    x = squeeze(results(ic, :, :)); % Extract the results for the current configuration across all development tiles, resulting in a 2D array where each row corresponds to a tile and each column corresponds to a metric (rF1, rPrecision, rRecall, relaxed F1, centerline quality).
    d = x(:, 4) - base(:, 4); % Compute the difference in relaxed F1 score between the current configuration and the baseline configuration (first configuration) for each development tile. The result is a column vector 'd' where each element represents the change in relaxed F1 score for a specific tile.
    rows(ic, :) = [configs(ic, :), mean(x(:, [4 2 3 5]), 1, 'omitnan'), mean(d, 'omitnan'), std(d, 'omitnan') / sqrt(nUse), sum(d > 0)];
end

T = array2table(rows, 'VariableNames', {'minLen', 'cvMax', 'minElong', 'useW', 'rF1', 'rPrec', 'rRec', 'Quality', 'dRF1', 'dRF1_se', 'wins'});
T = sortrows(T, 'rF1', 'descend');
disp(T(1:min(12, height(T)), :));
save(fullfile(c.resultsDirectory, 'stage4_results.mat'), 'T', 'results', 'configs');

%% Visualize the effect of shape filtering on a specific development tile using the best configuration based on relaxed F1 score

b = T(1, :); k = min(2, nUse);
pb = struct('minLen', b.minLen, 'cvMax', b.cvMax, 'minElong', b.minElong, 'wMin', b.useW * wMin, 'wMax', Inf);
if b.useW, pb.wMax = wMax; end
predB = D(k).lab > 0;
predS = shape_filter(D(k).lab, D(k).st, pb);
figure;
tiledlayout(1, 2, 'TileSpacing', 'compact');

nexttile;
imshowpair(predB, D(k).gt); title('Stage B');

nexttile;
imshowpair(predS, D(k).gt); title('Stage B with shape filtering');

sgtitle('Green = prediction, Magenta = GT, White = agreement');
