function m = centerline_metrics(pred, cl, valid, tolerance, minBranch)
    %CENTERLINE_METRICS Calculate centerline metrics for road extraction.
    %   m = CENTERLINE_METRICS(pred, cl, valid, tolerance) calculates the
    %   completeness, correctness, and quality metrics for road centerline
    %   extraction based on the predicted binary mask, ground truth centerline mask,
    %   validity mask, and tolerance in pixels.
    %
    %   Input:
    %       pred      - Predicted binary mask (logical or double).
    %       cl        - Ground truth centerline binary mask (logical or double).
    %       valid     - Validity mask (logical or double).
    %       tolerance - Tolerance in pixels for matching predicted centerlines to ground truth.
    %       minBranch - Minimum length of predicted centerline branches to consider (optional, default: 0).
    %
    %   Output:
    %       m - Struct containing the calculated metrics:
    %           completeness : Completeness metric (fraction of ground truth centerline pixels matched).
    %           correctness  : Correctness metric (fraction of predicted centerline pixels matched).
    %           quality      : Quality metric (harmonic mean of completeness and correctness).

    if nargin < 5, minBranch = 0; end % Set default minimum branch length to 0 if not provided

    m.completeness = 0; % Initialize completeness metric to zero
    m.correctness = 0; % Initialize correctness metric to zero
    m.quality = 0; % Initialize quality metric to zero

    % Return NaN metrics or 0 if there are no ground truth or no predicted centerline pixels
    if ~any(cl(:)), m.completeness = NaN; m.correctness = NaN; m.quality = NaN; return; end

    skeleton = bwskel(pred & valid, 'MinBranchLength', minBranch); % Skeletonize the predicted mask within the valid region to obtain the predicted centerline

    % Return 0 metrics if there are no predicted centerline pixels after skeletonization
    if ~any(skeleton(:)), return; end

    % Compute distance transforms for the predicted skeleton and ground truth centerline
    distancePrediction = bwdist(skeleton); % Compute the distance transform of the predicted skeleton to find the distance to the nearest predicted centerline pixel for each pixel in the image
    distanceGroundTruth = bwdist(cl); % Compute the distance transform of the ground truth centerline to find the distance to the nearest ground truth centerline pixel for each pixel in the image

    % Calculate completeness and correctness metrics based on the distance transforms and the specified tolerance
    completeness = nnz(cl & (distancePrediction <= tolerance)) / nnz(cl);
    correctness = nnz(skeleton & (distanceGroundTruth <= tolerance)) / nnz(skeleton);

    m.completeness = completeness; % Store the completeness metric in the output struct
    m.correctness = correctness; % Store the correctness metric in the output struct
    m.quality = completeness * correctness / max(completeness + correctness - completeness * correctness, eps); % Calculate the quality metric as the harmonic mean of completeness and correctness, avoiding division by zero
end
