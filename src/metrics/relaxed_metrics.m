function m = relaxed_metrics(pred, gt, valid, rhoPixel)
    %RELAXED_METRICS Calculate relaxed metrics for road extraction.
    %   m = RELAXED_METRICS(pred, gt, valid, rhoPixel) calculates
    %   the relaxed precision, recall, and F1 score metrics for
    %   road extraction based on the predicted binary mask,
    %   ground truth binary mask, validity mask, and a specified tolerance in pixels.
    %
    %   Input:
    %       pred     - Predicted binary mask (logical or double).
    %       gt       - Ground truth binary mask (logical or double).
    %       valid    - Validity mask (logical or double).
    %       rhoPixel - Tolerance in pixels for matching predicted pixels to ground truth.
    %
    %   Output:
    %       m - Struct containing the calculated metrics:
    %             rPrecision : Relaxed precision metric (fraction of predicted pixels matched within tolerance).
    %             rRecall    : Relaxed recall metric (fraction of ground truth pixels matched within
    %                          tolerance).
    %             rF1        : Relaxed F1 score metric (harmonic mean of relaxed precision and recall).

    pred = pred & valid; % Restrict the predicted mask to valid regions
    gt = gt & valid; % Restrict the ground truth mask to valid regions

    distanceGT = bwdist(gt); % Compute the distance transform of the ground truth mask to find the distance to the nearest ground truth pixel for each pixel in the image
    distancePred = bwdist(pred); % Compute the distance transform of the predicted mask to find the distance to the nearest predicted pixel for each pixel in the image

    m.rPrecision = nnz(pred & (distanceGT <= rhoPixel)) / max(nnz(pred), 1); % Calculate relaxed precision as the fraction of predicted pixels that are within the specified tolerance of any ground truth pixel, avoiding division by zero
    m.rRecall = nnz(gt & (distancePred <= rhoPixel)) / max(nnz(gt), 1); % Calculate relaxed recall as the fraction of ground truth pixels that are within the specified tolerance of any predicted pixel, avoiding division by zero
    m.rF1 = 2 * m.rPrecision * m.rRecall / max(m.rPrecision + m.rRecall, eps); % Calculate relaxed F1 score as the harmonic mean of relaxed precision and recall, avoiding division by zero
end
