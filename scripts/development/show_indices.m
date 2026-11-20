%% show_indices.m
clear; close all; clc;
id = 'img103'; % Tile ID to visualize

%% Load the tile and compute indices

t = load_tile(id);
[S, names] = compute_indices(t.A);

%% Display the RGB image and the computed indices

rgb = t.A(:, :, [5 3 2]); 
valid = repmat(t.valid, [1 1 3]);
lo = prctile(rgb(valid), 2); 
hi = prctile(rgb(valid), 98);
[r, c] = find(t.cl); % Find the coordinates of the road pixels

figure('Name', id); 
tiledlayout(2, 3, 'TileSpacing', 'compact');
nexttile; 
imshow(min(max(rescale(rgb, 0, 1, 'InputMin', lo, 'InputMax', hi), 0), 1));
title('RGB');

% For each computed index, display the image with road pixels overlaid
for k = 1:numel(names)
    x = S(:, :, k); v = x(t.valid);
    nexttile; 
    imshow(x, [prctile(v, 2) prctile(v, 98)]);
    hold on; plot(c, r, 'r.', 'MarkerSize', 1);
    title(names{k});
end
