function results_struct = run_hw_pricing_amortizing_swap_CVA(a, sigma, K, ...
    startDate, maturity_date_not_adjusted, precision_levels, notional_amortized, ...
    RecoveryRate, HazardRate, ois_curve, eur_curve)
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
%   results_struct             : [Struct] Convergence summary containing the following fields:
%                                  .Steps_Per_Year       [Vector] Tested grid resolutions.
%                                  .Total_Time_Steps     [Vector] Total tree nodes per run.
%                                  .Risk_free_Swap_Price [Vector] Prices excluding default risk.
%                                  .CVA                  [Vector] Credit Valuation Adjustment values.
%                                  .Risky_Swap_Price     [Vector] Final prices including default risk.

    % 1. INITIALIZATION
    
    % Determine the number of convergence levels based on the precision input
    n_levels = length(precision_levels);
    
    % Initialize storage vectors for prices, CVA, and grid dimension tracking
    prices_clean = zeros(n_levels, 1);
    CVA = zeros(n_levels, 1);
    prices = zeros(n_levels, 1);
    num_nodes = zeros(n_levels, 1);
    
    % 2. SCHEDULE PREPARATION
    
    % Generate the fixing, business-day adjusted payment schedule and corresponding year fractions
    [paymentDates, yf, fixing_start, fixing_end] = compute_swap_payments_dates_yf(...
        startDate, maturity_date_not_adjusted);
    
    % Set the final maturity date based on the last calculated payment date
    maturityDate = paymentDates(end);
    
    % 3. CONVERGENCE LOOP
    
    % Iterate through each requested precision level to evaluate model stability
    for j = 1:n_levels
        stepsPerYear = precision_levels(j);
        
        % A. GRID CONSTRUCTION
        % Generate a uniform time grid for the current resolution
        [~, grid_dates, dt] = build_hw_time_grid(startDate, maturityDate, stepsPerYear);
        num_nodes(j) = length(grid_dates);
        
        % B. TREE PARAMETER CALCULATION
        % Compute Hull-White analytical parameters based on the current time step size (dt)
        sigma_hat = sigma * sqrt((1 - exp(-2 * a * dt)) / (2 * a));
        
        % dx: Spatial step size required to keep the tree stable/consistent
        dx = sigma_hat * sqrt(3); 
        
        % mu_hat: Deterministic drift adjustment (1 - exp(-a*dt))
        mu_hat = 1 - exp(-a * dt);
        
        % l_max: Maximum spatial nodes to ensure boundary conditions are satisfied
        l_max = ceil((1 - sqrt(2/3)) / mu_hat);
        
        % C. PRICING EXECUTION
        % Invoke the backward induction tree pricer to obtain clean price and CVA
        [prices(j), prices_clean(j), CVA(j)] = price_swap_CVA(a, sigma, K, ...
            dt, grid_dates, l_max, dx, mu_hat, startDate, ois_curve, eur_curve, ...
            paymentDates, yf, fixing_start, fixing_end, notional_amortized,...
            RecoveryRate, HazardRate);
    end
    
    % 4. RESULTS PACKAGING
    
    % Consolidate all convergence metrics into a structured output object
    results_struct = struct();
    results_struct.Steps_Per_Year = precision_levels(:);
    results_struct.Total_Time_Steps = num_nodes(:);
    results_struct.Risk_free_Swap_Price = prices_clean(:);
    results_struct.CVA = CVA(:);
    results_struct.Risky_Swap_Price = prices(:);
end