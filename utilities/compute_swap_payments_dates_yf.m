function [paymentDates, yf] = compute_swap_payments_dates_yf(reference_date, maturity_date_unadj)
% COMPUTE_SWAP_PAYMENTS_DATES_YF Generates the adjusted payment schedule and year fractions.
%
% This function calculates the payment dates for a swap by rolling backwards
% from the maturity date in 3-month (quarterly) intervals. It filters out
% dates prior to or equal to the reference date, sorts them chronologically,
% and applies a business day adjustment (Modified Following). Finally, it
% computes the year fractions (ACT/360) between consecutive payment periods.
%
%
% INPUTS:
%   reference_date       : [Scalar] Valuation/Reference date (datenum or datetime).
%   maturity_date_unadj  : [Scalar] Final maturity date of the swap (datenum or datetime).
%
% OUTPUTS:
%   paymentDates   : [Column Vector] Business-day adjusted payment dates (datenum).
%   yf             : [Column Vector] Year fractions between payment dates (ACT/360).

    % Convert inputs to datetime objects 
    if ~isdatetime(reference_date)
        reference_date = datetime(reference_date, 'ConvertFrom', 'datenum');
    end
    if ~isdatetime(maturity_date_unadj)
        maturity_date_unadj = datetime(maturity_date_unadj, 'ConvertFrom', 'datenum');
    end

   % We calculate the maximum number of 3-month periods (quarterly) between dates
    max_periods = ceil(years(maturity_date_unadj - reference_date) * 4); 

    % We generate all unadjusted potential payment dates going backwards from maturity
    potential_payment_dates = maturity_date_unadj - calmonths(0:3:(3 * max_periods));

    % We filter dates to keep only those strictly after the reference date and sort them
    unadj_dates = sort(potential_payment_dates(potential_payment_dates > reference_date));
    num_dates = length(unadj_dates);

    % We apply business day adjustment
    paymentDates = zeros(num_dates, 1);
    for i = 1:num_dates
        paymentDates(i) = following_day_convention(unadj_dates(i), 0, 0, 0, 1, true);
    end

    % We compute ACT/360 year fractions
    % The start dates for each period are: reference_date (for the 1st) and 
    % the previous adjusted payment dates for the subsequent ones
    start_dates = [datenum(reference_date); paymentDates(1:end-1)];
    end_dates = paymentDates;
    yf = yearfrac(start_dates, end_dates, 2); 

end