function swapMarketData = precompute_swap_market_data(settlement, scheduleSwap, estrCurve, euriborCurve)
    
% Ensure swap dates are in datenum format
startDates = scheduleSwap.accrualStart;
endDates   = scheduleSwap.accrualEnd;
payDates   = scheduleSwap.payDates;
deltas     = scheduleSwap.delta;

% Store the exact payment dates in the output struct
swapMarketData.payDates = payDates;

% Pre-calculate OIS discounts on the EXACT payment dates
swapMarketData.B_ois = get_discount_factor_by_zero_rates_linear_interp(...
    settlement, payDates, estrCurve.dates, estrCurve.discounts);
    
% Pre-calculate Euribor pseudo-discounts on the FIXING DATES
P_euri_start = get_discount_factor_by_zero_rates_linear_interp(...
    settlement, startDates, euriborCurve.dates, euriborCurve.discounts);
    
P_euri_end = get_discount_factor_by_zero_rates_linear_interp(...
    settlement, endDates, euriborCurve.dates, euriborCurve.discounts);
    
%  Calculate exact Forward Rates using the Fixing-shifted pseudo-discounts
swapMarketData.F_forward = (1 ./ deltas) .* (P_euri_start ./ P_euri_end - 1);
    
end