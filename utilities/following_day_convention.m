function dates = following_day_convention(t0, d, m, y, n, modified)
% Creates a vector of n dates added to an initial date, considering the
% following or modified following convention.
%
% INPUTS:
%   t0          - initial date
%   d           - days to add
%   m           - months to add
%   y           - years to add
%   n           - number of recurrent dates
%   modified    - bool = true if modified following convention
%                 bool = false if following convention
%
% OUTPUTS:
%   dates       - vector of dates with selected convention

if modified
    rule = "modifiedfollow";
else
    rule = "follow";
end


if n > 1

    if ~isscalar(d) || ~isscalar(m) || ~isscalar(y)
        error("For n > 1, d, m, y must be scalars.");
    end

    dates = zeros(n,1);

    for i = 1:n

        % Start incrementing by i (days, months, years)
        dates(i) = increment_date(t0, d*i, m*i, y*i);

        % If not a business day: holiday
        if ~isbusday(dates(i))
            % Return follow or modified follow date
            dates(i) = busdate(dates(i), rule);
        end

    end


else    

    d = d(:);
    m = m(:);
    y = y(:);

    nVec = max([numel(d), numel(m), numel(y)]);

    % expand scalars if needed
    if numel(d) == 1, d = repmat(d, nVec, 1); end
    if numel(m) == 1, m = repmat(m, nVec, 1); end
    if numel(y) == 1, y = repmat(y, nVec, 1); end

    dates = zeros(nVec,1);

    for i = 1:nVec
        % Start incrementing by i (days, months, years)
        dates(i) = increment_date(t0, d(i), m(i), y(i));

        % If not a business day: holiday
        if ~isbusday(dates(i))
            % Return follow or modified follow date
            dates(i) = busdate(dates(i), rule);
        end

    end

end

end