function lines = read_geojson(fileName)
    %READ_GEOJSON Extracts road segments and attributes from a GeoJSON file.
    %   lines = READ_GEOJSON(fileName) reads a GeoJSON file containing road
    %   network features (e.g., LineString or MultiLineString geometries) and
    %   returns a struct array where each element corresponds to a single
    %   continuous coordinate segment along with its road attributes.
    %
    %   Input:
    %       fileName - Path to the input GeoJSON file.
    %
    %   Output:
    %       lines    - 1xN struct array with the following fields:
    %                    xy    : Mx2 double matrix of [X, Y] (or [lon, lat])
    %                            vertex coordinates for the segment.
    %                    lanes : Number of lanes (numeric scalar, NaN if
    %                            missing/invalid; checks 'lane_number' and
    %                            fallback 'lane_numbe').
    %                    rtype : Road type identifier (numeric scalar, NaN if
    %                            missing/invalid; from 'road_type').
    %                    paved : Paved surface indicator (numeric scalar, NaN
    %                            if missing/invalid; from 'paved').
    %                  Returns an empty 0x0 struct array with these fields if
    %                  no valid features or geometries are found.

    % Read and parse the GeoJSON file
    s = jsondecode(fileread(fileName));

    % Initialize output struct array
    lines = struct('xy', {}, 'lanes', {}, 'rtype', {}, 'paved', {});

    % Check for the presence of features in the GeoJSON structure
    if ~isfield(s, 'features') || isempty(s.features), return; end
    features = s.features;
    if isstruct(features), features = num2cell(features); end

    % Iterate over each feature (road) to extract geometry and properties
    for k = 1:numel(features)
        % Extract the current feature and check for geometry presence
        feature = features{k};
        if ~isfield(feature, 'geometry') || isempty(feature.geometry), continue; end

        % Extract geometry and properties
        geometry = feature.geometry;
        if ~isfield(geometry, 'coordinates') || isempty(geometry.coordinates), continue; end

        % Extract properties and handle missing attributes
        property = feature.properties;
        lanes = getvalue(property, 'lane_number');
        if isnan(lanes), lanes = getvalue(property, 'lane_numbe'); end
        rtype = getvalue(property, 'road_type');
        paved = getvalue(property, 'paved');
        segs = getsegments(geometry.coordinates);

        % Append each segment as a separate line entry in the output struct array
        for i = 1:numel(segs)
            lines(end + 1) = struct('xy', segs{i}, 'lanes', lanes, 'rtype', rtype, 'paved', paved); %#ok<AGROW>
        end

    end

end

function value = getvalue(p, name)
    %GETVALUE Safely extracts a scalar numeric property from a feature struct.
    %   value = GETVALUE(p, name) retrieves field 'name' from struct p and converts it
    %   to a numeric scalar if stored as char/string. Returns NaN if the field
    %   is missing, empty, non-scalar, or cannot be converted to a number.
    value = NaN;

    if isfield(p, name) && ~isempty(p.(name))
        x = p.(name);
        if ischar(x) || isstring(x), x = str2double(x); end
        if isnumeric(x) && isscalar(x), value = x; end
    end

end

function segments = getsegments(c)
    %GETSEGMENTS Recursively splits GeoJSON coordinates into 2D line matrices.
    %   segments = GETSEGMENTS(c) parses decoded GeoJSON coordinate arrays (cell arrays,
    %   3D arrays [nLines x nPoints x nCoord], or 2D matrices [nPoints x nCoord])
    %   and returns a cell array of Mx2 matrices containing [X, Y] coordinates.
    %
    %   Input:
    %       c - Decoded GeoJSON coordinates (cell array, 3D array, or 2D matrix).
    %
    %   Output:
    %       segments - Cell array of Mx2 double matrices, each representing a
    %                  continuous line segment.

    segments = {};

    % If the coordinates are in a cell array, recursively process each cell
    if iscell(c)
        for i = 1:numel(c), segments = [segments, getsegments(c{i})]; end %#ok<AGROW>
        % If the coordinates are in a numeric array, handle 3D and 2D cases
    elseif isnumeric(c)

        if ndims(c) == 3 % 3D array: [nLines x nPoints x nCoord]
            % For each line in the 3D array, reshape and store as a 2D matrix
            for i = 1:size(c, 1)
                segments{end + 1} = reshape(c(i, :, 1:2), [], 2); %#ok<AGROW>
            end

        elseif ismatrix(c) && size(c, 2) >= 2 && size(c, 1) >= 2 % 2D matrix: [nPoints x nCoord]
            % Directly store the 2D matrix as a segment
            segments{1} = c(:, 1:2);
        end

    end

end
