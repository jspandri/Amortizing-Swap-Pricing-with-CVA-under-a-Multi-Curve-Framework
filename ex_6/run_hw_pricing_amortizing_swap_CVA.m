function results_struct = run_hw_pricing_amortizing_swap_CVA( ...
    a, sigma, K, startDate, scheduleSwap, precision_levels, ...
    RecoveryRate, HazardRate, discountCurve, pseudoCurve)
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
%   scheduleSwap               : [Struct] Swap schedule container with active periods:
%                                       - .accrualStart : Period start dates (datenum)
%                                       - .accrualEnd   : Period end dates (datenum)
%                                       - .payDates     : Coupon payment dates (datenum)
%                                       - .notionals    : Active outstanding amortizing notionals
%                                       - .yf_pay       : Year fractions for payment periods (ACT/360)
%                                       - .F_forward    : Forward Libor rates
%                                       - .B_ois        : discounts at payments dates
%   precision_levels           : [Vector] Grid steps per year to test for convergence.
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

    n_levels = length(precision_levels);

    prices_clean = zeros(n_levels, 1);
    CVA          = zeros(n_levels, 1);
    prices       = zeros(n_levels, 1);
    num_steps    = zeros(n_levels, 1);

    for j = 1:n_levels

        stepsPerYear = precision_levels(j);

        [NPV_risky, NPV_rf, CVA_val, ~, tree] = price_swap_CVA_tree( ...
            a, sigma, K, startDate, scheduleSwap, stepsPerYear, ...
            RecoveryRate, HazardRate, discountCurve, pseudoCurve);

        prices_clean(j) = NPV_rf;
        CVA(j)          = CVA_val;
        prices(j)       = NPV_risky;
        num_steps(j)    = tree.nSteps;
    end

    results_struct = struct();
    results_struct.Steps_Per_Year       = precision_levels(:);
    results_struct.Total_Time_Steps     = num_steps(:);
    results_struct.Risk_free_Swap_Price = prices_clean(:);
    results_struct.CVA                  = CVA(:);
    results_struct.Risky_Swap_Price     = prices(:);
end