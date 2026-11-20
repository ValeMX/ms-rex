function t = load_tile(id, withGroundTruth)
    %LOAD_TILE Loads a PS-MS tile and its corresponding ground truth (if available).
    %   t = LOAD_TILE(id, withGroundTruth) loads the pan-sharpened multispectral (PS-MS)
    %   tile with the specified ID and its corresponding ground truth (if available).
    %   The function returns a struct containing the tile data, georeferencing
    %   information, and ground truth masks.
    %
    %   Input:
    %       id              - Tile ID (string or char vector) corresponding to the PS-MS
    %                         tile filename (e.g., 'img123').
    %       withGroundTruth - (Optional) Boolean flag indicating whether to load the ground
    %                         truth masks (default: true). If false, only the tile data is loaded.
    %
    %   Output:
    %       t - Struct with the following fields:
    %             id             : Tile ID (char vector).
    %             R              : GeographicCellsReference object for the tile.
    %             A              : 3D array containing the PS-MS tile data (double).
    %             valid          : 2D logical mask indicating valid (non-black) pixels.
    %             gt             : 2D logical mask of the full road surface (if withGroundTruth is true).
    %             cl             : 2D logical mask of the thin road centerlines (if withGroundTruth is true).
    %             hasGroundTruth : Boolean indicating whether ground truth is available.
    %             lines          : Struct array of road segments from the corresponding
    %                              GeoJSON file (if withGroundTruth is true and ground truth is available).

    if nargin < 2, withGroundTruth = true; end
    c = config();
    f = fullfile(c.msDirectory, sprintf('SN3_roads_train_AOI_3_Paris_PS-MS_%s.tif', id));
    [A, R] = readgeoraster(f);
    t.id = char(id);
    t.R = R;
    t.A = double(A);

    v = any(A > 0, 3);
    v = bwareaopen(v, 200); % removes small isolated valid regions
    v = ~bwareaopen(~v, 200); % fills small holes in valid regions
    t.valid = v;

    t.gt = false(size(v));
    t.cl = t.gt;
    t.hasGroundTruth = false;
    t.lines = [];

    if withGroundTruth
        geojsonFile = fullfile(c.geojsonDirectory, sprintf('SN3_roads_train_AOI_3_Paris_geojson_roads_%s.geojson', id));

        if isfile(geojsonFile)
            L = read_geojson(geojsonFile);

            if ~isempty(L)
                [gt, cl] = generate_ground_truth(L, R, size(v), struct('laneWidth', c.laneWidth));
                t.gt = gt & v;
                t.cl = cl & v;
                t.hasGroundTruth = true;
                t.lines = L;
            end

        end

    end

end
