function V = inject_cash_flows(V, step_i, x_grid, t_curr, start_date, a, sigma, B0_t_curr, ...
    payment_dates, T_start_dates, node_fixed_pay, node_float_reset, ...
    notional_amortized, K, yf, beta_vec, B0_pay, B0_start, N_steps)
% INJECT_CASH_FLOWS Identifies and injects local cash flows into the tree.
% This function fully vectorizes the cash flow mapping, eliminating inner loops.
%
% INPUTS:
%   V                  : [Vector, N_nodes x 1] Current clean swap value tree vector.
%   step_i             : [Scalar] Current time step index in the backward induction loop.
%   x_grid             : [Vector, N_nodes x 1] Spatial grid nodes column vector (x = r - alpha).
%   t_curr             : [Scalar] Current date mapped at step_i (datenum).
%   start_date         : [Scalar] Valuation date t0 (datenum).
%   a                  : [Scalar] Speed of mean reversion in the Hull-White model.
%   sigma              : [Scalar] Volatility parameter in the Hull-White model.
%   B0_t_curr          : [Scalar] Initial market discount factor P^M(0, t_curr).
%   payment_dates      : [Vector, M x 1] Swap payment dates (datenum).
%   T_start_dates      : [Vector, M x 1] Start dates for each accrual period (datenum).
%   node_fixed_pay     : [Vector, M x 1] Tree steps corresponding to payment dates.
%   node_float_reset   : [Vector, M x 1] Tree steps corresponding to floating resets.
%   notional_amortized : [Vector, M x 1] Amortized notional amount for each period.
%   K                  : [Scalar] Fixed strike rate of the swap.
%   yf                 : [Vector, M x 1] Year fractions between payment dates.
%   beta_vec           : [Vector, M x 1] Multi-curve floating adjustment factors.
%   B0_pay             : [Vector, M x 1] Precomputed market discounts P^M(0, T_pay).
%   B0_start           : [Vector, M x 1] Precomputed market discounts P^M(0, T_start).
%   N_steps            : [Scalar] Total number of discrete time steps in the tree.
%
% OUTPUTS:
%   V                  : [Vector, N_nodes x 1] Updated clean swap value tree vector after injection.

    % 1. FIXED LEG (Added at the node prior to payment)
    idx_fixed = find(node_fixed_pay == step_i);
    
    % The maturity payment is already initialized at N_steps, skip it during rollback
    if step_i == N_steps
        idx_fixed = setdiff(idx_fixed, length(payment_dates)); 
    end
    
    if ~isempty(idx_fixed)
        T_pay = payment_dates(idx_fixed);
        B0_T_pay = B0_pay(idx_fixed);
        
        % Analytical conditional ZCBs for all required payment dates across all spatial nodes
        B_curr_pay = compute_hw_zcb(x_grid, t_curr, T_pay, a, sigma, B0_t_curr, B0_T_pay, start_date);
        
        % Vector of weights for the fixed payments
        w_fixed = notional_amortized(idx_fixed) .* K .* yf(idx_fixed);
        
        % Vectorized subtraction of all overlapping fixed flows
        V = V + B_curr_pay * w_fixed(:);
    end

    % 2. FLOATING LEG (Subtracted at the node prior to reset)
    idx_float = find(node_float_reset == step_i);
    
    if ~isempty(idx_float)
        T_s = T_start_dates(idx_float);
        T_e = payment_dates(idx_float);
        B0_T_s = B0_start(idx_float);
        B0_T_e = B0_pay(idx_float);
        
        % Compute conditional ZCBs to the start and end of the period
        B_curr_start = compute_hw_zcb(x_grid, t_curr, T_s, a, sigma, B0_t_curr, B0_T_s, start_date);
        B_curr_end   = compute_hw_zcb(x_grid, t_curr, T_e, a, sigma, B0_t_curr, B0_T_e, start_date);
        
        % Weights based on the multi-curve framework formula
        w_start = notional_amortized(idx_float) .* beta_vec(idx_float);
        w_end   = notional_amortized(idx_float);
        
        % Vectorized cash flow injection via matrix multiplication
        V = V - B_curr_start * w_start(:) - B_curr_end * w_end(:);
    end
end
