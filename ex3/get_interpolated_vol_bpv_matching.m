function vol_interp = get_interpolated_vol_bpv_matching(settlement, expiry_date, target_BPV_norm, volData, estCurv)
    % GET_INTERPOLATED_VOL_BPV_MATCHING Finds the exact Bachelier volatility
    % by mapping the amortizing BPV to an equivalent bullet swap tenor.
    
    tenors = volData.tenors; 
    bullet_BPVs = zeros(length(tenors), 1);
    
    % Calculate the normalized BPV for standard market bullet swaps
    for i = 1:length(tenors)
        Y = tenors(i);
        num_quarters = Y * 4; % Assuming standard 3M vs OIS quarterly swaps
        
        % Approximate bullet payment dates (adding ~91.25 days per quarter)
        % given that expiry_date is datenum (otherwise we can use callmonth(3))
        pay_dates_bullet = expiry_date + (1:num_quarters)' * 91.25;
        
        % Get OIS discounts for these dates
        P_bullet = get_discount_factor_by_zero_rates_linear_interp(...
            settlement, pay_dates_bullet, estCurv.dates, estCurv.discounts);
            
        % Normalized Bullet BPV (assuming delta approx 0.25)
        bullet_BPVs(i) = sum(0.25 * P_bullet);
    end
    
    % Map the target BPV to an "Equivalent Tenor" in years via interpolation
    equivalent_tenor = interp1(bullet_BPVs, tenors, target_BPV_norm, 'linear', 'extrap');
    
    % Bound the tenor to the matrix limits to avoid extreme extrapolation errors
    equivalent_tenor = max(min(equivalent_tenor, max(tenors)), min(tenors));
    
    % Expiry in years
    T_exp = yearfrac(settlement, expiry_date, 3);
    
    % Bound expiry to minimum available in the matrix (e.g., 1 Month)
    T_exp = max(T_exp, min(volData.expiries));
    
    % 2D Interpolation directly on the Volatility Matrix
    [TenorGrid, ExpiryGrid] = meshgrid(volData.tenors, volData.expiries);
    vol_interp = interp2(TenorGrid, ExpiryGrid, volData.matrix, equivalent_tenor, T_exp, 'linear');
end