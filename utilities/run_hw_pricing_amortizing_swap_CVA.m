function [prices, results_table] = run_hw_pricing_amortizing_swap_CVA(a, sigma, K, ...
    startDate, maturity_date_not_adjusted, precision_levels, notional_amortized, ...
    RecoveryRate,HazardRate, ois_curve, eur_curve)
% RUN_HW_PRICING_AMORTIZING_SWAP_CVA Manages the convergence loop for pricing.
%
% This function manages the entire workflow: it constructs the uniform 
% time grid, computes the deterministic tree parameters based on Hull-White 
% analytics, and evaluates the risky and risk-free swap prices across different 
% grid precision levels to monitor numerical convergence.
%
% INPUTS:
%   a                          : [Scalar] Speed of mean reversion in the HW model.
%   sigma                      : [Scalar] Volatility parameter in the HW model.
%   K                          : [Scalar] Fixed swap strike rate.
%   startDate                  : [Scalar/Datetime] Tree valuation/settle date (t0).
%   maturity_date_not_adjusted : [Scalar/Datetime] Unadjusted final maturity date.
%   precision_levels           : [Vector] Grid steps per year to test for convergence.
%   notional_amortized         : [Vector] Amortizing principal schedule matching payment dates.
%   ois_curve                  : [Struct] Market OIS curve (.dates, .discounts).
%   eur_curve                  : [Struct] Market Euribor curve (.dates, .discounts).
%   RecoveryRate               : [Scalar] Recovery rate in case of default.
%   HazardRate                 : [Scalar] Constant hazard rate (lambda) for default probability.
%
% OUTPUTS:
%   prices                     : [Vector] Amortizing swap prices for each precision level.
%   results_table              : [Table] Summary table containing steps, nodes, and prices.

    % Initialize output vectors
    n_levels = length(precision_levels);
    prices_clean = zeros(n_levels, 1);
    CVA = zeros(n_levels, 1);
    prices = zeros(n_levels, 1);
    num_nodes = zeros(n_levels, 1);
    
    % Compute adjusted payment dates and year fractions
    [paymentDates, yf] = compute_swap_payments_dates_yf(startDate, maturity_date_not_adjusted);
    maturityDate = paymentDates(end);
    
    % Convergence Loop
    for j = 1:n_levels
        stepsPerYear = precision_levels(j);
        
        % 1. Construct uniform time grid
        [~, grid_dates, dt] = build_hw_time_grid(startDate, maturityDate, stepsPerYear);
        num_nodes(j) = length(grid_dates);

        % 2. Compute tree parameters based on the current time step dt
        sigma_hat = sigma * sqrt((1 - exp(-2 * a * dt)) / (2 * a));
        dx = sigma_hat * sqrt(3); 
        mu_hat = 1 - exp(-a * dt);
        l_max = ceil((1 - sqrt(2/3)) / mu_hat);

        % 3. Invoke backward induction tree pricer
        [prices(j), prices_clean(j), CVA(j)] = price_swap_CVA(a, sigma, K, ...
            dt, grid_dates, l_max, dx, mu_hat, startDate, ois_curve, eur_curve, ...
            paymentDates, yf, notional_amortized, RecoveryRate, HazardRate);
    end

    % Format execution summary table
    results_table = table(precision_levels(:), num_nodes(:), prices_clean(:), ...
         CVA(:), prices(:), 'VariableNames', {'Steps_Per_Year', ...
         'Total_Time_Steps', 'Risk-free_Swap_Price', 'CVA','Risky_Swap_Price'});
end