function [gt, cl] = generate_ground_truth(lines, R, imgSize, opts)
    %GENERATE_GROUND_TRUTH Generates ground truth masks from vector road segments.
    %   [gt, cl] = GENERATE_GROUND_TRUTH(lines, R, imgSize) converts geographic road
    %   segments into two binary masks aligned with a georeferenced raster image:
    %   a thick road segmentation mask (gt) scaled by lane count, and a 1-pixel
    %   wide centerline mask (cl).
    %
    %   [gt, cl] = GENERATE_GROUND_TRUTH(lines, R, imgSize, opts) allows customizing lane
    %   width and fallback lane count via the options struct.
    %
    %   Input:
    %       lines   - 1xN struct array from READ_GEOJSON containing fields:
    %                   xy    : Mx2 matrix of [longitude, latitude] coordinates.
    %                   lanes : Number of lanes (numeric scalar or NaN).
    %       R       - GeographicCellsReference spatial referencing object
    %                 associated with the target raster image.
    %       imgSize - 1x2 numeric vector [numRows, numCols] specifying the
    %                 output mask dimensions.
    %       opts    - (Optional) Struct with optional configuration fields:
    %                   laneWidth   : Width of a single lane in meters
    %                                  (default: 3.0).
    %                   defaultLanes : Fallback number of lanes used when
    %                                  'lanes' is NaN or < 1 (default: 2).
    %
    %   Output:
    %       gt      - numRows x numCols logical mask of the full road surface,
    %                 dilated according to lane count (minimum radius 1.5 px).
    %       cl      - numRows x numCols logical mask of the thin road
    %                 centerlines.

    % Read and validate input arguments
    if nargin < 3, error('Insufficient input arguments.'); end
    if nargin < 4, opts = struct; end
    laneWidth = 3.0; if isfield(opts, 'laneWidth'), laneWidth = opts.laneWidth; end
    defaultLanes = 2; if isfield(opts, 'defaultLanes'), defaultLanes = opts.defaultLanes; end

    numRows = imgSize(1);
    numCols = imgSize(2);
    latMax = R.LatitudeLimits(2); % Maximum latitude
    lonMin = R.LongitudeLimits(1); % Minimum longitude
    dLat = R.CellExtentInLatitude; % Latitude extent per pixel in degrees
    dLon = R.CellExtentInLongitude; % Longitude extent per pixel in degrees

    % Compute pixel-to-meter conversion factors based on geographic extents
    latMid = mean(R.LatitudeLimits);
    mLat = dLat * 111320; % Approximate meters per degree latitude
    mLon = dLon * 111320 * cosd(latMid); % Approximate meters per degree longitude at mid-latitude
    pxM = sqrt(mLat * mLon); % Average meters per pixel

    cl = false(numRows, numCols);
    gt = false(numRows, numCols);

    % Return empty masks if no road segments are provided
    if isempty(lines), return; end

    lanes = [lines.lanes];
    lanes(isnan(lanes) | lanes < 1) = defaultLanes;
    groups = unique(lanes);

    for group = groups
        mask = false(numRows, numCols);

        for line = find(lanes == group)
            xy = lines(line).xy; % Extract the coordinates for the current road segment
            row = (latMax - xy(:, 2)) / dLat + 0.5; % Convert latitude to row index and add 0.5 for pixel center alignment
            col = (xy(:, 1) - lonMin) / dLon + 0.5; % Convert longitude to column index and add 0.5 for pixel center alignment

            % Iterate through each pair of consecutive points in the road segment to create the mask
            for s = 1:numel(row) - 1
                % Ensure at least 2 points per pixel distance to avoid gaps in the mask
                n = ceil(max(abs(row(s + 1) - row(s)), abs(col(s + 1) - col(s)))) * 2 + 1;

                % Generate linearly spaced indices between the two points and round to nearest pixel
                rowLine = round(linspace(row(s), row(s + 1), n));
                colLine = round(linspace(col(s), col(s + 1), n));

                % Check line indices are within image bounds
                ok = rowLine >= 1 & rowLine <= numRows & colLine >= 1 & colLine <= numCols;

                % Create a mask for the current line segment and update the overall mask
                mask(sub2ind([numRows numCols], rowLine(ok), colLine(ok))) = true;
            end

        end

        % Update the centerline mask
        cl = cl | mask;

        % Update the ground truth mask by dilating the centerline mask based on lane count and lane width
        radiusPx = max(1.5, group * laneWidth / 2 / pxM);
        gt = gt | (bwdist(mask) <= radiusPx);
    end

end
