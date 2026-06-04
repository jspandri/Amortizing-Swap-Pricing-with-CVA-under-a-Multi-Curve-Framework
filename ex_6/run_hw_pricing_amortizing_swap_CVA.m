function results_struct = run_hw_pricing_amortizing_swap_CVA( ...
    a, sigma, K, startDate, scheduleSwap, precision_levels, ...
    RecoveryRate, HazardRate, discountCurve, pseudoCurve)
% RUN_HW_PRICING_AMORTIZING_SWAP_CVA Manages the convergence loop for pricing.
%
% INPUTS:
%   a                          : [Scalar] Speed of mean reversion in the HW model.
%   sigma                      : [Scalar] Volatility parameter in the HW model.
%   K                          : [Scalar] Fixed swap strike rate.
%   startDate                  : [Scalar/Datetime] Tree valuation/settlement date (t0).
%   scheduleSwap               : [Struct] Swap schedule container with active periods:
%                                       - .accrualStart : Period start dates (datenum)
%                                       - .accrualEnd   : Period end dates (datenum)
%                                       - .payDates     : Coupon payment dates (datenum)
%                                       - .notionals    : Active outstanding amortizing notionals
%                                       - .yf_pay       : Year fractions for payment periods (ACT/360)
%                                       - .F_forward    : Forward Libor rates
%                                       - .B_ois        : discounts at payments dates
%   precision_levels           : [Vector] Grid steps per year to test for convergence.
%   RecoveryRate               : [Scalar] Recovery rate in case of default.
%   HazardRate                 : [Scalar] Constant hazard rate (lambda) for default probability.
%   discountCurve              : [Struct] Market OIS curve (.dates, .discounts).
%   pseudoCurve                : [Struct] Market Euribor curve (.dates, .discounts).
%
% OUTPUTS:
%   results_struct             : [Struct] Convergence summary containing the following fields:
%                                  .Steps_Per_Year       [Vector] Tested grid resolutions.
%                                  .Total_Time_Steps     [Vector] Total tree nodes per run.
%                                  .Risk_free_Swap_Price [Vector] Prices excluding default risk.
%                                  .CVA                  [Vector] Credit Valuation Adjustment values.
%                                  .Risky_Swap_Price     [Vector] Final prices including default risk.
    % INITIALIZATION
    
    % Determine the number of convergence levels based on the precision input
    n_levels = length(precision_levels);
    
    % Initialize storage vectors for prices, CVA, and grid dimension tracking
    prices_clean = zeros(n_levels, 1);
    CVA          = zeros(n_levels, 1);
    prices       = zeros(n_levels, 1);
    num_steps    = zeros(n_levels, 1);
    
    % CONVERGENCE LOOP
    % Iterate through each requested precision level to evaluate model numerical stability
    for j = 1:n_levels

        % Extract the number of time steps per year for the current iteration
        stepsPerYear = precision_levels(j);
        
        % Pricing execution
        [NPV_risky, NPV_rf, CVA_val, ~, tree] = price_swap_CVA_tree( ...
            a, sigma, K, startDate, scheduleSwap, stepsPerYear, ...
            RecoveryRate, HazardRate, discountCurve, pseudoCurve);

        prices_clean(j) = NPV_rf;
        CVA(j)          = CVA_val;
        prices(j)       = NPV_risky;
        num_steps(j)    = tree.nSteps;

    end

    % RESULTS PACKAGING
    % Initialize the output structured object
    results_struct = struct();
    
    % Store the tested precision levels
    results_struct.Steps_Per_Year = precision_levels(:);
    
    % Store the corresponding total time steps computed
    results_struct.Total_Time_Steps = num_steps(:);
    
    % Store the computed Risk-Free Swap Prices
    results_struct.Risk_free_Swap_Price = prices_clean(:);
    
    % Store the computed Credit Value Adjustments
    results_struct.CVA = CVA(:);
    
    % Store the computed Risky Swap Prices
    results_struct.Risky_Swap_Price = prices(:);
end