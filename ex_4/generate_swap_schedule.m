function scheduleSwap = generate_swap_schedule(settlement, original_start_date, ...
    maturity_date_unadj, notional_amortized)
% GENERATE_SWAP_SCHEDULE Generates the payment and fixing schedule, the year 
% fractions between payment dates and fixing dates and notionals for an IRS.
%
% INPUTS:
%   settlement          : [Scalar] Settlement date (datenum).
%   original_start_date : [Scalar] Original inception date of the swap (datenum).
%   maturity_date_unadj : [Scalar] Unadjusted maturity date of the swap (datenum).
%   notional_amortized  : [Vector] Amortizing notional profile of the swap.
%
% OUTPUTS:
%   scheduleSwap        : [Struct] Swap schedule container with active periods:
%                           - .accrualStart : Period start dates (datenum)
%                           - .accrualEnd   : Period end dates (datenum)
%                           - .payDates     : Coupon payment dates (datenum)
%                           - .fixingStart  : Euribor fixing start dates (2 BD backward)
%                           - .fixingEnd    : Euribor fixing end dates (2 BD backward)
%                           - .notionals    : Active outstanding amortizing notionals
%                           - .yf_float     : Year fractions between fixing dates (ACT/360)
%                           - .yf_pay       : Year fractions for payment periods (ACT/360)
    
    % 1. ENSURE INPUTS ARE NUMERIC DATENUMS
    
    if isdatetime(settlement)
        settlement = datenum(settlement); 
    end
    if isdatetime(original_start_date)
        original_start_date = datenum(original_start_date); 
    end
    if isdatetime(maturity_date_unadj)
        maturity_date_unadj = datenum(maturity_date_unadj); 
    end

    % 2. THEORETICAL DATES GENERATION

    % Compute maximum number of periods
    max_periods = length(notional_amortized);
    
    % Convert maturity to datetime
    mat_dt = datetime(maturity_date_unadj, 'ConvertFrom', 'datenum');
    
    % Roll backwards from maturity in 3-month steps to get theoretical dates
    all_unadj_dates_dt = mat_dt - calmonths(0:3:(3 * max_periods));
    
    % Sort unadjusted theoretical dates chronologically into datenum array
    all_unadj_dates = sort(datenum(all_unadj_dates_dt))';
    
    % Force the first date to be exactly the inception date to avoid calendar drift
    all_unadj_dates(1) = original_start_date;
    
    % Compute total number of generated unadjusted schedule dates
    num_all_dates = length(all_unadj_dates);
    
    % Pre-allocate column vector for business-day adjusted dates
    all_adj_dates = zeros(num_all_dates, 1);

   % 3. BUSINESS DAY CONVENTION ADJUSTMENT
   for i = 1:num_all_dates
        % Apply Modified Following business day convention
        all_adj_dates(i) = following_day_convention(all_unadj_dates(i), 0, 0, 0, 1, true);
    end
    
    % 4. INTERNAL SCHEDULE ARRAYS

    % Period start dates are all adjusted dates except the very last one
    accrual_start_all = all_adj_dates(1:end-1);
    
    % Period end dates are all adjusted dates except the very first one
    accrual_end_all   = all_adj_dates(2:end);
    
    % Payment dates match the period end dates
    pay_dates_all     = all_adj_dates(2:end);
    
    % 5. FILTERING ACTIVE FLOWS
    % Find indices of active cash flows whose payment date is after settlement
    future_idx = find(pay_dates_all > settlement);
         
    % 6. POPULATE OUTPUT STRUCT
    
    scheduleSwap.accrualStart = accrual_start_all(future_idx);
    scheduleSwap.accrualEnd   = accrual_end_all(future_idx);
    scheduleSwap.payDates     = pay_dates_all(future_idx);
    scheduleSwap.notionals    = notional_amortized(future_idx);
    
    % 7. FIXING DATES COMPUTATION

    % Compute fixing start dates by shifting active accrual starts 2 business days backward
    scheduleSwap.fixingStart  = shift_2bd_backward(scheduleSwap.accrualStart);
        
    % Compute fixing end dates by shifting active accrual ends 2 business days backward
    scheduleSwap.fixingEnd    = shift_2bd_backward(scheduleSwap.accrualEnd);
    
    % 8. YEAR FRACTIONS COMPUTATION

    % ACT/360 year fractions between fixing dates for Euribor forward rates
    scheduleSwap.yf_float = yearfrac(scheduleSwap.fixingStart, scheduleSwap.fixingEnd, 2);
    
    % ACT/360 year fractions between accrual starts and payment dates for coupons
    scheduleSwap.yf_pay = yearfrac(scheduleSwap.accrualStart, scheduleSwap.payDates, 2);
end