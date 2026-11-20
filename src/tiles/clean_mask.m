function out = clean_mask(pred, valid, p)
    %CLEAN_MASK Clean a binary mask using morphological operations.
    %   out = CLEAN_MASK(pred, valid, p) cleans the binary mask 'pred'
    %   using morphological operations based on the parameters specified in
    %   the struct 'p'. The 'valid' mask is used to restrict the operations
    %   to valid regions. The output 'out' is the cleaned binary mask.
    %
    %   Input:
    %       pred  - Binary mask to be cleaned (2D logical array).
    %       valid - 2D logical mask indicating valid pixels.
    %       p     - Struct containing parameters for morphological operations:
    %                 p.nAngles : Number of angles for structuring elements (default: 8).
    %                 p.minArea : Minimum area of connected components to keep.
    %                 p.radius  : Radius for morphological operations (if > 0).
    %                 p.lClose  : Length of the structuring element for closing (if > 0).
    %                 p.lOpen   : Length of the structuring element for opening (if > 0).
    %
    %   Output:
    %       out - Cleaned binary mask (2D logical array).

    if ~isfield(p, 'nAngles'), p.nAngles = 8; end
    if ~isfield(p, 'radius'), p.radius = 0; end
    if ~isfield(p, 'lClose'), p.lClose = 0; end
    if ~isfield(p, 'lOpen'), p.lOpen = 0; end

    angles = linspace(0, 180, p.nAngles + 1); % Generate angles for structuring elements
    angles(end) = []; % Remove the last angle to avoid duplication of 0 and 180 degrees
    m = bwareaopen(pred & valid, p.minArea); % Remove small connected components based on the minimum area threshold

    % Apply morphological operations based on the specified radius if greater than 0
    if p.radius > 0 
        m = m & ~imopen(m, strel('disk', p.radius)); % Remove small structures using morphological opening with a disk-shaped structuring element of the specified radius
    end

    % Apply morphological closing if specified
    if p.lClose > 0
        accumulator = false(size(m)); % Initialize an accumulator for the closing operation

        % Apply morphological closing for each angle and accumulate the results
        for a = angles
            accumulator = accumulator | imclose(m, strel('line', p.lClose, a));
        end

        % Update the mask with the accumulated closing results, ensuring it remains within valid regions
        m = accumulator & valid;
    end

    % Apply morphological opening if specified
    if p.lOpen > 0
        accumulator = false(size(m)); % Initialize an accumulator for the opening operation

        % Apply morphological opening for each angle and accumulate the results
        for a = angles
            accumulator = accumulator | imopen(m, strel('line', p.lOpen, a));
        end

        % Update the mask with the accumulated opening results
        m = accumulator;
    end

    % Remove small connected components again after morphological operations
    out = bwareaopen(m, p.minArea) & valid;
end
