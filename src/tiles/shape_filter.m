function out = shape_filter(labels, stats, p)
    %SHAPE_FILTER Filter connected components based on shape metrics.
    %   out = shape_filter(labels, stats, p) filters the connected components in
    %   the labeled image 'labels' based on the shape metrics in the struct 'stats'
    %   and the parameters specified in the struct 'p'. The output 'out' is
    %   a binary mask indicating which connected components to keep.
    %
    %   Input:
    %       labels - Labeled image of connected components (2D array).
    %       stats  - Struct containing statistics of the connected components:
    %                  stats.n      : Number of connected components.
    %                  stats.A      : Area of each connected component (number of pixels).
    %                  stats.L      : Length of each connected component's centerline (number of pixels).
    %                  stats.wMean  : Mean width of each connected component (in pixels).
    %                  stats.cv     : Coefficient of variation of the width for each connected component.
    %       p      - Struct containing parameters for filtering:
    %                  p.minLen   : Minimum length of connected components to keep.
    %                  p.wMin     : Minimum mean width of connected components to keep.
    %                  p.wMax     : Maximum mean width of connected components to keep.
    %                  p.cvMax    : Maximum coefficient of variation of width to keep.
    %                  p.minElong : Minimum elongation (length/width) of connected components to keep.
    %
    %   Output:
    %       out - Binary mask indicating which connected components to keep (2D logical array).

    % Compute a logical array indicating which connected components meet the specified criteria
    keep = stats.L >= p.minLen & ...
        stats.wMean >= p.wMin & ...
        stats.wMean <= p.wMax & ...
        stats.cv <= p.cvMax & ...
        (stats.L ./ max(stats.wMean, 1)) >= p.minElong;
    
    k = [false; keep(:)]; % Create a logical array where the first element corresponds to the background (label 0) and is set to false, and the rest correspond to the connected components

    out = k(double(labels) + 1); % Create the output binary mask by indexing into the logical array 'k' using the labeled image 'labels'. The '+1' is used to account for the background label (0) in 'labels', which corresponds to the first element in 'k'.
end
