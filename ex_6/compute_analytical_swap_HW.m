function V_swap = compute_analytical_swap_HW(x_grid, t_curr, start_date, a, sigma, B0_t_curr,...
    K, scheduleSwap, beta_vec, B0_acc_start)
% COMPUTE_ANALYTICAL_SWAP_HW Computes the analytical Mark-to-Market value of 
% an amortizing swap at every node in the Hull-White grid.
%
% INPUTS:
%   x_grid       : [N_nodes x 1] Spatial grid.
%   t_curr       : [Scalar] Current evaluation time (datenum).
%   start_date   : [Scalar] Settlement date (datenum).
%   a            : [Scalar] Hull-White mean reversion parameter.
%   sigma        : [Scalar] Hull-White volatility parameter.
%   B0_t_curr    : [Scalar] OIS discount factor at t_curr relative to t0.
%   K            : [Scalar] Fixed strike rate.
%   scheduleSwap : [Struct] Swap schedule container with active periods:
%                            - .accrualStart : Period start dates (datenum)
%                            - .accrualEnd   : Period end dates (datenum)
%                            - .payDates     : Coupon payment dates (datenum)
%                            - .notionals    : Active outstanding amortizing notionals
%                            - .yf_pay       : Year fractions for payment periods (ACT/360)
%                            - .F_forward    : Forward Libor rates
%                            - .B_ois        : discounts at payments dates%   
%   beta_vec     : [Vector] Multi-curve deterministic beta adjustment factors.
%   B0_acc_start : [Vector] OIS discount factors at accrual start dates.
%
% OUTPUTS:
%   V_swap       : [N_nodes x 1] Swap MtM value vector at each node.

   % Identify indices of coupons occurring in the future relative to the current tree time
    future_idx = find(scheduleSwap.payDates > t_curr);
    
    % If no future coupons exist, the swap value is zero across all nodes
    if isempty(future_idx)
        V_swap = zeros(length(x_grid), 1);
        return;
    end
    
    % Extract only the data relevant to future coupons for efficiency
    T_p_vec     = scheduleSwap.payDates(future_idx);      % Payment dates
    T_s_vec     = scheduleSwap.accrualStart(future_idx);  % Accrual start dates
    yf_vec      = scheduleSwap.yf_pay(future_idx);        % Year fractions
    notl_vec    = scheduleSwap.notionals(future_idx);     % Amortized notionals
    B_ois_p     = scheduleSwap.B_ois(future_idx);         % OIS discounts at payment dates
    F_fwd_vec   = scheduleSwap.F_forward(future_idx);     % Pre-fixed forward rates
    beta_vec_sub= beta_vec(future_idx);                   % Multi-curve beta adjustment
    B0_acc_s    = B0_acc_start(future_idx);               % Market discounts at accrual start
    
    % Compute HW Zero Coupon Bonds (P(t, Tp)) for all nodes and future payments
    % Returns matrix [N_nodes x N_future_coupons]
    B_pay_matrix = compute_hw_zcb(x_grid, t_curr, T_p_vec, a, sigma, ...
                    B0_t_curr, B_ois_p, start_date);
    
    % FIXED LEG CALCULATION
    % Calculate scalar fixed cash flow per period (Notional * K * YearFraction)
    cf_fixed_vec = notl_vec(:)' .* K .* yf_vec(:)';
    % Multiply bond prices by CFs and sum across the coupon dimension (dim 2)
    % Result is [N_nodes x 1], the total fixed leg value per node
    fixed_leg_sum = sum(B_pay_matrix .* cf_fixed_vec, 2);
    
    % FLOATING LEG CALCULATION
    % Split periods into those where accrual has not yet started (stochastic)
    % and those where accrual started (fixed/deterministic)
    is_unstarted = (T_s_vec >= t_curr);
    
    % 1. Started Accrual (Fixed Rate Leg):
    % If accrual started, the rate is fixed and flow is deterministic.
    if any(~is_unstarted)
        cf_float_fixed_val = notl_vec(~is_unstarted)' .* F_fwd_vec(~is_unstarted) .* yf_vec(~is_unstarted)';
        % Sum the discounted fixed flows for the started coupons
        float_leg_sum = sum(B_pay_matrix(:, ~is_unstarted) .* cf_float_fixed_val, 2);
    else
        float_leg_sum = 0;
    end
    
    % 2. Unstarted Accrual (Stochastic Leg):
    % If accrual has not started, the future Euribor is stochastic.
    if any(is_unstarted)
        % Compute analytical HW bond for accrual start dates: P(t, Ts)
        B_start_matrix = compute_hw_zcb(x_grid, t_curr, T_s_vec(is_unstarted), a, sigma, ...
                                        B0_t_curr, B0_acc_s(is_unstarted), start_date);
        
        % Floating leg payoff is N * (beta * P(t, Ts) - P(t, Tp))
        cf_stoch_matrix = notl_vec(is_unstarted)' .* (beta_vec_sub(is_unstarted)' .* B_start_matrix - B_pay_matrix(:, is_unstarted));
        
        % Add the stochastic part to the floating leg
        float_leg_sum = float_leg_sum + sum(cf_stoch_matrix, 2);
    end
    
    % Total Swap Value: Floating Leg (receive) - Fixed Leg (pay)
    V_swap = float_leg_sum - fixed_leg_sum;
end