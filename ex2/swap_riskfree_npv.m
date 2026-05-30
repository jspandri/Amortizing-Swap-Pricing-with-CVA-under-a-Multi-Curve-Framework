function [npvBank, npvFixedLeg, npvFloatLeg] = swap_riskfree_npv(...
    settlement, scheduleSwap, K, past_fixing_rate)
% SWAP_RISKFREE_NPV_V2 Computes the Risk-Free Net Present Value of an amortizing swap.
%
% INPUTS:
%   settlement          : [Scalar] Valuation date (datenum).
%   scheduleSwap        : [Struct] Swap schedule container with active periods:
%                           - .accrualStart : Period start dates (datenum)
%                           - .accrualEnd   : Period end dates (datenum)
%                           - .payDates     : Coupon payment dates (datenum)
%                           - .notionals    : Active outstanding amortizing notionals
%                           - .yf_pay       : Year fractions for payment periods (ACT/360)
%                           - .F_forward    : Forward Libor rates
%                           - .B_ois        : discounts at payments dates
%   K                   : [Scalar] Fixed leg strike swap rate.
%   past_fixing_rate    : [Scalar] Pre-determined historical Euribor 3M fixing rate (optional).
%
% OUTPUTS:
%   npvBank             : [Scalar] Net NPV from Bank perspective (Receive Float, Pay Fixed).
%   npvFixedLeg         : [Scalar] Present Value of the Fixed coupon leg.
%   npvFloatLeg         : [Scalar] Present Value of the Floating leg.

    % Check if optional past fixing rate is provided
        if nargin < 4 || isempty(past_fixing_rate)
            past_fixing_rate = [];
        end

    % Extract useful data
    notionals = scheduleSwap.notionals;
    accrualStart = scheduleSwap.accrualStart;
    yf_pay =  scheduleSwap.yf_pay;
    B_ois = scheduleSwap.B_ois;
    F_forward = scheduleSwap.F_forward;
    
    if accrualStart(1) < settlement
        if isempty(past_fixing_rate)
            error('Valuation is mid-period, but past_fixing_rate was not provided!');
        end
        F_forward(1) = past_fixing_rate;
    end
    % Compute cash flow vector for fixed leg
    cf_fixed = notionals .* K .* yf_pay;
    
    % Compute cash flow vector for floating leg 
    cf_float = notionals .* F_forward .* yf_pay;
    
    % Calculate total Present Value of Fixed Leg by multiplying cash flows 
    % by discounts and summing
    npvFixedLeg = sum(cf_fixed .* B_ois);
    
    % Calculate total Present Value of Float Leg by multiplying cash flows 
    % by discounts and summing
    npvFloatLeg = sum(cf_float .* B_ois);
    
    % Compute Net NPV from Bank view (Receive Float, Pay Fixed).
    npvBank = npvFloatLeg - npvFixedLeg;
end