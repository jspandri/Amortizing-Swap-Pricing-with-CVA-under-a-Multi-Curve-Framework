function zero_rates = from_discount_factors_to_zero_rates(settlement, dates, discount_factors)
% FROM_DISCOUNT_FACTORS_TO_ZERO_RATES Compute the zero rates from the discount factors.
% Formula: r = -ln(DF) / T  , where DF : disc fact
%
% INPUTS:
%   settlement                 : [Scalar] settlement date.
%   dates                      : [Vector] datenum dates.
%   discount_factors           : [Vector] discount factors of corresponding dates.
%
% OUTPUTS:
%   zero_rates                 : [Vector] zero-rates of corresponding dates.

% INPUT VALIDATION
if ~(isnumeric(dates) || isdatetime(dates))
    error( 'Input dates must be a numeric array (datenum or year fractions) or datetime array.');
end

if ~isnumeric(discount_factors)
    error('Input discount_factors must be a numeric array.');
end

if numel(dates) ~= numel(discount_factors)
    error('Inputs dates and discount_factors must have the same number of elements.');
end

if any(discount_factors <= 0)
    error('All discount factors must be strictly greater than 0 to compute the zero rates.');
end

%%

effDates = dates;

% If the input are datenums, it must be converted to year fractions; if it is 
% already year fractions, nothing to do.
if isdatetime(effDates) || (isnumeric(effDates) && max(effDates) > 1000)

    % Year fraction (ACT/365)
    effDates = yearfrac(settlement, effDates, 3);
end

zero_rates = zeros(length(effDates),1);

% transform into zero-rates while checking divison by zero
for i = 1:length(effDates)
    T = effDates(i);
    
    if T > 0
        zero_rates(i) = -log(discount_factors(i)) / T;
    else
        zero_rates(i) = 0.00;
    end    
end    


end