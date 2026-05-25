function [swaptionPrice, S_iw, BPV_iw, vol_exact] = price_swap_bachelier(settlement, ti_idx, tw_idx, scheduleSwap, estCurv, euliborCurv, volData,K)
    % PRICE_SWAP_BACHELIER Prices a receiver/payer swaption for CVA calculation
    % using the Bachelier (Normal) model and Amortizing BPV matching.
    

    % If default happens at t_i, the replacement swap covers cash flows from i+1 to omega
    idx_range = (ti_idx + 1) : tw_idx;
    
    % If we are at the very last period, exposure is zero
    if isempty(idx_range)
        swaptionPrice = 0; S_iw = 0; BPV_iw = 0; vol_exact = 0;
        return;
    end
    
    % Extract vectors for the residual swap
    startDates = datenum(scheduleSwap.accrualStart(idx_range));
    endDates   = datenum(scheduleSwap.accrualEnd(idx_range));
    payDates   = datenum(scheduleSwap.payDates(idx_range));
    deltas     = scheduleSwap.delta(idx_range);
    notionals  = scheduleSwap.notionals(idx_range);
    
    % DISCOUNTING & Amortizing BPV Calculation
    % We use your vectorized function for all future payment dates
    P_ois_pay = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, payDates, estCurv.dates, estCurv.discounts);
        
    % Amortizing BPV (in currency, actual monetary risk)
    BPV_iw = sum(notionals .* deltas .* P_ois_pay);
    
    % FORWARD SWAP RATE (S_iw)
    P_euri_start = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, startDates, euliborCurv.dates, euliborCurv.discounts);
    P_euri_end = get_discount_factor_by_zero_rates_linear_interp(...
        settlement, endDates, euliborCurv.dates, euliborCurv.discounts);
        
    F_forward = (1 ./ deltas) .* (P_euri_start ./ P_euri_end - 1);
    
    % Present Value of the residual floating leg
    float_leg_pv = sum(notionals .* F_forward .* deltas .* P_ois_pay);
    
    % The fair forward swap rate is the one that makes PV_float = PV_fixed
    S_iw = float_leg_pv / BPV_iw;
    

    % Expiry is the date of default (t_i)
    t_expiry_date = datenum(scheduleSwap.payDates(ti_idx));
    T_exp = yearfrac(settlement, t_expiry_date, 3); % ACT/365
    
    % Normalized BPV Target (Divide by starting notional of the forward swap)
    N_current = notionals(1); 
    target_BPV_norm = BPV_iw / N_current;
    
    % Call the helper function to find the exact volatility
    vol_exact = get_interpolated_vol_bpv_matching(settlement, t_expiry_date, target_BPV_norm, volData, estCurv);
    
    % BACHELIER PRICING FORMULA (Payer Swaption)
    % d-parameter for Normal distribution
    d = (S_iw - K) / (vol_exact * sqrt(T_exp));
    
    % Handle boundary condition where Expiry is extremely close to 0
    if T_exp <= 0
        swaptionPrice = max(float_leg_pv - BPV_iw * K, 0);
    else
        % Bachelier Call Option Formula
        swaptionPrice = BPV_iw * ( (S_iw - K) * normcdf(d) + vol_exact * sqrt(T_exp) * normpdf(d) );
    end
end