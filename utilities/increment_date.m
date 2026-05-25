function date_num = increment_date(t0, d, m, y)
% INCREMENT_DATE Increments or decrements a date by a specified 
% number of days, months, and years.
%
% INPUTS:
%   t0  - Initial date (can be a datenum or a datetime object)
%   d   - Number of days to add (or subtract)
%   m   - Number of months to add (or subtract)
%   y   - Number of years to add (or subtract)
%
% OUTPUTS:
%   date_num - The final date expressed as a datenum (numeric serial date)

    % Convert t0 to a datetime object
    if isnumeric(t0)
        dt = datetime(t0, 'ConvertFrom', 'datenum');
    else
        dt = t0;
    end

    % Add day, months, years according to the calendar
    dt = dt + calyears(y) + calmonths(m);
    dt = dt + days(d);

    % Convert back to datenum
    date_num = datenum(dt);
end