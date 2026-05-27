function [CVA, EE_profile] = calculate_cva_bachelier_v2(settlement,scheduleSwap, K, ...
    discountCurve, pseudoCurve, volData, hazardRate, recoveryRate, past_fixing_rate)
% CALCULATE_CVA_BACHELIER_V2 Computes the Credit Value Adjustment (CVA) 
% for an amortizing swap using a Bachelier pricing model.
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
%   volData             : [Matrix] Volatility matrix structure.
%   hazardRate          : [Scalar] Constant intensity of default lambda.
%   recoveryRate        : [Scalar] Expected recovery rate R.
%   past_fixing_rate    : [Scalar] Pre-determined historical Euribor 3M fixing rate.
%
% OUTPUTS:
%   CVA                           : [Scalar] Total Credit Value Adjustment.
%   EE_profile                    : [Vector] Expected Exposure vector (at each payment date).

    if nargin < 9 || isempty(past_fixing_rate)
        past_fixing_rate = [];
    end

    % 1. PROBABILITY OF DEFAULT CALCULATION

    % Compute ACT/365 year fractions from settlement to each payment date
    T_pay = yearfrac(settlement, scheduleSwap.payDates, 3);
    
    % Compute survival probabilities 
    SP = exp(-hazardRate * T_pay);
    
    % Shift survival probabilities array to obtain SP_{i-1}
    SP_prev = [1; SP(1:end-1)];
    
    % Calculate marginal default probabilities
    PD = SP_prev - SP;
    
    % 2. EXPECTED EXPOSURE PRICING
    [EE_profile, ~, ~] = price_swap_bachelier_v2(settlement, scheduleSwap, ...
        K, discountCurve, pseudoCurve, volData, past_fixing_rate);
    
    % 3. CVA CALCULATION
    
    % Define the loss given default
    LGD = (1 - recoveryRate);
    
    % Determine the total Credit Value Adjustment
    CVA = LGD * sum(EE_profile .* PD);
end