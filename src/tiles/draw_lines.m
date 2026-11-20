function bw = draw_lines(L, size)
    %DRAW_LINES Draw lines on a binary image.
    %   bw = DRAW_LINES(L, size) draws lines on a binary image of size
    %   'size' based on the line segments specified in the structure array L.
    %   Each element of L should have fields 'point1' and 'point2',
    %   which are 1x2 vectors representing the coordinates of the endpoints of the line segment.
    %   The output 'bw' is a binary image where the pixels corresponding to the lines
    %   are set to true (1) and all other pixels are set to false (0).
    %
    %   Input:
    %       L    - A structure array where each element represents a line segment with fields:
    %                point1 : A 1x2 vector [x1, y1] representing the coordinates of the first endpoint of the line segment.
    %                point2 : A 1x2 vector [x2, y2] representing the coordinates of the second endpoint of the line segment.
    %       size - A 1x2 vector [height, width] specifying the size of the output binary image.
    %
    %   Output:
    %       bw - A binary image of size 'size' with the lines drawn on it

    bw = false(size); % Initialize the binary image with all pixels set to false (0)

    % Iterate through each line segment in the structure array L and draw the corresponding line on the binary image
    for i = 1:numel(L)
        p1 = L(i).point1; % Get the coordinates of the first endpoint of the line segment
        p2 = L(i).point2; % Get the coordinates of the second endpoint of the line segment
        n = ceil(max(abs(p2 - p1))) * 2 + 1; % Compute the number of points to sample along the line segment based on its length
        x = round(linspace(p1(1), p2(1), n)); % Generate x-coordinates of the points along the line segment
        y = round(linspace(p1(2), p2(2), n)); % Generate y-coordinates of the points along the line segment
        bw(sub2ind(size, y, x)) = true; % Set the pixels corresponding to the line segment to true (1) in the binary image
    end

end
