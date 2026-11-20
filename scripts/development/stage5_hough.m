%% stage5_hough.m
clear; close all; clc;
c = config();

%% Load the development tile IDs and initialize parameters for the Hough transform evaluation stage

load(fullfile(c.resultsDirectory, 'split.mat'), 'devIds');

nUse = 30; % Number of development tiles to use for the evaluation
threshold = 0.30; % NDVI threshold to use for the initial mask generation (stage B)
radius = 55; % Radius for morphological closing operation to fill small gaps in the predicted masks
lOpen = 60; % Length for morphological opening operation to remove small objects from the predicted masks
minArea = 100; % Minimum area of connected components to keep when cleaning the predicted masks
minBranch = 20; % Minimum length of branches in the skeleton
pB = struct('minArea', minArea, 'radius', radius, 'lClose', 0, 'lOpen', lOpen);

nPeaks = 60; % Number of peaks to detect in the Hough transform accumulator array
thresholdFraction = 0.25; % Fraction of the maximum value in the Hough transform accumulator array to use as a threshold for peak detection
configs = []; % Array to hold the configurations of Hough transform parameters (minimum length and fill gap) to evaluate

% Generate all combinations of the specified parameters for Hough transform evaluation and store them in the 'configs' array
for a = [40 80 120] % Minimum length of segments to keep

    for g = [20 50] % Fill gap parameter for the Hough transform line detection
        configs = [configs; a g]; %#ok<AGROW>
    end

end

nConfigs = size(configs, 1);
rLine = 12; % Semilength of the structuring element used for dilating the detected lines in the Hough transform evaluation
rHybrid = 20; % Maximum distance from the detected lines to consider when combining the Hough transform results with the stage B predictions in the hybrid evaluation

%% Load the development tiles, clean the predicted masks from stage B, compute the skeletons, perform the Hough transform, and store the results for each tile

D = struct('mask', cell(nUse, 1), 'skeleton', [], 'P', [], 'gt', [], 'cl', [], 'valid', [], 'tolerancePixels', []);

for k = 1:nUse
    tile = load_tile(devIds(k)); % Load the tile with the specified ID and its corresponding ground truth (if available)
    S = compute_indices(tile.A); % Compute spectral indices for the tile's multispectral image
    mask = clean_mask(S(:, :, 1) <= threshold, tile.valid, pB); % Clean the predicted mask from stage B by applying the NDVI threshold, morphological operations, and area filtering based on the specified parameters in 'pB'
    skeleton = bwskel(mask, 'MinBranchLength', minBranch); % Compute the skeleton of the cleaned predicted mask using the 'bwskel' function, which performs skeletonization while preserving the connectivity of the structures and removing branches shorter than 'minBranch' pixels
    [H, theta, rho] = hough(skeleton); % Perform the Hough transform on the skeletonized image to detect lines, returning the accumulator array 'H', the theta values 'Th', and the rho values 'Rho' that represent the detected lines in polar coordinates

    if nnz(skeleton) > 0
        P = houghpeaks(H, nPeaks, 'Threshold', thresholdFraction * max(H(:))); % Detect peaks in the Hough transform accumulator array 'H' to identify the most prominent lines, returning the coordinates of the detected peaks in the 'P' array. The number of peaks to detect is specified by 'nPeaks', and a threshold is applied based on a fraction of the maximum value in 'H' to filter out less significant peaks.
    else
        P = zeros(0, 2); % If the skeleton is empty, set 'P' to an empty array with 0 rows and 2 columns
    end

    D(k).mask = mask;
    D(k).skeleton = skeleton; D(k).P = P;
    D(k).gt = tile.gt;
    D(k).cl = tile.cl;
    D(k).valid = tile.valid;
    D(k).tolerancePixels = c.tolerance / pixel_size(tile.R);
    fprintf('Loaded %d/%d\n', k, nUse);
end

%% Evaluate the performance of the Hough transform-based line detection and hybrid approach compared to the stage B predictions for each tile, and store the results in a table for analysis

resultsB = zeros(nUse, 5); % Results for stage B predictions (baseline)
resultsL = zeros(nConfigs, nUse, 5); % Results for Hough transform-based line detection
resultsH = zeros(nConfigs, nUse, 5); % Results for hybrid approach combining stage B predictions and Hough transform-based line detection

% For each development tile
for k = 1:nUse
    d = D(k);
    resultsB(k, :) = evaluate(d.mask, d, minBranch); % Baseline is the evaluation of the stage B predictions

    for ic = 1:nConfigs
        lb = false(size(d.mask)); % Initialize binary image for the detected lines to false (0) for the current configuration

        if ~isempty(d.P)
            L = houghlines(d.skeleton, theta, rho, d.P, 'FillGap', configs(ic, 2), 'MinLength', configs(ic, 1)); % Compute the line segments detected by the Hough transform
            lb = draw_lines(L, size(d.mask)); % Draw the detected lines on a binary image of the same size as the predicted mask
        end

        resultsL(ic, k, :) = evaluate(imdilate(lb, strel('disk', rLine)) & d.valid, d, minBranch); % Save the evaluation results for the Hough transform-based line detection
        resultsH(ic, k, :) = evaluate(d.mask & imdilate(lb, strel('disk', rHybrid)), d, minBranch); % Save the evaluation results for the hybrid approach
    end

    fprintf('Evaluation %d/%d\n', k, nUse);
