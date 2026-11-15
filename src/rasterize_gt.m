function [gt, cl] = rasterize_gt(lines, R, imgSize, opts)
    % gt : maschera strada (logical) con larghezza proporzionale alle corsie
    % cl : centerline sottile (logical)
    % opts.laneWidthM (def 3.0) larghezza di una corsia in metri
    % opts.defaultLanes (def 2) usato se lane_number manca o e' 0
    if nargin < 4, opts = struct; end
    laneW = 3.0; if isfield(opts, 'laneWidthM'), laneW = opts.laneWidthM; end
    defL = 2; if isfield(opts, 'defaultLanes'), defL = opts.defaultLanes; end

    nR = imgSize(1); nC = imgSize(2);
    latMax = R.LatitudeLimits(2); lonMin = R.LongitudeLimits(1);
    dLat = R.CellExtentInLatitude; dLon = R.CellExtentInLongitude;

    % dimensione media del pixel in metri (approssimazione: i pixel non sono quadrati)
    latMid = mean(R.LatitudeLimits);
    mLat = dLat * 111320; mLon = dLon * 111320 * cosd(latMid);
    pxM = sqrt(mLat * mLon);

    cl = false(nR, nC);
    gt = false(nR, nC);
    if isempty(lines), return; end

    lanes = [lines.lanes];
    lanes(isnan(lanes) | lanes < 1) = defL;
    groups = unique(lanes);

    for gi = groups
        mk = false(nR, nC);

        for li = find(lanes == gi)
            xy = lines(li).xy;
            row = (latMax - xy(:, 2)) / dLat + 0.5; % lat -> riga
            col = (xy(:, 1) - lonMin) / dLon + 0.5; % lon -> colonna

            for s = 1:numel(row) - 1
                n = ceil(max(abs(row(s + 1) - row(s)), abs(col(s + 1) - col(s)))) * 2 + 1;
                rr = round(linspace(row(s), row(s + 1), n));
                cc = round(linspace(col(s), col(s + 1), n));
                ok = rr >= 1 & rr <= nR & cc >= 1 & cc <= nC;
                mk(sub2ind([nR nC], rr(ok), cc(ok))) = true;
            end

        end

        cl = cl | mk;
        radiusPx = max(1.5, gi * laneW / 2 / pxM);
        gt = gt | (bwdist(mk) <= radiusPx);
    end

end
