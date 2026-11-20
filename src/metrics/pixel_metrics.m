function m = pixel_metrics(pred, gt, valid)
    %PIXEL_METRICS Calculate pixel-level metrics for binary segmentation.
    %   m = PIXEL_METRICS(pred, gt, valid) calculates the true positives (TP),
    %   false positives (FP), and false negatives (FN) for a binary segmentation
    %   result, and then computes the precision, recall, F1-score,
    %   and Intersection over Union (IoU).
    %
    %   Input:
    %       pred  - Predicted binary mask (logical or double).
    %       gt    - Ground truth binary mask (logical or double).
    %       valid - Validity mask (logical or double).
    %
    %   Output:
    %       m - Struct containing the calculated metrics:
    %           TP        : Number of true positive pixels.
    %           FP        : Number of false positive pixels.
    %           FN        : Number of false negative pixels.
    %           precision : Precision metric (TP / (TP + FP)).
    %           recall    : Recall metric (TP / (TP + FN)).
    %           F1        : F1-score (2 * TP / (2 * TP + FP + FN)).
    %           IoU       : Intersection over Union (TP / (TP + FP + FN)).

    pred = pred & valid; % Ensure that only valid pixels are considered in the prediction
    gt = gt & valid; % Ensure that only valid pixels are considered in the ground truth
    TP = nnz(pred & gt); % Count the number of true positive pixels (predicted as road and actually road)
    FP = nnz(pred & ~gt); % Count the number of false positive pixels (predicted as road but actually not road)
    FN = nnz(~pred & gt); % Count the number of false negative pixels (predicted as not road but actually road)

    m.TP = TP; % Store the true positive count in the output struct
    m.FP = FP; % Store the false positive count in the output struct
    m.FN = FN; % Store the false negative count in the output struct
    m.precision = TP / max(TP + FP, 1); % Calculate precision (TP / (TP + FP)), avoiding division by zero
    m.recall = TP / max(TP + FN, 1); % Calculate recall (TP / (TP + FN)), avoiding division by zero
    m.F1 = 2 * TP / max(2 * TP + FP + FN, 1); % Calculate F1-score (2 * TP / (2 * TP + FP + FN)), avoiding division by zero
    m.IoU = TP / max(TP + FP + FN, 1); % Calculate Intersection over Union (TP / (TP + FP + FN)), avoiding division by zero
end
