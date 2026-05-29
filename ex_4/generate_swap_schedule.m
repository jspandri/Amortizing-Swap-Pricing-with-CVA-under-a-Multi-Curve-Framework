function scheduleSwap = generate_swap_schedule(settlement, original_start_date, ...
    maturity_date_unadj, notional_amortized,discountCurve, pseudoCurve)
% GENERATE_SWAP_SCHEDULE Generates the payment schedule, the year fractions 
% between payment periods, forward Libor rates, discounts at payments dates
% and notionals for an IRS.
%
% INPUTS:
%   settlement          : [Scalar] Settlement date 
%   original_start_date : [Scalar] Original inception date of the swap (2BD after original trade date)
%   maturity_date_unadj : [Scalar] Unadjusted maturity date of the swap
%   notional_amortized  : [Vector] Amortizing notional profile of the swap
%   discountCurve       : [Struct] ESTR OIS discounting curve data (.dates, .discounts)
%   pseudoCurve         : [Struct] Market Euribor curve (.dates, .discounts)
%
% OUTPUTS:
%   scheduleSwap        : [Struct] Swap schedule container with active periods:
%                           - .accrualStart : Period start dates (datenum)
%                           - .accrualEnd   : Period end dates (datenum)
%                           - .payDates     : Coupon payment dates (datenum)
%                           - .notionals    : Active outstanding amortizing notionals
%                           - .yf_pay       : Year fractions for payment periods (ACT/360)
%                           - .F_forward    : Forward Libor rates
%                           - .B_ois        : discounts at payments dates

    
    % 1. ENSURE INPUTS ARE NUMERIC DATENUMS
    
    if ~isdatetime(settlement)
        settlement = datetime(settlement, 'ConvertFrom', 'datenum');
    end
    if ~isdatetime(original_start_date)
        original_start_date = datetime(original_start_date, 'ConvertFrom', 'datenum'); 
    end
    if ~isdatetime(maturity_date_unadj)
        maturity_date_unadj = datetime(maturity_date_unadj, 'ConvertFrom', 'datenum'); 
    end

    % 2. THEORETICAL DATES GENERATION

    % Compute maximum number of periods
    max_periods = length(notional_amortized);
   
    % Roll backwards from maturity in 3-month steps to get theoretical dates
    all_unadj_dates_dt = maturity_date_unadj - calmonths(0:3:(3 * max_periods));
    
    % Filter dates to keep only those strictly after the original start date and sort them
    all_unadj_dates = sort(all_unadj_dates_dt(all_unadj_dates_dt > original_start_date))';
    
    % Compute total number of generated unadjusted schedule dates
    num_all_dates = length(all_unadj_dates);
    
    % Pre-allocate column vector for business-day adjusted dates that
    % incldes also the original_start_date
    all_adj_dates = zeros(num_all_dates + 1, 1);

   % 3. BUSINESS DAY CONVENTION ADJUSTMENT
   for i = 1:num_all_dates
        % Apply Modified Following business day convention
        all_adj_dates(i + 1) = following_day_convention(all_unadj_dates(i), 0, 0, 0, 1, true);
   end
   all_adj_dates(1) = datenum(original_start_date);
    
    % 4. INTERNAL SCHEDULE ARRAYS

    % Period start dates are all adjusted dates except the very last one
    accrual_start_all = all_adj_dates(1:end-1);
    
    % Period end dates are all adjusted dates except the very first one
    accrual_end_all   = all_adj_dates(2:end);
    
    % Payment dates match the period end dates
    pay_dates_all     = all_adj_dates(2:end);
    
    % 5. FILTERING ACTIVE FLOWS
    % Find indices of active cash flows whose payment date is after settlement
    future_idx = find(pay_dates_all > datenum(settlement));
         
    % 6. POPULATE OUTPUT STRUCT
    
    scheduleSwap.accrualStart = accrual_start_all(future_idx);
    scheduleSwap.accrualEnd   = accrual_end_all(future_idx);
    scheduleSwap.payDates     = pay_dates_all(future_idx);
    scheduleSwap.notionals    = notional_amortized(future_idx);
    
    
    % 7. YEAR FRACTIONS COMPUTATION
   
    % ACT/360 year fractions between accrual starts and payment dates for coupons
    scheduleSwap.yf_pay = yearfrac(scheduleSwap.accrualStart, scheduleSwap.payDates, 2);

    % 8. FORWARD RATES COMPUTATION AND DISCOUNTS AT PAYMENT DATES
    % NOTE: If the first accrual start date is before settlement, we will use  
    % the past fixed 3m euribor, so there's no problem in computing the first F_forward
    % in the following way since it will be overwritten.
    
    % Interpolate pseudo-discounts at accrual start dates
    P_start = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.accrualStart, pseudoCurve.dates, pseudoCurve.discounts);

    % Interpolate pseudo-discounts at period accrual end dates
    P_end   = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.accrualEnd, pseudoCurve.dates, pseudoCurve.discounts);

    % Compute Forward Rates between payments dates
    scheduleSwap.F_forward = (1 ./ scheduleSwap.yf_pay) .* ((P_start ./ P_end) - 1);

    % 9. DISCOUNTS AT PAYMENT DATES

    % Interpolate OIS discount factors on active payment dates
    scheduleSwap.B_ois = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.payDates, discountCurve.dates, discountCurve.discounts);
    
end