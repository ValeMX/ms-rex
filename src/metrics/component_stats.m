function [labels, stats] = component_stats(m, minBranch)
    %COMPONENT_STATS Compute statistics of connected components in a binary mask.
    %   [labels, stats] = component_stats(m, minBranch) computes the connected
    %   components in the binary mask 'm' and returns the labeled image 'labels'
    %   and a struct 'stats' containing statistics of the components. The
    %   'minBranch' parameter specifies the minimum length of branches in the
    %   centerline mask to consider for centerline metrics.
    %
    %   Input:
    %       m         - Binary mask (2D logical array) representing the connected components.
    %       minBranch - Minimum length of branches in the centerline mask to consider for centerline metrics (default: 20).
    %
    %   Output:
    %       labels - Labeled image of connected components (2D array).
    %       stats  - Struct containing statistics of the connected components:
    %                  stats.n      : Number of connected components.
    %                  stats.A      : Area of each connected component (number of pixels).
    %                  stats.L      : Length of each connected component's centerline (number of pixels).
    %                  stats.wMean  : Mean width of each connected component (in pixels).
    %                  stats.cv     : Coefficient of variation of the width for each connected component.

    if nargin < 2, minBranch = 20; end % Set default value for minBranch if not provided

    labels = bwlabel(m, 8); % Label connected components in the binary mask 'm' using 8 - connectivity
    n = max(labels(:)); % Get the number of connected components (maximum label value)
    stats.n = n;

    % If there are no connected components, return empty arrays for the statistics
    if n == 0, stats.A = [];
        stats.L = [];
        stats.wMean = [];
        stats.cv = [];
        return;
    end

    skeleton = bwskel(m, 'MinBranchLength', minBranch); % Compute the skeleton of the binary mask 'm' with a minimum branch length of 'minBranch'
    distance = double(bwdist(~m)); % Compute the distance transform of the binary mask 'm'
    w = 2 * distance(skeleton); % Compute the width of each pixel in the skeleton by multiplying the distance transform values by 2 (to account for both sides of the skeleton)
    skeletonLabels = labels(skeleton); % Label the skeleton pixels to identify which connected component each pixel belongs to
    stats.A = accumarray(labels(m), 1, [n 1]); % Compute the area of each connected component by counting the number of pixels in each label
    stats.L = accumarray(skeletonLabels, 1, [n 1]); % Compute the length of each connected component's centerline by counting the number of pixels in the skeleton for each label
    stats.wMean = accumarray(skeletonLabels, w, [n 1], @mean, 0); % Compute the mean width of each connected component by averaging the width values for each label in the skeleton
    wStd = accumarray(skeletonLabels, w, [n 1], @std, 0); % Compute the standard deviation of the width for each connected component by calculating the standard deviation of the width values for each label in the skeleton
    stats.cv = wStd ./ max(stats.wMean, eps); % Compute the coefficient of variation (CV) of the width for each connected component by dividing the standard deviation by the mean width, ensuring that the mean width is not zero by using 'eps' as a lower bound
end
