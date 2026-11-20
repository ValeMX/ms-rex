%% rank_band_pairs.m
clear; close all; clc;
c = config();

%% Load the development tile IDs and initialize parameters for band pair ranking

load(fullfile(c.resultsDirectory, 'split.mat'), 'devIds');
rng(1);
nPixels = 4000; % Number of road and background pixels to sample per tile
bandNames = {'C', 'B', 'G', 'Y', 'R', 'RE', 'N1', 'N2'};
pairs = nchoosek(1:8, 2); % All unique pairs of bands (8 choose 2)
nPairs = size(pairs, 1); % Number of unique band pairs
X = []; % Matrix to store features (ND values and computed indices)
Y = false(0, 1); % Vector to store labels (true for road pixels, false for background pixels)

%% Loop through each development tile, sample road and background pixels, compute features, and store them in X and Y

for k = 1:numel(devIds)
    tile = load_tile(devIds(k));
    road = imerode(tile.gt, strel('disk', 3)) & tile.valid; % Erode the ground truth mask to avoid edge pixels and ensure valid pixels
    background = tile.valid & ~imdilate(tile.gt, strel('disk', 8)); % Background pixels are valid pixels that are not near the road (dilated by 8 pixels)
    ir = find(road); % Indices of road pixels
    ib = find(background); % Indices of background pixels
    if numel(ir) < 50 || numel(ib) < 50, continue; end % Skip tiles with too few road or background pixels
    ir = ir(randperm(numel(ir), min(nPixels, numel(ir)))); % Randomly sample up to nPixels road pixels
    ib = ib(randperm(numel(ib), min(nPixels, numel(ib)))); % Randomly sample up to nPixels background pixels
    idx = [ir; ib]; % Indices of sampled pixels (road and background)

    a = reshape(tile.A, [], 8); % Reshape the multispectral image to a 2D array of size [N x 8], where N is the number of pixels and 8 is the number of bands
    a = a(idx, :); % Select only the sampled pixels (road and background) for feature computation
    f = zeros(numel(idx), nPairs); % Initialize a matrix to store the normalized difference (ND) values for each band pair

    % Compute the normalized difference (ND) for each unique pair of bands and store them in the feature matrix f
    for j = 1:nPairs
        p = pairs(j, :);
        f(:, j) = (a(:, p(1)) - a(:, p(2))) ./ (a(:, p(1)) + a(:, p(2)) + eps);
    end

    % Compute additional spectral indices (NDVI, NDWI, REI, BAI, Brightness) for the sampled pixels and store them in the feature matrix X
    [S, idxNames] = compute_indices(a);
    X = [X; f, S]; %#ok<AGROW>
    Y = [Y; true(numel(ir), 1); false(numel(ib), 1)]; %#ok<AGROW>
    fprintf('%d/%d\n', k, numel(devIds));
end

%% Compute the AUC (Area Under the Curve) for each feature (ND values and computed indices) to evaluate their separability between road and background pixels

names = [strcat('ND(', bandNames(pairs(:, 1)), ',', bandNames(pairs(:, 2)), ')'), idxNames];
nFeatures = size(X, 2); % Number of features (ND values and computed indices)
auc = zeros(1, nFeatures); % Initialize a vector to store the AUC values for each feature
for j = 1:nFeatures, auc(j) = auc_score(X(:, j), Y); end % Compute the AUC for each feature using the auc_score function defined below
sep = abs(auc - 0.5) * 2; % Compute the separability metric for each feature, which is a measure of how well the feature separates road and background pixels (0 = no separability, 1 = perfect separability)

Rk = table(names(:), auc(:), sign(auc(:) - 0.5), sep(:), 'VariableNames', {'index', 'AUC', 'sign', 'separability'});
Rk = sortrows(Rk, 'separability', 'descend');
disp(Rk(1:15, :));
save(fullfile(c.resultsDirectory, 'band_ranking.mat'), 'Rk');

%% Visualize the separability of road vs. background pixels for each band pair in a heatmap

% Fill the upper triangular part of the matrix M with the separability values for each band pair
M = nan(8);
for j = 1:nPairs, M(pairs(j, 1), pairs(j, 2)) = sep(j); end

figure;
imagesc(M);
axis image;
colorbar;
xticks(1:8);
xticklabels(bandNames);
yticks(1:8);
yticklabels(bandNames);
title('Separability of road vs. background pixels for each band pair');

function a = auc_score(x, y)
    %AUC_SCORE Compute the Area Under the Curve (AUC) for a given feature and its corresponding labels.
    %   a = AUC_SCORE(x, y) computes the AUC for the feature values x and binary labels y.
    %
    %   Input:
    %       x - A vector of feature values (numeric).
    %       y - A vector of binary labels (logical or numeric, where true/1 indicates road pixels
    %           and false/0 indicates background pixels).
    %
    %   Output:
    %       a - The computed AUC value, or NaN if not found or convertible.

    y = logical(y); % Convert the labels to logical values (true for road pixels, false for background pixels)
    [~, o] = sort(x); % Sort the feature values and obtain the sorting indices
    r = zeros(size(x)); % Initialize a vector to store the ranks of the feature values
    r(o) = 1:numel(x); % Assign ranks to the feature values based on the sorting indices
    n1 = sum(y); % Number of positive samples (road pixels)
    n0 = sum(~y); % Number of negative samples (background pixels)
    a = (sum(r(y)) - n1 * (n1 + 1) / 2) / (n1 * n0); % Compute the AUC using the formula based on the ranks of the positive samples
end
