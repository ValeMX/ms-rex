%% scan_dataset.m
clear; clc;
root = 'C:\Users\valer\Desktop\Università\Image Processing\ms-rex\data\AOI_3_Paris';
msFiles = dir(fullfile(root, 'PS-MS', '*.tif'));
N = numel(msFiles);

%% Scan the dataset and collect statistics

id = strings(N, 1); % Tile IDs
validPixels = zeros(N, 1); % Percentage of valid pixels (non-black)
nLines = zeros(N, 1); % Number of lines in the corresponding geojson file
hasGT = false(N, 1); % Whether the tile has a non-empty ground truth (geojson file with lines)
allRoadTypes = []; % Road types from all lines in the dataset
allPaved = []; % Whether the roads are paved from all lines in the dataset
allLanes = []; % Number of lanes from all lines in the dataset

fprintf('Scanning %d PS-MS tiles in %s\n', N, root);

% Loop through each PS-MS tile and collect statistics
for k = 1:N
    % Extract the tile ID from the filename and read the PS-MS tile
    id(k) = regexp(msFiles(k).name, 'img\d+', 'match', 'once');
    A = readgeoraster(fullfile(msFiles(k).folder, msFiles(k).name));

    % Calculate the percentage of valid pixels (non-black) in the tile
    validPixels(k) = 100 * mean(any(A > 0, 3), 'all');

    geojsonFile = fullfile(root, 'geojson_roads', sprintf('SN3_roads_train_AOI_3_Paris_geojson_roads_%s.geojson', id(k)));

    if isfile(geojsonFile)
        L = read_geojson(geojsonFile);
        nLines(k) = numel(L);
        hasGT(k) = ~isempty(L);
        allRoadTypes = [allRoadTypes, [L.rtype]]; %#ok<AGROW>
        allPaved = [allPaved, [L.paved]]; %#ok<AGROW>
        allLanes = [allLanes, [L.lanes]]; %#ok<AGROW>
    end

    if mod(k, 25) == 0, fprintf('%d/%d\n', k, N); end
end

%% Save the collected statistics to a .mat file and display summary information

T = table(id, validPixels, nLines, hasGT);
save(fullfile('results', 'scan_results.mat'), 'T', 'allRoadTypes', 'allPaved', 'allLanes');

fprintf('\nTiles with ground truth: %d / %d\n', sum(hasGT), N);
fprintf('Tiles with black pixels (valid < 100%%): %d\n', sum(validPixels < 100));
fprintf('Valid pixels: min %.1f%%, median %.1f%%\n\n', min(validPixels), median(validPixels));
disp(sortrows(T(T.validPixels < 100, :), 'validPixels'));

% Display the distribution of road types, paved status, and number of lanes
for type = {'allRoadTypes', 'allPaved', 'allLanes'}
    value = eval(type{1});
    value(isnan(value)) = -1;
    [u, ~, j] = unique(value);
    fprintf('\n%s (value, count):\n', type{1});
    disp([u(:), accumarray(j(:), 1)]);
end
