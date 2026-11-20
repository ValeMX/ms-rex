function c = config()
    %CONFIG Returns project configuration parameters and dataset directory paths.
    %   c = CONFIG() returns a struct containing hardcoded paths and processing
    %   thresholds for the SpaceNet 3 (AOI_3_Paris) road extraction pipeline.
    %
    %   Output:
    %       c - Struct with the following fields:
    %             root             : Root directory of the SpaceNet 3 Paris dataset
    %                                (char vector).
    %             dataDirectory    : Directory containing the dataset (char vector).
    %             resultsDirectory : Directory containing the results (char vector).
    %             msDirectory      : Directory containing pan-sharpened multispectral
    %                                TIFF tiles ('PS-MS') (char vector).
    %             geojsonDirectory : Directory containing GeoJSON road annotations
    %                                ('geojson_roads') (char vector).
    %             laneWidth        : Default width of a single road lane in meters
    %                                used for ground truth generation (double, default: 3.0).
    %             minValidPixels   : Minimum percentage of valid (non-zero) pixels
    %                                required to include a tile (double, default: 95).
    %             tolerance        : Tolerance in pixels for road centerline
    %                                detection when generating ground truth masks (double, default: 3).

    c.root = 'C:\Users\valer\Desktop\Università\Image Processing\ms-rex';
    c.dataDirectory = fullfile(c.root, 'data');
    c.resultsDirectory = fullfile(c.root, 'results');
    c.msDirectory = fullfile(c.dataDirectory, 'PS-MS');
    c.geojsonDirectory = fullfile(c.dataDirectory, 'geojson_roads');
    c.laneWidth = 3.0;
    c.minValidPixels = 95;
    c.tolerance = 3;
end
