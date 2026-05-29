function results_struct = run_hw_pricing_amortizing_swap_CVA(a, sigma, sigma_times,K, ...
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
%   sigma                      : [Scalar or Vector] Volatility parameter(s) in the HW model.
%   sigma_times                : [Vector] Time buckets corresponding to the sigma vector.
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
    
    % Generate the complete swap schedule
    scheduleSwap = generate_swap_schedule(startDate, startDate, ...
        maturity_date_not_adjusted, notional_amortized, ois_curve, eur_curve);
    
    % Extract payment dates 
    paymentDates = scheduleSwap.payDates;
     
    % Set the final maturity date (it's the last calculated payment date)
    maturityDate = paymentDates(end);
    
    % 3. BASE VOLATILITY FOR TREE GEOMETRY
    % Calculate the mean of the sigma array to build an uniformly spaced tree grid
    % If sigma is scalar, the mean coincide with sigma
    sigma_base = mean(sigma);
   
    % 4. CONVERGENCE LOOP
    % Iterate through each requested precision level to evaluate model numerical stability
    for j = 1:n_levels
        
        % Extract the number of time steps per year for the current iteration
        stepsPerYear = precision_levels(j);
        
        % A. GRID CONSTRUCTION
        % Generate a uniform time grid array and the time step size (dt)
        [~, grid_dates, dt] = build_hw_time_grid(startDate, maturityDate, stepsPerYear);
        
        % Store the total number of nodes generated for the current grid resolution
        num_nodes(j) = length(grid_dates);
        
        % B. TREE PARAMETER CALCULATION
        % Compute Hull-White analytical parameter sigma_hat using the averaged base volatility
        sigma_hat = sigma_base * sqrt((1 - exp(-2 * a * dt)) / (2 * a));
        
        % Calculate the spatial step size (dx) required to keep the tree stable
        dx = sigma_hat * sqrt(3); 
        
        % Calculate the deterministic drift adjustment term
        mu_hat = 1 - exp(-a * dt);
        
        % Calculate the maximum spatial index (l_max) to ensure boundary conditions are satisfied
        l_max = ceil((1 - sqrt(2/3)) / mu_hat);
        
        % C. PRICING EXECUTION
        % Invoke the backward induction tree pricer
        [prices(j), prices_clean(j), CVA(j)] = price_swap_CVA(a, sigma, sigma_times, K, ...
            dt, grid_dates, l_max, dx, mu_hat, startDate, ois_curve, eur_curve, ...
            scheduleSwap, RecoveryRate, HazardRate);
    end
    
    % 5. RESULTS PACKAGING
    % Initialize the output structured object
    results_struct = struct();
    
    % Store the tested precision levels
    results_struct.Steps_Per_Year = precision_levels(:);
    
    % Store the corresponding total time steps computed
    results_struct.Total_Time_Steps = num_nodes(:);
    
    % Store the computed Risk-Free Swap Prices
    results_struct.Risk_free_Swap_Price = prices_clean(:);
    
    % Store the computed Credit Value Adjustments
    results_struct.CVA = CVA(:);
    
    % Store the computed Risky Swap Prices
    results_struct.Risky_Swap_Price = prices(:);
end