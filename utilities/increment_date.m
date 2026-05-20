function date = increment_date(t0, d, m, y)
% Increment (or even decrease) initial date by a number of given days,
% months and years.
%
% INPUTS:
%   t0  - initial date
%   d   - days to add (or subtract)
%   m   - months to add (or subtract)
%   y   - years to add (or subtract)
%
% OUTPUTS:
%   date    - final date

% Extract calendar date
[Y,M,D] = datevec(t0);

% Add day, months, years
date = datenum(Y+y, M+m, D+d);

end