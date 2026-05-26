function V = inject_cash_flows(V, step_i, x_grid, t_curr, start_date, a, sigma, B0_t_curr, ...
    payment_dates, fixing_start, fixing_end, node_fixed_pay, node_float_reset, ...
    notional_amortized, K, yf, beta_vec, B0_T_pay, B0_fix_start, B0_fix_end, N_steps)
% INJECT_CASH_FLOWS Identifies and injects local cash flows into the tree.
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
%   fixing_start       : [Vector, M x 1] Start dates for each fixing period (datenum).
%   fixing_end         : [Vector, M x 1] End dates for each fixing period (datenum).
%   node_fixed_pay     : [Vector, M x 1] Tree steps corresponding to payment dates.
%   node_float_reset   : [Vector, M x 1] Tree steps corresponding to floating resets.
%   notional_amortized : [Vector, M x 1] Amortized notional amount for each period.
%   K                  : [Scalar] Fixed strike rate of the swap.
%   yf                 : [Vector, M x 1] Year fractions between payment dates.
%   beta_vec           : [Vector, M x 1] Multi-curve floating adjustment factors.
%   B0_T_pay           : [Vector, M x 1] Precomputed market discounts P^M(0, T_pay).
%   B0_fix_start       : [Vector, M x 1] Precomputed market discounts P^M(0, T_fixing_start).
%   B0_fix_end         : [Vector, M x 1] Precomputed market discounts P^M(0, T_fixing_end).
%   N_steps            : [Scalar] Total number of discrete time steps in the tree.
%
% OUTPUTS:
%   V                  : [Vector, N_nodes x 1] Updated clean swap value tree vector after injection.

    % 1. FIXED LEG (Added at the node prior to payment)
    
    % Identify all indices of fixed payments occurring at the current time step
    idx_fixed = find(node_fixed_pay == step_i);
    
    % The maturity payment is already initialized at N_steps, so we exclude it here 
    % to prevent double-counting during the backward induction rollback
    if step_i == N_steps
        idx_fixed = setdiff(idx_fixed, length(payment_dates)); 
    end
    
    % Proceed only if there is a fixed payment scheduled at this time step
    if ~isempty(idx_fixed)
        % Retrieve payment dates and market discount factors for the scheduled flows
        T_pay = payment_dates(idx_fixed);
        B0_pay = B0_T_pay(idx_fixed);
        
        % Calculate analytical Hull-White conditional Zero Coupon Bonds (ZCBs) 
        % for all nodes in the grid, bridging current time to payment dates
        B_curr_pay = compute_hw_zcb(x_grid, t_curr, T_pay, a, sigma, B0_t_curr, B0_pay, start_date);
        
        % Calculate the cash flow amount for each fixed payment
        % Weight = Notional * Fixed Rate * Year Fraction
        w_fixed = notional_amortized(idx_fixed) .* K .* yf(idx_fixed);
        
        % Vectorized addition: add the discounted value of all fixed cash flows to the current node values
        V = V + B_curr_pay * w_fixed(:);
    end
    
    % 2. FLOATING LEG (Subtracted at the node prior to reset)
    
    % Identify all indices of floating leg resets occurring at the current time step
    idx_float = find(node_float_reset == step_i);
    
    % Proceed only if there is a floating reset scheduled at this time step
    if ~isempty(idx_float)
        % Extract relevant dates for the floating period (Fixing Start, Fixing End, and Payment)
        T_s = fixing_start(idx_float);
        T_e = fixing_end(idx_float);
        T_pay = payment_dates(idx_float);
        
        % Extract precomputed market discounts for these dates
        B0_T_s = B0_fix_start(idx_float);
        B0_T_e = B0_fix_end(idx_float);
        B0_pay = B0_T_pay(idx_float);
                
        % Compute conditional ZCBs from the current node state to the start fixing, 
        % end fixing, and final payment date of the floating period
        B_curr_start = compute_hw_zcb(x_grid, t_curr, T_s, a, sigma, B0_t_curr, B0_T_s, start_date);
        B_curr_end   = compute_hw_zcb(x_grid, t_curr, T_e, a, sigma, B0_t_curr, B0_T_e, start_date);
        B_curr_T_pay = compute_hw_zcb(x_grid, t_curr, T_pay, a, sigma, B0_t_curr, B0_pay, start_date);
        
        % Calculate the floating leg cash flow: 
        % Notional * (Beta * Forward - 1) * Discount Factor
        float_flows = notional_amortized(idx_float)' .* ...
                      (beta_vec(idx_float)' .* (B_curr_start ./ B_curr_end) - 1) .* ...
                      B_curr_T_pay;
        
        % Update the swap value V: subtract the floating payment (since we pay the floating leg)
        % Sum across dimensions to handle multiple resets falling on the same step
        V = V - sum(float_flows, 2);
    end
end
