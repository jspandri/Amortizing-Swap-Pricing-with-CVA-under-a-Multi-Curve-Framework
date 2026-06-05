function results_struct = run_hw_pricing_amortizing_swap_CVA( ...
    a, sigma, K, startDate, scheduleSwap, precision_levels, ...
    RecoveryRate, HazardRates, discountCurve, pseudoCurve)
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
%   HazardRates                : [Vector] Constant hazard rates (lambda) for default probability.
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
    
    % Determine the number of hazard rates
    n_hazard  = length(HazardRates);
    
    % Initialize storage vectors for prices, CVA, and grid dimension tracking
    prices_clean = zeros(n_levels, 1);
    CVA = zeros(n_levels, n_hazard);
    prices = zeros(n_levels, n_hazard);
    num_steps = zeros(n_levels, 1);
    
    % CONVERGENCE LOOP
    % Iterate through each requested precision level to evaluate model numerical stability
    for j = 1:n_levels

        % Extract the number of time steps per year for the current iteration
        stepsPerYear = precision_levels(j);
        
        % Pricing execution with different hazard rates together
        [NPV_risky, NPV_rf, CVA_val, ~, tree] = price_swap_CVA_tree(a, sigma, ...
            K, startDate, scheduleSwap, stepsPerYear, RecoveryRate, HazardRates, ...
            discountCurve, pseudoCurve);

        prices_clean(j) = NPV_rf;
        CVA(j, :) = CVA_val(:).';
        prices(j, :) = NPV_risky(:).';
        num_steps(j) = tree.nSteps;

    end

    % RESULTS PACKAGING
    % Initialize the output structured object
    results_struct = struct();
    results_struct.hazard = repmat(struct(), n_hazard, 1);
    results_struct.tables = cell(n_hazard, 1);

    % Separate the scenarios (different hazard rates) and print results
    for h = 1:n_hazard
        scenario_struct = struct();
        scenario_struct.a                = a;
        scenario_struct.sigma            = sigma;
        scenario_struct.K                = K;
        scenario_struct.startDate        = startDate;
        scenario_struct.scheduleSwap     = scheduleSwap;
        scenario_struct.precision_levels = precision_levels(:);
        scenario_struct.RecoveryRate     = RecoveryRate;
        scenario_struct.discountCurve    = discountCurve;
        scenario_struct.pseudoCurve      = pseudoCurve;
        scenario_struct.Steps_Per_Year       = precision_levels(:);
        scenario_struct.Total_Time_Steps     = num_steps(:);
        scenario_struct.Risk_free_Swap_Price = prices_clean(:);
        scenario_struct.HazardRate       = HazardRates(h);
        scenario_struct.CVA              = CVA(:, h);
        scenario_struct.Risky_Swap_Price = prices(:, h);
        
        if h == 1
            results_struct.hazard = scenario_struct;
        else
            results_struct.hazard(h) = scenario_struct;
        end
           
        % Print
        printable_struct = rmfield(scenario_struct, ...
            {'a','sigma','K','startDate','scheduleSwap','precision_levels', ...
             'RecoveryRate','discountCurve','pseudoCurve','HazardRate'});

        results_struct.tables{h} = struct2table(printable_struct);

        fprintf('--> Results for Hazard Rate = %.6f\n', HazardRates(h));
        disp(results_struct.tables{h});
    end
end