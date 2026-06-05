function activeSchedule = generate_active_swap_schedule(settlement, rawSchedule, estrCurve, euriborCurve)
% GENERATE_ACTIVE_SWAP_SCHEDULE2 Filters a raw swap schedule (e.g., from Excel) 
% based on the current settlement date, and computes forward rates and OIS discounts 
% only for the active, surviving periods.
%
% INPUTS:
%   settlement                 : [Scalar/Datetime] Current valuation date (datenum).
%   rawSchedule                : [Struct] Struct containing the FULL original swap schedule from Excel:
%                                  - .accrualStart : accrual start dates
%                                  - .accrualEnd   : accrual end dates
%                                  - .payDates     : payment dates
%                                  - .delta        : year fractions
%                                  - .notionals    : amortizing notionals
%   estrCurve                  : [Struct] Struct containing €STR curve data (.dates, .discounts).
%   euriborCurve               : [Struct] Struct containing Euribor curve data (.dates, .discounts).
%
% OUTPUTS:
%   activeSchedule             : [Struct] Struct ready for pricing, containing only future cash flows:
%                                  - .accrualStart : accrual start dates
%                                  - .accrualEnd   : accrual end dates
%                                  - .payDates     : payment dates
%                                  - .notionals    : amortizing notionals
%                                  - .yf_pay       : year fractions for payment periods
%                                  - .F_forward    : exact forward rates
%                                  - .B_ois        : OIS discounts
    % IDENTIFY SURVIVING CASH FLOWS
    % Find indices where the payment date has NOT happened yet
    future_idx = find(rawSchedule.payDates > datenum(settlement));
    
    if isempty(future_idx)
        error('The swap has already expired. No active cash flows after settlement.');
    end
    
    % EXTRACT ACTIVE DATA
    activeSchedule.accrualStart = rawSchedule.accrualStart(future_idx);
    activeSchedule.accrualEnd   = rawSchedule.accrualEnd(future_idx);
    activeSchedule.payDates     = rawSchedule.payDates(future_idx);
    activeSchedule.notionals    = rawSchedule.notionals(future_idx);
    activeSchedule.yf_pay       = rawSchedule.delta(future_idx);
    
    % PRE-CALCULATE PSEUDO-DISCOUNTS
    P_start = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, activeSchedule.accrualStart, euriborCurve.dates, euriborCurve.discounts);
        
    P_end = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, activeSchedule.accrualEnd, euriborCurve.dates, euriborCurve.discounts);
        
    % CALCULATE EXACT FORWARD RATES
    activeSchedule.F_forward = (1 ./ activeSchedule.yf_pay) .* ((P_start ./ P_end) - 1);
    
    %  PRE-CALCULATE OIS DISCOUNTS
    activeSchedule.B_ois = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, activeSchedule.payDates, estrCurve.dates, estrCurve.discounts);
end