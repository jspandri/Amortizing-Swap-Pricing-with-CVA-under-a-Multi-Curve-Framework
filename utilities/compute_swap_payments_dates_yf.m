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
    if isdatetime(reference_date)
        reference_date = datenum(reference_date);
    end
    if isdatetime(maturity_date_unadj)
        maturity_date_unadj = datenum(maturity_date_unadj);
    end

    % We calculate the maximum number of 3-month periods (quarterly) between dates
    max_periods = ceil(years(maturity_date_unadj - reference_date) * 4); 

    % Generate the vector of month offsets (rolling backwards by 3 months)
    m_offsets = -3 * (0:max_periods)';
    
    % Replicate the scalar maturity_date to match the dimension of offsets
    mat_dates_vec = repmat(maturity_date_unadj, length(m_offsets), 1);

    % Compute unadjusted dates by shifting the maturity dates backward
    % using the month offsets array.
    unadj_dates = increment_date(mat_dates_vec, 0, m_offsets, 0);

    % Retain only dates that are strictly in the future relative to the reference date.
    unadj_dates = unadj_dates(unadj_dates > reference_date);
    
    % Sort chronologically (from earliest future payment to maturity).
    unadj_dates = sort(unadj_dates);

    % Apply business day adjustment using modified_following' rule.
    paymentDates = following_day_convention(unadj_dates, 0, 0, 0, 1, true);

    % We compute ACT/360 year fractions
    % The start dates for each period are: reference_date (for the 1st) and 
    % the previous adjusted payment dates for the subsequent ones
    start_dates = [reference_date; paymentDates(1:end-1)];
    end_dates = paymentDates;
    yf = yearfrac(start_dates, end_dates, 2); 

end

 