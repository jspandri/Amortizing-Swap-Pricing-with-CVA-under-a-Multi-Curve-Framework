function df_interp = get_discount_factor_by_zero_rates_linear_interp(reference_date, interp_date, dates, discount_factors, allow_extrap)
% Given a vector of discount factors, return the discount factors at given 
% dates by linear interpolation.
%
% INPUTS:
%   reference_date      - settlement date
%   interp_date         - scalar or vector of interpolation dates (dates at 
%                         which we extract DF)
%   dates               - available DF dates
%   discount_factors    - discount factors at corresponding dates
%   allow_extrap        - (optional) bool: if true allows extrapolation.        
%                                          Default: false.
%
% OUTPUTS:
%   df_interp   - interpolated discount factors at interp_date


if nargin < 5 || isempty(allow_extrap)
    allow_extrap = false;
end

% INPUT VALIDATION

if ~(isnumeric(reference_date) || isdatetime(reference_date)) || ...
   ~(isnumeric(interp_date) || isdatetime(interp_date)) || ...
   ~(isnumeric(dates) || isdatetime(dates))
    error('All date inputs (reference_date, interp_date, dates) must be numeric datenums or datetime arrays.');
end

if ~isnumeric(discount_factors)
    error('Input discount_factors must be a numeric array.');
end

if ~allow_extrap && any(interp_date > max(dates) + 1)
    error('Trying to extrapolate but it is forbidden.')
end    


%%

dates = dates(:);
discount_factors = discount_factors(:);
interp_date = interp_date(:);

% Input validation
if numel(dates) ~= numel(discount_factors)
    error('Dates and discount factors must have same size');
end    

% Compute relevant year fractions (ACT/365) for available set of dates
times = yearfrac(reference_date, dates, 3);
t_target = yearfrac(reference_date, interp_date, 3);

% Convert known discounts into zero rates
zero_rates = from_discount_factors_to_zero_rates(reference_date, times, discount_factors);

% Linearly interpolate the zero rate at the target time
r_interp = interp1(times, zero_rates, t_target, 'linear', 'extrap');

% Convert the interpolated zero rate back to a discount factor
df_interp = exp(-r_interp .* t_target);

end   