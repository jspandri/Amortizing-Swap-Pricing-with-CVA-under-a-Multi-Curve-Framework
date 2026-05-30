function scheduleSwap = generate_swap_schedule_22(settlement, ammortizingData, estrCurve, euriborCurve)
% GENERATE_SWAP_SCHEDULE_22 Precomputes swap market data and builds the swap schedule.
%
% SYNTAX:
%   scheduleSwap = generate_swap_schedule_22(settlement, ammortizingData, estrCurve, euriborCurve)
%
% INPUTS:
%   settlement      - Settlement date (datenum or string)
%   ammortizingData - Struct containing input schedule data (accrualStart, accrualEnd, payDates, delta, notionals)
%   estrCurve       - Struct containing €STR curve data (dates, discounts)
%   euriborCurve    - Struct containing Euribor curve data (dates, discounts)
%
% OUTPUTS:
%   scheduleSwap    - Struct containing the completed swap schedule, forward rates, and OIS discounts
    
% Extract schedule dates, deltas, and notionals from ammortizingData
startDates = ammortizingData.accrualStart;
endDates   = ammortizingData.accrualEnd;
payDates   = ammortizingData.payDates;
deltas     = ammortizingData.delta;
notionals  = ammortizingData.notionals; % Extracted separately as requested

% Store the extracted schedule data in the output scheduleSwap struct
scheduleSwap.accrualStart = startDates;
scheduleSwap.accrualEnd   = endDates;
scheduleSwap.payDates     = payDates;
scheduleSwap.notionals    = notionals;
scheduleSwap.yf_pay      = deltas;
    
% Pre-calculate Euribor pseudo-discounts on the fixing dates
P_euri_start = get_discount_factor_by_zero_rates_linear_interp(...
    settlement, startDates, euriborCurve.dates, euriborCurve.discounts);
    
P_euri_end = get_discount_factor_by_zero_rates_linear_interp(...
    settlement, endDates, euriborCurve.dates, euriborCurve.discounts);
    
% Calculate exact Forward Rates using the fixing-shifted pseudo-discounts
scheduleSwap.F_forward = (1 ./ deltas) .* (P_euri_start ./ P_euri_end - 1);

% Pre-calculate OIS discounts on the exact payment dates
scheduleSwap.B_ois = get_discount_factor_by_zero_rates_linear_interp(...
    settlement, payDates, estrCurve.dates, estrCurve.discounts);
    
end