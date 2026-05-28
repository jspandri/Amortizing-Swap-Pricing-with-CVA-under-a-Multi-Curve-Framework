function [EE_profile, S_iw_profile, BPV_iw_profile, vol_exact_profile] = price_swap_bachelier(settlement, scheduleSwap, swapMarketData, volData, K, estCurv, T_exp)
    % PRICE_SWAP_BACHELIER Computes the Expected Exposure profile of a swap
    % using a fully vectorized Bachelier (Normal) swaption pricing model.
    %
    % This function calculates the residual Basis Point Value (BPV), forward 
    % swap rates, and swaption prices for all future default dates in a single 
    % pass using reverse cumulative sums.
    %
    % Inputs:
    %   settlement     - Settlement date (datenum)
    %   scheduleSwap   - Struct containing the swap amortizing schedule
    %   swapMarketData - Struct with pre-calculated vectors (.B_ois, .F_forward)
    %   volData        - Struct containing implied volatility surface/matrix
    %   K              - Strike rate for the swaption
    %   estCurv        - Struct containing the OIS zero curve for BPV mapping
    %   T_exp          - Vector of times to expiry (in years) for each node
    %
    % Outputs:
    %   EE_profile        - Vector of Expected Exposures (Swaption PV) at each node
    %   S_iw_profile      - Vector of Fair Forward Swap Rates for the residual swap
    %   BPV_iw_profile    - Vector of residual Amortizing BPVs at each node
    %   vol_exact_profile - Vector of exact mapped Bachelier volatilities
    
    numPeriods = length(scheduleSwap.payDates);
    
    % --- Extract full schedule vectors ---
    deltas       = scheduleSwap.delta;
    notionals    = scheduleSwap.notionals;
    P_ois        = swapMarketData.B_ois;
    F_fwd        = swapMarketData.F_forward;
    payDates_num = scheduleSwap.payDates;
    
    % --- Standalone cash flows for each single period ---
    cf_fixed = notionals .* deltas .* P_ois;
    cf_float = notionals .* F_fwd .* deltas .* P_ois;
    
    % --- Reverse cumulative sum to obtain the residual PV at each node ---
    BPV_full      = cumsum(cf_fixed, 'reverse');
    PV_float_full = cumsum(cf_float, 'reverse');
    
    % --- Replacement Swap Shift ---
    % Since default occurs at t_i, the replacement swap covers cash flows 
    % from i+1 to maturity. We shift the arrays and append 0 for the last node.
    BPV_iw_profile = [BPV_full(2:end); 0];
    float_leg_pv   = [PV_float_full(2:end); 0];
    
    % --- Initialize output profiles ---
    S_iw_profile = zeros(numPeriods, 1);
    EE_profile   = zeros(numPeriods, 1);
    
    % --- Forward Swap Rate ---
    % Calculated only where residual BPV exists to prevent division by zero (NaN)
    valid_idx = BPV_iw_profile > 0;
    S_iw_profile(valid_idx) = float_leg_pv(valid_idx) ./ BPV_iw_profile(valid_idx);
    
    % --- Normalized BPV and Exact Volatility Mapping ---
    % Normalize using the starting notional of the forward replacement swap
    N_current = [notionals(2:end); 0]; 
    target_BPV_norm = zeros(numPeriods, 1);
    target_BPV_norm(valid_idx) = BPV_iw_profile(valid_idx) ./ N_current(valid_idx);
    
    % Pass the full vectors to the volatility mapping function
    vol_exact_profile = get_interpolated_vol_bpv_matching(...
        settlement, payDates_num, target_BPV_norm, volData, estCurv);
        
    % --- VECTORIZED BACHELIER PRICING ---
    % Identify indices where standard option pricing formula is strictly valid
    calc_idx = (T_exp > 0) & valid_idx;
    d = zeros(numPeriods, 1);
    
    % Calculate the 'd' parameter simultaneously for all valid nodes
    d(calc_idx) = (S_iw_profile(calc_idx) - K) ./ (vol_exact_profile(calc_idx) .* sqrt(T_exp(calc_idx)));
    
    % Apply Bachelier Call Option Formula
    EE_profile(calc_idx) = BPV_iw_profile(calc_idx) .* ...
        ( (S_iw_profile(calc_idx) - K) .* normcdf(d(calc_idx)) + ...
          vol_exact_profile(calc_idx) .* sqrt(T_exp(calc_idx)) .* normpdf(d(calc_idx)) );

end