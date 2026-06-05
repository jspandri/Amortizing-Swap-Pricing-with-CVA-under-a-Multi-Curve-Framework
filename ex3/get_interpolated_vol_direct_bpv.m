function vol_interp = get_interpolated_vol_direct_bpv(settlement, expiry_date, target_BPV_norm, volData, discountCurve)
    % GET_INTERPOLATED_VOL_DIRECT_BPV Extracts the implied Bachelier volatility 
    % for an amortizing swap by directly interpolating across Bullet BPVs.
    % This implementation strictly follows Hint 2 of the project guidelines.
    %
    % INPUTS:
    %   settlement      : Valuation date (datenum scalar)
    %   expiry_date     : Option expiry dates / payment nodes (datenum vector, length N)
    %   target_BPV_norm : Normalized residual BPVs of the amortizing swap (vector, length N)
    %   volData         : Struct with market vol grid (.tenors, .expiries, .vol_matrix)
    %   estCurv         : Struct with OIS discount curve (.dates, .discounts)
    %
    % OUTPUTS:
    %   vol_interp      : Vector of mapped Bachelier volatilities for each node (length N)

    expiry_date = expiry_date(:);
    target_BPV_norm = target_BPV_norm(:);
    N = length(expiry_date);
    tenors = volData.tenors(:)'; 
    num_tenors = length(tenors);
    bullet_BPVs = zeros(N, num_tenors);
    
    % Vectorized Bullet BPV Calculation
    for j = 1:num_tenors
        Y = tenors(j);
        num_quarters = Y * 4; 
        
        pay_dates_bullet_mat = generate_exact_quarterly_dates(expiry_date, num_quarters);
        
        P_bullet_vec = get_discount_factor_by_zero_rates_linear_interp(...
            settlement, pay_dates_bullet_mat(:), discountCurve.dates, discountCurve.discounts);
            
        P_bullet_mat = reshape(P_bullet_vec, N, num_quarters);
        full_dates_mat = [expiry_date, pay_dates_bullet_mat];
        exact_deltas = yearfrac(full_dates_mat(:, 1:end-1), full_dates_mat(:, 2:end), 2); % ACT/360
        
        bullet_BPVs(:, j) = sum(exact_deltas .* P_bullet_mat, 2);
    end
    
    % Direct BPV Interpolation (hint 2)
    vol_interp = zeros(N, 1);
    valid_idx = target_BPV_norm > 0;
    
    % Time to expiry computation with boundary clamping to avoid NaN issues
    T_exp = yearfrac(settlement, expiry_date, 3);
    T_exp = max(min(T_exp, max(volData.expiries)), min(volData.expiries));
    
    for i = 1:N
        if valid_idx(i)
            % STEP A (hint 2): Interpolate along the expiries axis.
            % This extracts a volatility curve (1 x num_tenors vector) 
            % perfectly aligned with our exact T_exp(i)
            vol_curve_at_Texp = interp1(volData.expiries, volData.vol_matrix, T_exp(i), 'linear');
            
            % STEP B (hint 2): Direct interpolation using BPVs.
            % X-axis = Bullet swap BPVs at that specific expiry
            % Y-axis = Volatility curve just computed
            % Query  = Our target amortizing BPV
            vol_interp(i) = interp1(bullet_BPVs(i, :), vol_curve_at_Texp, target_BPV_norm(i), 'linear', 'extrap');
        end
    end
end