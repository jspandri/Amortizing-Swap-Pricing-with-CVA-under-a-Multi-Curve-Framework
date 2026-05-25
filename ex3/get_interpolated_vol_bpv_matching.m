function vol_interp = get_interpolated_vol_bpv_matching(settlement, expiry_date, target_BPV_norm, volData, estCurv)
    % GET_INTERPOLATED_VOL_BPV_MATCHING Maps amortizing swap BPVs to equivalent market 
    % bullet tenors to find the exact Bachelier implied volatility at each node.
    %
    % Inputs:
    %   settlement      - Valuation date (datenum scalar)
    %   expiry_date     - Option expiry dates / payment nodes (datenum vector, length N)
    %   target_BPV_norm - Normalized residual BPVs of the amortizing swap (vector, length N)
    %   volData         - Struct with market vol grid (.tenors, .expiries, .vol_matrix)
    %   estCurv         - Struct with OIS discount curve (.dates, .discounts)
    %
    % Outputs:
    %   vol_interp      - Vector of mapped Bachelier volatilities for each node (length N)

    expiry_date = expiry_date(:);
    target_BPV_norm = target_BPV_norm(:);
    N = length(expiry_date);
    tenors = volData.tenors(:)'; 
    num_tenors = length(tenors);
    bullet_BPVs = zeros(N, num_tenors);
    
    % --- Benchmark Bullet BPV Calculation ---
    for j = 1:num_tenors
        Y = tenors(j);
        num_quarters = Y * 4; % Assuming standard quarterly payments
        
        % Implicit broadcasting: expands to an (N x num_quarters) matrix of future payment dates
        pay_dates_bullet_mat = expiry_date + (1:num_quarters) * 91.25;
        
        % Flatten the 2D date matrix into a 1D vector using (:) to query the curve 
        % interpolation function in a single, high-performance vectorized call.
        P_bullet_vec = get_discount_factor_by_zero_rates_linear_interp(...
            settlement, pay_dates_bullet_mat(:), estCurv.dates, estCurv.discounts);
            
        P_bullet_mat = reshape(P_bullet_vec, N, num_quarters);
        bullet_BPVs(:, j) = sum(0.25 * P_bullet_mat, 2);
    end
    
    % --- Risk Mapping: Target BPV -> Equivalent Bullet Tenor ---
    equivalent_tenor = zeros(N, 1);
    valid_idx = target_BPV_norm > 0;
    
    for i = 1:N
        if valid_idx(i)
            equivalent_tenor(i) = interp1(bullet_BPVs(i, :), tenors, target_BPV_norm(i), 'linear', 'extrap');
        end
    end
    
    % Clamp mapped tenors within the market grid boundaries to avoid extrapolation errors
    equivalent_tenor = max(min(equivalent_tenor, max(tenors)), min(tenors));
    
    % --- Time to Expiry Calculation & Boundary Clamping ---
    T_exp = yearfrac(settlement, expiry_date, 3);
    T_exp = max(T_exp, min(volData.expiries));
    
    % ---  Fully Vectorized 2D Volatility Interpolation ---
    [TenorGrid, ExpiryGrid] = meshgrid(volData.tenors, volData.expiries);
    vol_interp = interp2(TenorGrid, ExpiryGrid, volData.vol_matrix, equivalent_tenor, T_exp, 'linear');
end