end

%% Analyze the evaluation results, compute summary statistics, and display the results in a table for comparison of the different approaches (stage B, Hough transform-based line detection, and hybrid approach)

rows = {'stage B', 0, 0, mean(resultsB(:, 1)), mean(resultsB(:, 2)), mean(resultsB(:, 3)), mean(resultsB(:, 4)), 0, 0, 0, 0, 0};

for ic = 1:nConfigs

    for v = 1:2

        if v == 1
            X = squeeze(resultsL(ic, :, :)); % Results for Hough transform-based line detection
            name = 'lines';
        else
            X = squeeze(resultsH(ic, :, :)); % Results for hybrid approach
            name = 'hybrid';
        end

        dR = X(:, 1) - resultsB(:, 1); % Difference in relaxed F1 score between the current approach and stage B predictions
        dQ = X(:, 4) - resultsB(:, 4); % Difference in centerline quality between the current approach and stage B predictions
        rows(end + 1, :) = {name, configs(ic, 1), configs(ic, 2), mean(X(:, 1)), mean(X(:, 2)), mean(X(:, 3)), mean(X(:, 4)), ...
                                mean(dR), std(dR) / sqrt(nUse), sum(dR > 0), mean(dQ), std(dQ) / sqrt(nUse)}; %#ok<SAGROW>
    end

end

Tab = cell2table(rows, 'VariableNames', {'variant', 'minLen', 'fillGap', 'rF1', 'rPrec', 'rRec', ...
                              'Quality', 'dRF1', 'dRF1_se', 'wins', 'dQ', 'dQ_se'});
Tab = sortrows(Tab, 'rF1', 'descend');
disp(Tab);
save(fullfile(c.resultsDirectory, 'stage5_results.mat'), 'Tab', 'resultsB', 'resultsL', 'resultsH', 'configs');

%% Visualize the results for the best configuration of the Hough transform-based line detection and hybrid approach compared to the stage B predictions for a selected tile

Tn = Tab(~strcmp(Tab.variant, 'stadio B'), :);
b = Tn(1, :);
k = min(2, nUse);
d = D(k);
L = houghlines(d.skeleton, theta, rho, d.P, 'FillGap', b.fillGap, 'MinLength', b.minLen);
lb = draw_lines(L, size(d.mask));
figure;

tiledlayout(1, 3, 'TileSpacing', 'compact');
nexttile;

imshowpair(d.mask, d.gt);
title('Stage B');
nexttile;

imshowpair(imdilate(lb, strel('disk', rLine)) & d.valid, d.gt);
title('Hough lines');
nexttile;

imshowpair(d.mask & imdilate(lb, strel('disk', rHybrid)), d.gt);
title('Hybrid');
sgtitle('Green = prediction, Magenta = GT, White = agreement');

function m = evaluate(pred, d, minBranch)
    %EVALUATE Evaluate the performance of the predicted mask against the ground truth and centerline data.
    %   m = EVALUATE(pred, d, minBranch) computes various metrics to
    %   evaluate the performance of the predicted binary mask 'pred'
    %   against the ground truth data 'd.gt' and centerline data 'd.cl'.
    %
    %   Input:
    %       pred      - A binary image representing the predicted mask.
    %       d         - A structure containing the ground truth data and other relevant information:
    %                     d.gt              : A binary image representing the ground truth mask.
    %                     d.cl              : A binary image representing the centerline of the ground truth mask.
    %                     d.valid           : A binary image indicating the valid region for evaluation.
    %                     d.tolerancePixels : A scalar value representing the tolerance in pixels for relaxed metrics.
    %       minBranch - A scalar value representing the minimum length of branches to consider in the centerline evaluation.
    %
    %   Output:
    %       m - A vector containing the computed metrics:
    %             m(1) : Relaxed F1 score
    %             m(2) : Relaxed Precision
    %             m(3) : Relaxed Recall
    %             m(4) : Centerline Quality
    %             m(5) : Pixel-level F1 score

    pm = pixel_metrics(pred, d.gt, d.valid);
    rm = relaxed_metrics(pred, d.gt, d.valid, d.tolerancePixels);
    cm = centerline_metrics(pred, d.cl, d.valid, d.tolerancePixels, minBranch);
    m = [rm.rF1, rm.rPrecision, rm.rRecall, cm.quality, pm.F1];
end
