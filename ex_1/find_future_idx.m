function idx = find_future_idx(settlement, futures_starts, starting_month)
% Finds the index of a future with starting date in the requested
% starting_month and same starting year of the settlement date.
%
% INPUTS:
%   settlement          - settlement date.
%   futures_starts      - vector of futures starting dates.
%   starting_month      - (1-12) scalar: starting month of requested
%                         future.
%
% OUTPUTS:
%   idx                 - index of requested future.

% Extract settlement month and year
[settle_year, settle_month, ~] = datevec(settlement);
% Compute the future start date in settlement month
settle_month_third_wed = thirdwednesday(settle_month, settle_year);

% Evaluate if that future is still tradable
if settlement <= (settle_month_third_wed - 2) % Still tradable
    months_increment = starting_month - 1;
else % Not tradable anymore, next future is in the next month
    months_increment = starting_month;
end    

% Compute requested month
date_target_month = increment_date(settlement, 0, months_increment, 0);
[target_year, target_month, ~] = datevec(date_target_month);
% Compute future start date in requested month
target_start = thirdwednesday(target_month, target_year);

% Find corresponding future
idx = find(futures_starts == target_start, 1);

% Check if exists and eventually raise an error
if isempty(idx)
    error("No future found with requested starting date.");
end

end