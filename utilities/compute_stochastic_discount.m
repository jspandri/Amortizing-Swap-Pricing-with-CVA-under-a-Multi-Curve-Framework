function [D_u, D_m, D_d] = compute_stochastic_discount(x_nodes, B_t_t1, ...
                        dx, mu_hat, a, sigma, dt)
% COMPUTE_STOCHASTIC_DISCOUNT Exact discount factors for Hull-White Trinomial Tree.
%
% This function calculates the stochastic discount factors for the three 
% possible branches (Up, Mid, Down) from each node, ensuring the tree is 
% arbitrage-free and consistent with the initial yield curve.
%
% INPUTS:
%   x_nodes     : [vector] Spatial grid nodes at current time step (x = r - alpha).
%   B_t_t1      : [scalar] HW analytical bond B(t_i, t_{i+1}; x_i)
%   dx          : [scalar] Spatial step size.
%   mu_hat      : [scalar] Deterministic drift adjustment (1 - exp(-a*dt)).
%   a           : [scalar] Speed of mean reversion in the Hull-White model.
%   sigma       : [scalar] Volatility parameter in the Hull-White model.
%   dt          : [scalar] Time step size.
%
% OUTPUTS:
%   D_u, D_m, D_d : [vectors] Stochastic discounts for the Up, Mid, and Down branches.

    % 1. PRE-COMPUTE HULL-WHITE VOLATILITY TERMS
    % sigma_hat: Local volatility of the process x over dt
    sigma_hat = sigma * sqrt((1 - exp(-2 * a * dt)) / (2 * a));
    
    % sigma_star: Integrated volatility term for the exact discount bond formula
    term1 = dt;
    term2 = 2 * (1 - exp(-a * dt)) / a;
    term3 = (1 - exp(-2 * a * dt)) / (2 * a);
    sigma_star = (sigma / a) * sqrt(term1 - term2 + term3);
    
    % Pre-calculated constants for the exponential argument
    term_const = -0.5 * (sigma_star^2);
    ratio_sigma = sigma_star / sigma_hat;
    N_nodes = length(x_nodes);

    % 2. DEFINE JUMP SIZES
    % Standard trinomial branching: Up (+dx), Mid (0), Down (-dx)
    dx_u = ones(N_nodes, 1) * dx;
    dx_m = zeros(N_nodes, 1);
    dx_d = ones(N_nodes, 1) * -dx;

    % 3. BOUNDARY ADJUSTMENTS (Non-standard branching at tree edges)
    % CASE B: Bottom boundary (Node 1) - Branching shifts Upwards
    dx_d(1) = 0;        % Down branch actually stays level
    dx_m(1) = dx;       % Mid branch jumps up 1 level
    dx_u(1) = 2 * dx;   % Up branch jumps up 2 levels

    % CASE C: Top boundary (Last Node) - Branching shifts Downwards
    dx_u(end) = 0;      % Up branch actually stays level
    dx_m(end) = -dx;    % Mid branch jumps down 1 level
    dx_d(end) = -2 * dx;% Down branch jumps down 2 levels

    % 4. CALCULATE STOCHASTIC DISCOUNTS
    % Drift of the process x at each node
    drift_term = mu_hat .* x_nodes;

    % Vectorized evaluation of the exact discount factor formula:
    % D = B(t, T) * exp( -0.5*sigma_star^2 - (sigma_star/sigma_hat) * (Jump + Drift) )
    D_u = B_t_t1 .* exp(term_const - ratio_sigma .* (dx_u + drift_term));
    D_m = B_t_t1 .* exp(term_const - ratio_sigma .* (dx_m + drift_term));
    D_d = B_t_t1 .* exp(term_const - ratio_sigma .* (dx_d + drift_term));

end