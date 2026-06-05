function [EE_profile, S_iw_profile, BPV_iw_profile,vol_exact_profile] = price_swap_bachelier(...
    settlement, scheduleSwap, K, discountCurve, volData, past_fixing_rate)
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
%                           - .notionals    : Active outstanding amortizing notionals
%                           - .yf_pay       : Year fractions for payment periods (ACT/360)
%                           - .F_forward    : Forward Libor rates
%                           - .B_ois        : discounts at payments dates
%   K                   : [Scalar] Fixed leg strike swap rate.
%   discountCurve       : [Struct] ESTR OIS discounting curve data (.dates, .discounts).
%   volData             : [Struct] Volatility matrix structure.
%   past_fixing_rate    : [Scalar] Pre-determined historical Euribor 3M fixing rate.
%
%
% OUTPUTS:
%   EE_profile     : [Vector] Expected Exposure (Receiver Swaption PV) at each node.
%   S_iw_profile   : [Vector] Forward Swap Rates of the residual underlying swaps.
%   BPV_iw_profile : [Vector] Basis Point Value of the residual amortizing legs.

    % Check if optional past fixing rate is provided
    if nargin < 6 || isempty(past_fixing_rate)
        past_fixing_rate = [];
    end

    % EXTRACT USEFUL DATA

    notionals = scheduleSwap.notionals;
    accrualStart = scheduleSwap.accrualStart;
    payDates = scheduleSwap.payDates;
    yf_pay =  scheduleSwap.yf_pay;
    B_ois = scheduleSwap.B_ois;
    F_forward = scheduleSwap.F_forward;

    % 2 BD fixing 
    %fixingDates = shift_2bd_backward(payDates);
    fixingDates=datewrkdy(payDates, -3);
    T_exp = yearfrac(settlement, fixingDates, 3);
    
    % INITIALIZATION

    numPeriods = length(payDates);
    S_iw_profile = zeros(numPeriods, 1); % vector for forward swap rates
    target_BPV_norm = zeros(numPeriods, 1); % vector for normalized BPV
    EE_profile = zeros(numPeriods, 1); % vector for expected exposure
    d = zeros(numPeriods, 1); % vector for Bachelier option argument parameter

    % PAST FIXING OVERWRITE

    % Check if the first active period is a running non-integer period (accrual start is in the past)
    if accrualStart(1) < settlement
        % Overwrite the first active forward rate with the historical known fixing rate
        F_forward(1) = past_fixing_rate;
    end
    
    % PV PROFILES FOR BOTH LEGS

    pv_bpv_leg   = (notionals .* yf_pay) .* B_ois;
    pv_float_leg = (notionals .* F_forward .* yf_pay) .* B_ois;
    
    % CUMULATIVE RESIDUAL VALUES

    % Compute remaining BPV for fixed leg using fast reverse cumulativesum  operations
    BPV_full = flip(cumsum(flip(pv_bpv_leg)));
    
    % Compute remaining PV for floating leg using fast reverse cumulative sum operations
    PV_float_full  = flip(cumsum(flip(pv_float_leg)));

    % Since default occurs at t_i, the replacement swap covers cash flows 
    % from i+1 to maturity. We shift the arrays and append 0 for the last node.
    BPV_iw_profile = [ BPV_full(2:end); 0];
    float_leg_pv   = [PV_float_full(2:end); 0];
    
    % Create logical filter ensuring residual swap values are strictly positive
    valid_bpv_mask = BPV_iw_profile > 0;
    
    % SWAP RATES

    % Calculate swap rates by dividing floating PV by BPV profiles
    S_iw_profile(valid_bpv_mask) = float_leg_pv(valid_bpv_mask) ./ BPV_iw_profile(valid_bpv_mask);
    
    % NORMALIZED BPV AND VOLATILITY MAPPING

    % Shift active notionals forward to establish target forward swap scaling
    N_current = [notionals(2:end); 0];
    
    % Normalize outstanding BPV by current target principal
    target_BPV_norm(valid_bpv_mask) = BPV_iw_profile(valid_bpv_mask) ./ N_current(valid_bpv_mask);

     % Extract mapped Bachelier volatilities
     vol_exact_profile= get_interpolated_vol_direct_bpv(settlement, fixingDates, target_BPV_norm, volData, discountCurve);
     
     %SECOND METHOD for Bachelier volatilities:
     % with equivalent tenor and interpolation on the grid interp2  
     %vol_exact_profile = get_interpolated_vol_bpv_matching(settlement,fixingDates, target_BPV_norm, volData, discountCurve);


    % BACHELIER EXPOSURE COMPUTATION
    
    % Isolate active future nodes
    calc_idx = (T_exp > 0) & valid_bpv_mask;
       
    % Compute d simultaneously for all valid option expiration nodes
    d(calc_idx) = (S_iw_profile(calc_idx) - K) ./ (vol_exact_profile(calc_idx) .* sqrt(T_exp(calc_idx)));
    
    % Price payer swaptions using Bachelier pricing formula to get exposure
    EE_profile(calc_idx) = BPV_iw_profile(calc_idx) .* ( (S_iw_profile(calc_idx) - K) .*...
        normcdf(d(calc_idx)) + vol_exact_profile(calc_idx) .* sqrt(T_exp(calc_idx)) .* normpdf(d(calc_idx)) );
end