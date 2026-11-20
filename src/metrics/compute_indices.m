function [S, names] = compute_indices(A)
    %COMPUTE_INDICES Computes spectral and radiometric indices.
    %   [S, names] = COMPUTE_INDICES(A) calculates five spectral indices tailored
    %   for road extraction and land-cover separation from an 8-band WorldView-3
    %   multispectral image or pixel matrix.
    %
    %   Input:
    %       A     - Multispectral image array of size [H x W x 8] or a 2D pixel
    %               matrix of size [N x 8] (numeric, ordered as WV-3 bands:
    %               Coastal, Blue, Green, Yellow, Red, RedEdge, NIR1, NIR2).
    %
    %   Output:
    %       S     - Double array of computed indices with size [H x W x 5] (or
    %               [N x 5] if input A is 2D), ordered according to 'names':
    %                 1. NDVI       : Normalized Difference Vegetation Index
    %                                 (NIR1 - Red) / (NIR1 + Red)
    %                 2. NDWI       : Normalized Difference Water Index
    %                                 (Green - NIR1) / (Green + NIR1)
    %                 3. REI        : Road Extraction Index (Shahi et al.)
    %                                 ((NIR2 - Blue) / (NIR2 + Blue)) .* NIR2
    %                 4. BAI        : Built-up Area Index (Mhangara et al.)
    %                                 (Blue - NIR1) / (Blue + NIR1)
    %                 5. Brightness : Mean reflectance across all 8 bands
    %       names - 1x5 cell array of char vectors containing the index names:
    %               {'NDVI', 'NDWI', 'REI', 'BAI', 'Brightness'}.

    % Reshape the input to a 2D matrix of size [N x 8] for easier computation
    originalSize = size(A);
    A2 = reshape(A, [], 8);

    % Extract the relevant bands for index calculations
    B = A2(:, 2); % Blue
    G = A2(:, 3); % Green
    R = A2(:, 5); % Red
    N1 = A2(:, 7); % NIR1
    N2 = A2(:, 8); % NIR2

    % Define the normalized difference function
    normalizedDifference = @(x, y) (x - y) ./ (x + y + eps);

    % Compute the indices and store them in the output array S
    names = {'NDVI', 'NDWI', 'REI', 'BAI', 'Brightness'};
    S = [normalizedDifference(N1, R), ... % vegetation
             normalizedDifference(G, N1), ... % water
             normalizedDifference(N2, B) .* N2, ... % REI (Shahi et al.), adapted to WV-3
             normalizedDifference(B, N1), ... % BAI (Mhangara et al.)
             mean(A2, 2)]; % brightness

    % Reshape the output to match the original input dimensions, preserving the last dimension for indices
    S = reshape(S, [originalSize(1:end - 1), numel(names)]);
end
