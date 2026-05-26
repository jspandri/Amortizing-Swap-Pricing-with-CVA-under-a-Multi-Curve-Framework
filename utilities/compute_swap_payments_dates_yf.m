function [paymentDates, yf, fixing_start, fixing_end] = compute_swap_payments_dates_yf(...
    reference_date, maturity_date_unadj)
% COMPUTE_SWAP_PAYMENTS_DATES_YF Generates the fixing and adjusted payment 
% schedule and year fractions.
%
% This function calculates the payment dates for a swap by rolling backwards
% from the maturity date in 3-month (quarterly) intervals. It filters out
% dates prior to or equal to the reference date, sorts them chronologically,
% and applies a business day adjustment (Modified Following). Finally, it
% computes the year fractions (ACT/360) between consecutive payment periods 
% and fixing start and end dates.
%
% INPUTS:
%   reference_date       : [Scalar] Valuation/Reference date (datenum or datetime).
%   maturity_date_unadj  : [Scalar] Final maturity date of the swap (datenum or datetime).
%
% OUTPUTS:
%   paymentDates   : [Column Vector] Business-day adjusted payment dates (datenum).
%   yf             : [Column Vector] Year fractions between payment dates (ACT/360).
%   fixing_start   : [Column Vector] Fixing start dates (2 BD before accrual start).
%   fixing_end     : [Column Vector] Fixing end dates (2 BD before payment date).

    % 1. TYPE CONVERSION & PREPARATION
    
    % Ensure inputs are handled as datetime objects for calendar compatibility
    if ~isdatetime(reference_date)
        reference_date = datetime(reference_date, 'ConvertFrom', 'datenum');
    end
    if ~isdatetime(maturity_date_unadj)
        maturity_date_unadj = datetime(maturity_date_unadj, 'ConvertFrom', 'datenum');
    end
    
    % 2. GENERATE UNADJUSTED SCHEDULE
    
    % Determine total quarters between start and maturity to define the scope of the schedule
    max_periods = ceil(years(maturity_date_unadj - reference_date) * 4); 
    
    % Generate potential payment dates by rolling backwards from maturity in 3-month steps
    potential_payment_dates = maturity_date_unadj - calmonths(0:3:(3 * max_periods));
    
    % Filter to exclude dates before or equal to the reference date and sort chronologically
    unadj_dates = sort(potential_payment_dates(potential_payment_dates > reference_date));
    num_dates = length(unadj_dates);
    
    % 3. BUSINESS DAY ADJUSTMENT
    
    % Apply the 'Modified Following' business day convention to each unadjusted date
    paymentDates = zeros(num_dates, 1);
    for i = 1:num_dates
        paymentDates(i) = following_day_convention(unadj_dates(i), 0, 0, 0, 1, true);
    end
    
    % 4. YEAR FRACTIONS & FIXING DATES
    
    % Define the start date for each accrual period: 
    % The first period starts at reference_date; subsequent periods start at the previous payment date
    accrual_start_dates = [datenum(reference_date); paymentDates(1:end-1)];
    
    % Compute year fractions using the ACT/360 day count convention (mode 2)
    yf = yearfrac(accrual_start_dates, paymentDates, 2); 
    
    % Compute fixing dates: 
    % Fixing start/end are defined as 2 Business Days (BD) before the accrual 
    % start and payment date, respectively
    fixing_start = shift_2bd_backward(accrual_start_dates);
    fixing_end   = shift_2bd_backward(paymentDates);
end