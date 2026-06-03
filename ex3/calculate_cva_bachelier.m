function [CVA, EE_profile] = calculate_cva_bachelier(settlement,scheduleSwap, K, ...
    discountCurve, volData, hazardRate, recoveryRate, past_fixing_rate)
% CALCULATE_CVA_BACHELIER_V2 Computes the Credit Value Adjustment (CVA) 
% for an amortizing swap using a Bachelier pricing model.
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
%   discountCurve       : [Struct] ESTR OIS discounting curve data (.dates, .discounts).
%   volData             : [Matrix] Volatility matrix structure.
%   hazardRate          : [Scalar] Constant intensity of default lambda.
%   recoveryRate        : [Scalar] Expected recovery rate R.
%   past_fixing_rate    : [Scalar] Pre-determined historical Euribor 3M fixing rate.
%
% OUTPUTS:
%   CVA                           : [Scalar] Total Credit Value Adjustment.
%   EE_profile                    : [Vector] Expected Exposure vector (at each payment date).

    if nargin < 8 || isempty(past_fixing_rate)
        past_fixing_rate = [];
    end

    % 1. PROBABILITY OF DEFAULT

    % Compute ACT/365 year fractions from settlement to each payment date
    payDates = scheduleSwap.payDates;
    T_default = yearfrac(settlement, payDates, 3);

    % Compute survival probabilities 
    SP = exp(-hazardRate * T_default);
    
    % Shift survival probabilities array to obtain SP_{i-1}
    SP_prev = [1; SP(1:end-1)];
    
    % Calculate marginal default probabilities
    PD = SP_prev - SP;
    
    % 2. EXPECTED EXPOSURE PRICING
    
    [EE_profile, ~, ~] = price_swap_bachelier(settlement, scheduleSwap,...
        K, discountCurve, volData, past_fixing_rate);
    
    % 3. CVA CALCULATION
    
    % Define the loss given default
    LGD = (1 - recoveryRate);
    
    % Determine the total Credit Value Adjustment
    CVA = LGD * sum(EE_profile .* PD);
end