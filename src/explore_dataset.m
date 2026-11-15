%% explore_dataset.m
clear; close all; clc;
root = 'C:\Users\valer\Desktop\Università\Image Processing\ms-rex\data\AOI_3_Paris';

%% 1) Retrieve directory information
d = dir(root);
directoryTable = struct2table(d(:), 'AsArray', true);
disp(directoryTable(:, {'name', 'isdir', 'bytes'}));

%% 2) Retrieve files information
msFiles = dir(fullfile(root, 'PS-MS', '*.tif'));
gjFiles = dir(fullfile(root, 'geojson_roads', '*.geojson'));
fprintf('PS-MS: %d tiles, geojson: %d files\n\n', numel(msFiles), numel(gjFiles));

%% 3) Inspect first tile
f = fullfile(msFiles(1).folder, msFiles(1).name);
[A, R] = readgeoraster(f);
info = geotiffinfo(f);
fprintf('Sample file: %s\n', msFiles(1).name);
fprintf('Size: %d x %d x %d, class: %s\n', size(A), class(A));

% Get the coordinate reference system (CRS) information
if isa(R, 'map.rasterref.MapCellsReference') % the tile is projected
    fprintf('CRS projected, cell: %.3f m\n', R.CellExtentInWorldX);
elseif isa(R, 'map.rasterref.GeographicCellsReference') % the tile is geographic
    fprintf('CRS geographic, cell: %.3e° lat x %.3e° lon\n', R.CellExtentInLatitude, R.CellExtentInLongitude);
    latMid = mean(R.LatitudeLimits);
    mLat = R.CellExtentInLatitude * 111320; % approximate conversion from degrees to meters
    mLon = R.CellExtentInLongitude * 111320 * cosd(latMid);
    fprintf('Approx. pixel size: %.2f m x %.2f m\n\n', mLat, mLon);
end

disp(R)

% Verify valid pixels and compute statistics
valid = any(A > 0, 3);
fprintf('Valid pixels: %.1f%%\n', 100 * mean(valid(:)));

for b = 1:size(A, 3)
    x = double(A(:, :, b)); x = x(valid);
    fprintf('Band %d: min %g  p2 %g  p98 %g  max %g\n', b, min(x), prctile(x, 2), prctile(x, 98), max(x));
end

% RGB view (order WV-3: C B G Y R RE N1 N2 -> R=5,G=3,B=2)
rgb = double(A(:, :, [5 3 2])); % extract RGB bands
vv = repmat(valid, [1 1 3]); % mask valid pixels
lo = prctile(rgb(vv), 2); % compute 2nd percentile for valid pixels
hi = prctile(rgb(vv), 98); % compute 98th percentile for valid pixels

% Display the RGB image with contrast stretching to avoid saturation
imshow(min(max(rescale(rgb, 0, 1, 'InputMin', lo, 'InputMax', hi), 0), 1));
title('PS-MS: RGB (bands 5-3-2)');

%% 4) Inspect first geojson file
gj = fullfile(gjFiles(1).folder, gjFiles(1).name);
s = jsondecode(fileread(gj));
fprintf('\nSample geojson: %s\n', gjFiles(1).name);
fprintf('CRS: %s\n\n', s.crs.properties.name);
fprintf('Features: %d\n', numel(s.features));
disp(s.features(1).properties);
fprintf('Geometry type: \n');
disp(s.features(1).geometry);
