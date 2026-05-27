function [npvCorporate, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv_v2(...
    settlement, scheduleSwap, K, discountCurve, pseudoCurve, past_fixing_rate)
% SWAP_RISKFREE_NPV_V2 Computes the Risk-Free Net Present Value of an amortizing receiver swap.
%
% INPUTS:
%   settlement          : [Scalar] Valuation date (datenum).
%   scheduleSwap        : [Struct] Swap schedule container with active periods:
%                           - .accrualStart : Period start dates (datenum)
%                           - .accrualEnd   : Period end dates (datenum)
%                           - .payDates     : Coupon payment dates (datenum)
%                           - .fixingStart  : Euribor fixing start dates (2 BD backward)
%                           - .fixingEnd    : Euribor fixing end dates (2 BD backward)
%                           - .notionals    : Active outstanding amortizing notionals
%                           - .yf_float     : Year fractions between fixing dates (ACT/360)
%                           - .yf_pay       : Year fractions for payment periods (ACT/360)
%   K                   : [Scalar] Fixed leg strike swap rate.
%   discountCurve       : [Struct] ESTR OIS discounting curve data (.dates, .discounts).
%   pseudoCurve         : [Struct] Euribor 3M forward pseudo curve data (.dates, .discounts).
%   past_fixing_rate    : [Scalar] Pre-determined historical Euribor 3M fixing rate (optional).
%
% OUTPUTS:
%   npvCorporate        : [Scalar] Net NPV from Corporate perspective (Receive Fixed, Pay Float).
%   npvFixedLeg         : [Scalar] Present Value of the Fixed coupon leg.
%   npvFloatLeg         : [Scalar] Present Value of the Floating leg.

    % Check if optional past fixing rate is provided
        if nargin < 6 || isempty(past_fixing_rate)
            has_past_fixing = false;
        else
            has_past_fixing = true;
        end
    % Interpolate OIS discount factors vectorially on active payment dates
    B_ois = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.payDates, discountCurve.dates, discountCurve.discounts);
    
    % Interpolate pseudo-discounts at fixing start dates
    P_start = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.fixingStart, pseudoCurve.dates, pseudoCurve.discounts);
    
    % Interpolate pseudo-discounts at period fixing end dates
    P_end   = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.fixingEnd, pseudoCurve.dates, pseudoCurve.discounts);
    
    % Compute Forward Rates between fixing dates
    F_forward = (1 ./ scheduleSwap.yf_float) .* ((P_start ./ P_end) - 1);
    
    % Check if the first active period is a running non-integer period (accrual start is in the past)
    if has_past_fixing && scheduleSwap.accrualStart(1) < settlement
        % Overwrite the first active forward rate with the historical known fixing rate
        F_forward(1) = past_fixing_rate;
    end
    
    % Compute cash flow vector for fixed leg
    cf_fixed = scheduleSwap.notionals .* K .* scheduleSwap.yf_pay;
    
    % Compute cash flow vector for floating leg 
    cf_float = scheduleSwap.notionals .* F_forward .* scheduleSwap.yf_pay;
    
    % Calculate total Present Value of Fixed Leg by multiplying cash flows by discounts and summing
    npvFixedLeg = sum(cf_fixed .* B_ois);
    
    % Calculate total Present Value of Float Leg by multiplying cash flows by discounts and summing
    npvFloatLeg = sum(cf_float .* B_ois);
    
    % Compute Net NPV from Corporate view (Receive Fixed, Pay Float).
    npvCorporate = npvFixedLeg - npvFloatLeg;
end