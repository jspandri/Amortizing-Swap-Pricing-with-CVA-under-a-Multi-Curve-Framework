function V = inject_cash_flows(V, step_i, x_grid, t_curr, start_date, a, ...
    sigma, B0_t_curr, node_fixed_pay, node_float, K, scheduleSwap,...
    beta_vec, B0_acc_start, N_steps)
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
%   node_fixed_pay     : [Vector, M x 1] Tree steps corresponding to payment dates.
%   node_float         : [Vector, M x 1] Tree steps corresponding to floating payments.
%   K                  : [Scalar] Fixed strike rate of the swap.
%   scheduleSwap        : [Struct] Swap schedule container with active periods:
%                           - .accrualStart : Period start dates (datenum)
%                           - .accrualEnd   : Period end dates (datenum)
%                           - .payDates     : Coupon payment dates (datenum)
%                           - .notionals    : Active outstanding amortizing notionals
%                           - .yf_pay       : Year fractions for payment periods (ACT/360)
%                           - .F_forward    : Forward Libor rates
%                           - .B_ois        : discounts at payments dates
%   beta_vec           : [Vector, M x 1] Multi-curve floating adjustment factors.
%   B0_acc_start       : [Vector, M x 1] Precomputed market discounts P^M(0, T_acc_start).
%   N_steps            : [Scalar] Total number of discrete time steps in the tree.
%
% OUTPUTS:
%   V                  : [Vector, N_nodes x 1] Updated clean swap value tree vector after injection.

     % 0. EXTRACT USEFUL SWAP PARAMETERS

    payment_dates = scheduleSwap.payDates;
    acc_start  = scheduleSwap.accrualStart;
    acc_end  = scheduleSwap.accrualEnd; 
    yf_pay  = scheduleSwap.yf_pay;
    notional_amortized  = scheduleSwap.notionals;
    B0_T_pay = scheduleSwap.B_ois;


    % 1. FIXED LEG (Subtracted at the node prior to payment)
    
    % Identify all indices of fixed payments occurring at the current time step
    idx_fixed = find(node_fixed_pay == step_i);
    
    % The maturity payment is already initialized at N_steps, so we exclude it 
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
        B_curr_pay = compute_hw_zcb(x_grid, t_curr, T_pay, a, sigma, B0_t_curr, ...
                                        B0_pay, start_date);
        
        % Calculate the cash flow amount for each fixed payment
        % Weight = Notional * Fixed Rate * Year Fraction
        w_fixed = notional_amortized(idx_fixed) .* K .* yf_pay(idx_fixed);
        
        % Vectorized addition: add the discounted value of all fixed cash flows 
        % to the current node values
        V = V - B_curr_pay * w_fixed(:);
    end
    
    % 2. FLOATING LEG (Added at the node prior to accrual start)
    
    % Identify all indices of floating leg occurring at the current time step
    idx_float = find(node_float == step_i);
    
    % Proceed only if there is a floating accrual start scheduled at this time step
    if ~isempty(idx_float)
        % Extract relevant dates for the floating period (Accrual Start,
        % Accrual End (= Payment))
        T_s = acc_start(idx_float);
        T_e = acc_end(idx_float);

        % Extract precomputed market discounts for these dates
        B0_T_s = B0_acc_start(idx_float);
        B0_T_e = B0_T_pay(idx_float);
                
        % Compute analytical Hull-White conditional Zero Coupon Bonds (ZCBs)
        % from the current node state to the start accrual and end accrual (= payment) 
        % dates of the floating period
        B_curr_start = compute_hw_zcb(x_grid, t_curr, T_s, a, sigma, ...
                            B0_t_curr, B0_T_s, start_date);
        B_curr_T_pay = compute_hw_zcb(x_grid, t_curr, T_e, a, sigma, ...
                            B0_t_curr, B0_T_e, start_date);
              
        % Calculate the floating leg cash flow
        float_flows = notional_amortized(idx_float)' .* ...
              (beta_vec(idx_float)' .* B_curr_start - B_curr_T_pay);
        
        % Update the swap value V: subtract the floating payment (since we receive the floating leg)
        V = V + sum(float_flows, 2);
    end
end