function swapMarketData = precompute_swap_market_data(settlement, scheduleSwap, estCurv, euliborCurv)
    
    % Ensure swap dates are in datenum format
    startDates = datenum(scheduleSwap.accrualStart);
    endDates   = datenum(scheduleSwap.accrualEnd);
    payDates   = datenum(scheduleSwap.payDates);
    deltas     = scheduleSwap.delta;
    
    % Store the exact payment dates in the output struct
    swapMarketData.payDates = payDates;
    
    % --- EURIBOR FIXING DATES (2 BUSINESS DAYS PRIOR) ---
    fixing_start = shift_2bd_backward(startDates);
    fixing_end   = shift_2bd_backward(endDates);
    
    % Pre-calculate OIS discounts on the EXACT payment dates
    swapMarketData.B_ois = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, payDates, estCurv.dates, estCurv.discounts);
        
    % Pre-calculate Euribor pseudo-discounts on the FIXING DATES
    P_euri_start = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, fixing_start, euliborCurv.dates, euliborCurv.discounts);
        
    P_euri_end = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, fixing_end, euliborCurv.dates, euliborCurv.discounts);
        
    %  Calculate exact Forward Rates using the Fixing-shifted pseudo-discounts
    swapMarketData.F_forward = (1 ./ deltas) .* (P_euri_start ./ P_euri_end - 1);
    
end