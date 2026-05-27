function [EE_profile, S_iw_profile, BPV_iw_profile] = price_swap_bachelier_v2(...
    settlement, scheduleSwap, K, discountCurve, pseudoCurve, volData, past_fixing_rate)
% PRICE_SWAP_BACHELIER_V2 Computes Expected Exposure profile of a swap using Bachelier Model.
%
% This function also calculates the residual Basis Point Value (BPV), forward 
% swap rates, and swaption prices for all future default dates in a single 
% pass using reverse cumulative sums.
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
%   volData             : [Struct] Volatility matrix structure.
%   past_fixing_rate    : [Scalar] Pre-determined historical Euribor 3M fixing rate.
%
%
% OUTPUTS:
%   EE_profile     : [Vector] Expected Exposure (Receiver Swaption PV) at each node.
%   S_iw_profile   : [Vector] Forward Swap Rates of the residual underlying swaps.
%   BPV_iw_profile : [Vector] Basis Point Value of the residual amortizing legs.

    % Check if optional past fixing rate is provided
    if nargin < 7 || isempty(past_fixing_rate)
        has_past_fixing = false;
    else
        has_past_fixing = true;
    end

    % 1. INITIALIZATION AND DISCOUNTS

    % Obtain number of future remaining payment intervals from the pre-computed schedule
    numPeriods = length(scheduleSwap.payDates);
    
    % Interpolate OIS discount factors vectorially on active payment dates
    B_ois = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.payDates, discountCurve.dates, discountCurve.discounts);
    
    % 2. FORWARD RATES COMPUTATION

    % Interpolate pseudo-discounts at fixing start dates
    P_start = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.fixingStart, pseudoCurve.dates, pseudoCurve.discounts);
    
    % Interpolate pseudo-discounts at period fixing end dates
    P_end   = get_discount_factor_by_zero_rates_linear_interp(settlement, ...
        scheduleSwap.fixingEnd, pseudoCurve.dates, pseudoCurve.discounts);
    
    % Compute Forward Rates between fixing dates
    F_forward = (1 ./ scheduleSwap.yf_float) .* ((P_start ./ P_end) - 1);
       
    % 3. PAST FIXING OVERWRITE
    % Check if the first active period is a running non-integer period (accrual start is in the past)
    if has_past_fixing && scheduleSwap.accrualStart(1) < settlement
        % Overwrite the first active forward rate with the historical known fixing rate
        F_forward(1) = past_fixing_rate;
    end
    
    % 4. PV PROFILES FOR BOTH LEGS
    pv_bpv_leg   = (scheduleSwap.notionals .* scheduleSwap.yf_pay) .* B_ois;
    pv_float_leg = (scheduleSwap.notionals .* F_forward .* scheduleSwap.yf_pay) .* B_ois;
    
    % 5. CUMULATIVE RESIDUAL VALUES

    % Compute remaining BPV vector using fast reverse cumulative sum matrix operations
    BPV_iw_profile = flip(cumsum(flip(pv_bpv_leg)));
    
    % Compute remaining variable PV vector using fast reverse cumulative sum operations
    float_residuo  = flip(cumsum(flip(pv_float_leg)));
    
    % 6. TIME TO EXPIRY AND SWAP RATES

    % Compute continuous time-to-expiry from settlement using ACT/365 convention on fixing start dates
    T_exp = yearfrac(settlement, scheduleSwap.fixingStart, 3);
    
    % Initialize vector for forward swap rates of residual structures
    S_iw_profile = zeros(numPeriods, 1);
    
    % Create logical filter ensuring residual swap values are strictly positive
    valid_bpv_mask = BPV_iw_profile > 0;
    
    % Calculate swap rates by dividing floating PV by BPV profiles
    S_iw_profile(valid_bpv_mask) = float_residuo(valid_bpv_mask) ./ BPV_iw_profile(valid_bpv_mask);
    
    % 7. VOLATILITY MAPPING

    % Shift active notionals forward to establish target forward swap scaling
    N_current = [scheduleSwap.notionals(2:end); 0];
    
    % Pre-allocate vector for normalized Basis Point Value metrics
    target_BPV_norm = zeros(numPeriods, 1);
    
    % Normalize outstanding BPV by current target principal
    target_BPV_norm(valid_bpv_mask) = BPV_iw_profile(valid_bpv_mask) ./ N_current(valid_bpv_mask);
    
    % Extract mapped Bachelier volatilities
    vol_exact_profile = get_interpolated_vol_bpv_matching(settlement, ...
        scheduleSwap.payDates, target_BPV_norm, volData, discountCurve);
    
    % 8. BACHELIER EXPOSURE COMPUTATION
    
    % Pre-allocate output array for expected exposure
    EE_profile = zeros(numPeriods, 1);
    
    % Isolate active future nodes where option option pricing math is required
    calc_idx = (T_exp > 0) & valid_bpv_mask;
    
    % Initialize vector for Bachelier option argument parameter
    d = zeros(numPeriods, 1);
    
    % Compute d simultaneously for all valid option expiration nodes
    d(calc_idx) = (S_iw_profile(calc_idx) - K) ./ (vol_exact_profile(calc_idx) .* sqrt(T_exp(calc_idx)));
    
    % Price receiver swaptions using Bachelier pricing formula to get exposure
    EE_profile(calc_idx) = BPV_iw_profile(calc_idx) .* ( (K - S_iw_profile(calc_idx)) .*...
        normcdf(-d(calc_idx)) + vol_exact_profile(calc_idx) .* sqrt(T_exp(calc_idx)) .* normpdf(d(calc_idx)) );
end