function [price, price_clean, CVA] = price_swap_CVA(a, sigma, K, dt, ...
    grid_dates, l_max, dx, mu_hat, start_date, ois_curve, eur_curve, ...
    payment_dates, yf, notional_amortized, RecoveryRate, HazardRate)
% PRICE_SWAP_CVA Prices an amortizing Swap and computes its CVA using a 
% Hull-White Trinomial Tree.
%
% This function performs backward induction on a trinomial tree to calculate 
% both the risk-free price of an amortizing swap and its unilateral Credit Value 
% Adjustment (CVA) using a multi-curve framework. 
%
% INPUTS:
%   a                  : [Scalar] Speed of mean reversion in the HW model.
%   sigma              : [Scalar] Volatility parameter in the HW model.
%   K                  : [Scalar] Fixed strike rate of the swap.
%   dt                 : [Scalar] Time step size of the tree.
%   grid_dates         : [Vector] Time grid dates for the tree (datenum).
%   l_max              : [Scalar] Maximum number of spatial nodes from the center.
%   dx                 : [Scalar] Spatial step size for the grid.
%   mu_hat             : [Scalar] Deterministic drift adjustment for probabilities.
%   start_date         : [Scalar] Valuation date (datenum).
%   ois_curve          : [Struct] OIS curve containing .dates and .discounts.
%   eur_curve          : [Struct] Euribor curve containing .dates and .discounts.
%   payment_dates      : [Vector] Payment dates of the swap (datenum).
%   yf                 : [Vector] Year fractions between payment dates.
%   notional_amortized : [Vector] Amortized notional amount for each period.
%   RecoveryRate       : [Scalar] Recovery rate in case of default.
%   HazardRate         : [Scalar] Constant hazard rate (lambda) for default probability.
%
% OUTPUTS:
%   price              : [Scalar] Risky price of the swap (price_clean - CVA).
%   price_clean        : [Scalar] Risk-free clean price obtained from tree rollback.
%   CVA                : [Scalar] Credit Value Adjustment computed via backward induction.

    % 1. PRE-COMPUTATIONS & TIMING MAPS
    N_steps = length(grid_dates) - 1;
    N_nodes = 2 * l_max + 1;
    x_grid = (-l_max:l_max)' * dx; % Spatial grid nodes column vector
    
    ois_dates = datenum(ois_curve.dates);
    ois_discounts = ois_curve.discounts;
    
    % Compute the multi-curve floating leg adjustment factor (betas)
    beta_vec = compute_floating_leg_spread_beta(start_date, payment_dates,...
                ois_curve, eur_curve);
    
    % Define the period start dates for the floating leg
    T_start_dates = [start_date; payment_dates(1:end-1)];
    
    % Map cash flow schedule dates to discrete time steps on the tree grid
    M_periods = length(payment_dates);
    node_fixed_pay = zeros(M_periods, 1);
    node_float_reset = zeros(M_periods, 1);
    
    for k = 1:M_periods
        node_fixed_pay(k) = find(grid_dates <= payment_dates(k), 1, 'last');
        node_float_reset(k) = find(grid_dates <= T_start_dates(k), 1, 'last');
    end
    
    % Precompute all Market OIS discount factors 
    B0_grid_dates = get_discount_factor_by_zero_rates_linear_interp(...
                start_date, grid_dates, ois_dates, ois_discounts);
    B0_pay = get_discount_factor_by_zero_rates_linear_interp(...
                start_date, payment_dates, ois_dates, ois_discounts);
    B0_start = get_discount_factor_by_zero_rates_linear_interp(...
                start_date, T_start_dates, ois_dates, ois_discounts);

    % 2. INITIALIZE TREE VECTORS AT MATURITY (t = T_max)
    CVA_tree = zeros(N_nodes, 1);
    V = -ones(N_nodes, 1) * notional_amortized(end) * K * yf(end);
    
    % Precompute tree branching geometry
    [p_u, p_m, p_d, idx_u, idx_m, idx_d] = compute_tree_geometry(x_grid, l_max, mu_hat);

    % 3. BACKWARD INDUCTION LOOP
    for i = N_steps:-1:1
        t_curr = grid_dates(i);
        t_next = grid_dates(i+1);
        
        % Compute the HW analytical zero-coupon bond for the current step
         B_t_t1 = compute_hw_zcb(x_grid, t_curr, t_next, a, sigma, ...
                    B0_grid_dates(i), B0_grid_dates(i+1), start_date);
        
        % Compute short-rate stochastic discount factors for the 3 branches
        [D_u, D_m, D_d] = compute_stochastic_discount(x_grid, B_t_t1, dx, ...
                            mu_hat, a, sigma, dt);
        
        % A. EXPECTATION STEP (Trinomial Rollback)
        V = D_u .* V(idx_u) .* p_u + ...
            D_m .* V(idx_m) .* p_m + ...
            D_d .* V(idx_d) .* p_d;
        
        % Roll back the CVA tree vector
        CVA_tree = D_u .* CVA_tree(idx_u) .* p_u + ...
                   D_m .* CVA_tree(idx_m) .* p_m + ...
                   D_d .* CVA_tree(idx_d) .* p_d;
               
        % B. CASH FLOW INJECTION STEP
        V = inject_cash_flows(V, i, x_grid, t_curr, start_date, a, sigma, B0_grid_dates(i), ...
            payment_dates, T_start_dates, node_fixed_pay, node_float_reset, ...
            notional_amortized, K, yf, beta_vec, B0_pay, B0_start, N_steps);
        
        % C. CREDIT VALUE ADJUSTMENT (CVA) ACCUMULATION
        y_curr = yearfrac(start_date, t_curr, 3);
        y_next = yearfrac(start_date, t_next, 3);
        PD_i = exp(-HazardRate * y_curr) - exp(-HazardRate * y_next);
        
        % Accumulate unilateral CVA exposure
        CVA_tree = CVA_tree + (1 - RecoveryRate) * PD_i * max(V, 0);
    end

    % 4. FINAL ASSIGNMENT AT t0 (Center Node l=0)
    center_idx = l_max + 1;
    
    price_clean = V(center_idx);
    CVA = CVA_tree(center_idx);
    price = price_clean - CVA;
end
