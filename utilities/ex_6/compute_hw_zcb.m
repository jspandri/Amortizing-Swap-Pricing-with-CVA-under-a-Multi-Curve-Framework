function ZCB_matrix = compute_hw_zcb(x_nodes, t_curr, T_future, a, sigma, ...
                    B0_t_curr, B0_T_future, start_date)
% COMPUTE_HW_ZCB Calculates the analytical Hull-White Zero Coupon Bond.
%
% This function evaluates the closed-form HW pricing formula for a ZCB
% conditional on the current state x_nodes at time t_curr.
%
% INPUTS:
%   x_nodes     : [N_nodes x 1] vector of spatial grid nodes.
%   t_curr      : [scalar] Current time in the tree (datenum).
%   T_future    : [N_future x 1] vector of future maturity dates (datenum).
%   a, sigma    : [scalars] Hull-White model parameters.
%   B0_t_curr   : [scalar] Market discount P(0, t_curr).
%   B0_T_future : [N_future x 1] Market discounts P(0, T_future).
%   start_date  : [scalar] Valuation date t=0 (datenum).
%
% OUTPUT:
%   ZCB_matrix  : [N_nodes x N_future] Matrix of analytical bond prices.

    % 1. Force strict COLUMN vectors (Crucial to avoid yearfrac NaN bugs)
    x_nodes = x_nodes(:);             % [N_nodes x 1]
    T_future = T_future(:);           % [N_future x 1]
    B0_T_future = B0_T_future(:);     % [N_future x 1]
    
    % 2. Time from start to current node (for variance calculation)
    yfrac_t0_t = yearfrac(start_date, t_curr, 3);
    V_t = (sigma^2 / (2 * a)) * (1 - exp(-2 * a * yfrac_t0_t));
    
    % 3. Hull-White B coefficient & Variance adjustment (Computed as Columns)
    tau = yearfrac(t_curr, T_future, 3);  % [N_future x 1]
    B_tau = (1 - exp(-a * tau)) ./ a;     % [N_future x 1]
    
    var_adj = 0.5 * V_t .* (B_tau.^2);    % [N_future x 1]
    
    % 4. Matrix generation (Exact logic from calc_swap_payoff)
    
    % Forward market discount factors as a ROW vector [1 x N_future]
    forward_ZCB = (B0_T_future ./ B0_t_curr)'; 
    
    % Exponent calculation using broadcasting: 
    % [N_nodes x 1] * [1 x N_future] -> [N_nodes x N_future]
    exponent = -(x_nodes * B_tau') - var_adj';
    
    % Final analytical ZCB matrix: [N_nodes x N_future]
    ZCB_matrix = forward_ZCB .* exp(exponent);
    
end