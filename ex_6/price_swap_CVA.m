function [price, price_clean, CVA] = price_swap_CVA(a, sigma, sigma_times,...
    K, dt, grid_dates, l_max, dx, mu_hat, start_date, ois_curve, eur_curve,...
    scheduleSwap, RecoveryRate, HazardRate)
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
%   sigma_times        : [Vector] Time buckets corresponding to the sigma vector.
%   K                  : [Scalar] Fixed strike rate of the swap.
%   dt                 : [Scalar] Time step size of the tree.
%   grid_dates         : [Vector] Time grid dates for the tree (datenum).
%   l_max              : [Scalar] Maximum number of spatial nodes from the center.
%   dx                 : [Scalar] Spatial step size for the grid.
%   mu_hat             : [Scalar] Deterministic drift adjustment for probabilities.
%   start_date         : [Scalar] Valuation date (datenum).
%   ois_curve          : [Struct] OIS curve containing .dates and .discounts.
%   eur_curve          : [Struct] Euribor curve containing .dates and .discounts.
%   scheduleSwap        : [Struct] Swap schedule containing:
%                           - .payDates     : Coupon payment dates (datenum)
%                           - .fixingStart  : Euribor fixing start dates (2 BD backward)
%                           - .fixingEnd    : Euribor fixing end dates (2 BD backward)
%                           - .notionals    : Active outstanding amortizing notionals
%                           - .yf_pay       : Year fractions for payment periods (ACT/360)
%   RecoveryRate       : [Scalar] Recovery rate in case of default.
%   HazardRate         : [Scalar] Constant hazard rate (lambda) for default probability.
%
% OUTPUTS:
%   price              : [Scalar] Risky price of the swap (price_clean - CVA).
%   price_clean        : [Scalar] Risk-free clean price obtained from tree rollback.
%   CVA                : [Scalar] Credit Value Adjustment computed via backward induction.

    % 0. EXTRACT USEFUL SWAP PARAMETERS

    payment_dates = scheduleSwap.payDates;
    fixing_start  = scheduleSwap.fixingStart;
    fixing_end  = scheduleSwap.fixingEnd; 
    yf_pay  = scheduleSwap.yf_pay;
    notional_amortized  = scheduleSwap.notionals;

    % 1. PRE-COMPUTATIONS & TIMING MAPS
    
    % Calculate the total number of time steps in the tree
    N_steps = length(grid_dates) - 1; 
    
    % Calculate the total number of spatial nodes on the vertical axis
    N_nodes = 2 * l_max + 1; 
    
    % Generate the spatial grid column vector
    x_grid = (-l_max:l_max)' * dx; 
    
    % Convert the dates of the market OIS curve into numeric format (datenum)
    ois_dates = datenum(ois_curve.dates); 
    
    % Extract the discount factors from the market OIS curve
    ois_discounts = ois_curve.discounts; 
    
    % Compute the multi-curve floating leg adjustment factors (beta) using both OIS and Euribor curves
    beta_vec = compute_floating_leg_spread_beta(start_date, fixing_start, ...
        fixing_end, ois_curve, eur_curve); 
    
    % Get the total number of payment periods in the swap schedule
    M_periods = length(payment_dates); 
    
    % Initialize an array to map each fixed payment date to a specific tree step index
    node_fixed_pay = zeros(M_periods, 1); 
    
    % Initialize an array to map each floating reset date to a specific tree step index
    node_float_reset = zeros(M_periods, 1); 
    
    % Loop through the schedule to map cash flow dates to discrete time steps on the tree grid
    for k = 1:M_periods 
        
        % Find the last index on the tree grid that is less than or equal to the k-th payment date
        idx = find(grid_dates <= payment_dates(k), 1, 'last'); 
        
        % Fallback safety: if no index is found, assign to the first step,
        % otherwise use the found index
        if isempty(idx) 
            node_fixed_pay(k) = 1; 
        else 
            node_fixed_pay(k) = idx; 
        end 
        
        % Find the last index on the tree grid that is <= the k-th fixing 
        % date (which is 2 BD before accrual)
        idx_fix = find(grid_dates <= fixing_start(k), 1, 'last'); 
        
        % Fallback safety: if no index is found, assign to the first step, 
        % otherwise use the found fixing index
        if isempty(idx_fix) 
            node_float_reset(k) = 1; 
        else 
            node_float_reset(k) = idx_fix; 
        end 
    end
    
    % Precompute OIS market discount factors for every date on the tree grid 
    % via linear interpolation on zero rates
    B0_grid_dates = get_discount_factor_by_zero_rates_linear_interp(...
                start_date, grid_dates, ois_dates, ois_discounts);
                   
    % Precompute OIS market discount factors evaluated exactly at the payment dates
    B0_T_pay = get_discount_factor_by_zero_rates_linear_interp(...
                start_date, payment_dates, ois_dates, ois_discounts);
            
    % Precompute OIS market discount factors evaluated exactly at the start from the second fixing period
    B0_fix_start = get_discount_factor_by_zero_rates_linear_interp(...
                start_date, fixing_start(2:end), ois_dates, ois_discounts);
    % The first discount is computed by using the first accrual date (= settlement) 
    % since the first fixing start date is before settlement
    B0_fix_start = [1; B0_fix_start];

    % Precompute OIS market discount factors evaluated exactly at the end of each fixing period
    B0_fix_end = get_discount_factor_by_zero_rates_linear_interp(...
                start_date, fixing_end, ois_dates, ois_discounts); 

    % 2. INITIALIZE TREE VECTORS AT MATURITY (t = T_max) 

    % Initialize the CVA tree vector at maturity to zero (no future exposure left)
    CVA_tree = zeros(N_nodes, 1);
    
    % Initialize the swap value V at maturity with the final fixed cash flow (we receive fixed)
    V = ones(N_nodes, 1) * notional_amortized(end) * K * yf_pay(end);
    
    % Precompute the tree branching geometry (up, mid, down probabilities and targeted indices)
    [p_u, p_m, p_d, idx_u, idx_m, idx_d] = compute_tree_geometry(x_grid, l_max, mu_hat);

    % 3. BACKWARD INDUCTION LOOP
    
    % Step backwards from the maturity of the tree down to the root node (t=0)
    for i = N_steps:-1:1
        
        % Identify the current grid date
        t_curr = grid_dates(i);
        
        % Identify the next grid date 
        t_next = grid_dates(i+1);

        % Calculate the current grid time(in years) from the start date
        t = i* dt;
        
        % DYNAMIC LOCAL VOLATILITY EXTRACTION 
        % Check if the user passed a scalar volatility or not
        if  isscalar(sigma)
            % Use the constant scalar volatility for the current step
            sigma_local = sigma;
        else
            % Find the index of the first calibration bucket that is greater than or equal to current time t
            idx_sigma = find(t <= sigma_times, 1, 'first');
            
            % If current time t exceeds all defined buckets, use the last available volatility value
            if isempty(idx_sigma)
                sigma_local = sigma(end);
            else
                % Otherwise, assign the piecewise volatility corresponding to the matching time bucket
                sigma_local = sigma(idx_sigma);
            end
        end

        % Compute the HW analytical zero-coupon bond bridging the current step to the next step
        B_t_t1 = compute_hw_zcb(x_grid, t_curr, t_next, a, sigma_local, ...
                    B0_grid_dates(i), B0_grid_dates(i+1), start_date);
        
        % Compute the 3 directional stochastic discount factors (Up, Mid, Down)
        [D_u, D_m, D_d] = compute_stochastic_discount(x_grid, B_t_t1, dx, ...
                            mu_hat, a, sigma_local, dt);
        
        % A. EXPECTATION STEP
        % Multiply future values by transition probabilities and stochastic discount factors
        V = D_u .* V(idx_u) .* p_u + ...
            D_m .* V(idx_m) .* p_m + ...
            D_d .* V(idx_d) .* p_d;
        
        % Roll back the CVA tree vector simultaneously using the same discount 
        % factors and probabilities
        CVA_tree = D_u .* CVA_tree(idx_u) .* p_u + ...
                   D_m .* CVA_tree(idx_m) .* p_m + ...
                   D_d .* CVA_tree(idx_d) .* p_d;
               
        % B. CASH FLOW INJECTION STEP
        % Inject relevant cash flows (fixed / float) into the V vector if 
        % the current step matches a schedule date
        V = inject_cash_flows(V, i, x_grid, t_curr, start_date, a, sigma_local,...
            B0_grid_dates(i), node_fixed_pay, node_float_reset, K, scheduleSwap, ...
            beta_vec, B0_T_pay, B0_fix_start,  B0_fix_end, N_steps);
        
        % C. CREDIT VALUE ADJUSTMENT (CVA) ACCUMULATION
        
        % Convert current time to a year fraction from inception
        y_curr = yearfrac(start_date, t_curr, 3);
        
        % Convert next time step to a year fraction from inception
        y_next = yearfrac(start_date, t_next, 3);
        
        % Calculate the marginal probability of default specifically within this incremental dt window
        PD_i = exp(-HazardRate * y_curr) - exp(-HazardRate * y_next) ;
        
        % Accumulate unilateral CVA exposure: add the discounted expected loss associated with this specific step
        % Exposure is max(V, 0) 
        CVA_tree = CVA_tree + (1 - RecoveryRate) * PD_i * max(V, 0);
    end

    % 4. FINAL ASSIGNMENT AT t=0 (Center Node l=0)
    
    % The center node index corresponds to l = 0 (no spatial displacement)
    center_idx = l_max + 1;
    
    % Extract the clean risk-free price evaluated at the root node
    price_clean = V(center_idx);
    
    % Extract the totally accumulated CVA evaluated at the root node
    CVA = CVA_tree(center_idx);
    
    % The final risky price is the risk-free price minus the Credit Value Adjustment
    price = price_clean - CVA;
end