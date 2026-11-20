function pxM = pixel_size(R)
    %PIXEL_SIZE Calculate the pixel size in meters for a given spatial referencing object.
    %   pxM = PIXEL_SIZE(R) calculates the pixel size in meters for
    %   a spatial referencing object R (map raster reference or geographic raster reference).
    %
    %   Input:
    %       R - Spatial referencing object (map raster reference or geographic raster reference).
    %
    %   Output:
    %       pxM - Pixel size in meters (double).

    latMid = mean(R.LatitudeLimits); % Calculate the midpoint latitude of the raster reference object
    mLat = R.CellExtentInLatitude * 111320; % Convert latitude extent to meters (approximate conversion factor)
    mLon = R.CellExtentInLongitude * 111320 * cosd(latMid); % Convert longitude extent to meters (approximate conversion factor adjusted for latitude)
    pxM = sqrt(mLat * mLon); % Calculate the pixel size in meters as the geometric mean of the latitude and longitude extents
end
